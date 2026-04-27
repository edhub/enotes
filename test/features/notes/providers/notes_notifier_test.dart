import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enotes/features/notes/models/note.dart';
import 'package:enotes/features/notes/providers/notes_provider.dart';
import 'package:enotes/features/notes/services/notes_service.dart';

/// In-memory [NotesService] stand-in. Records every persistence call so
/// tests can assert that [NotesNotifier] talks to its dependency correctly.
///
/// Inherits from [NotesService] so it satisfies the provider's type
/// signature without touching real SQLite (which can't run in unit tests).
class _FakeNotesService extends NotesService {
  final Map<String, Note> store = {};
  final List<List<String>> upsertCalls = [];
  final List<Set<String>> deleteCalls = [];
  Object? throwOnUpsert;

  @override
  Future<void> init() async {
    /* no-op */
  }

  @override
  Future<List<Note>> loadNotes() async => store.values.toList();

  @override
  Future<void> saveNotes(List<Note> notes) async {
    store
      ..clear()
      ..addEntries(notes.map((n) => MapEntry(n.id, n)));
  }

  @override
  Future<void> upsertNotes(List<Note> notes) async {
    upsertCalls.add(notes.map((n) => n.id).toList());
    if (throwOnUpsert != null) throw throwOnUpsert!;
    for (final n in notes) {
      store[n.id] = n;
    }
  }

  @override
  Future<void> deleteNotesByIds(Set<String> ids) async {
    deleteCalls.add(Set<String>.from(ids));
    for (final id in ids) {
      store.remove(id);
    }
  }

  @override
  void dispose() {
    /* no-op */
  }
}

ProviderContainer _makeContainer({
  required _FakeNotesService service,
  List<Note> initial = const [],
}) {
  return ProviderContainer(
    overrides: [
      notesServiceProvider.overrideWithValue(service),
      initialNotesProvider.overrideWithValue(initial),
    ],
  );
}

/// Wait long enough for the 800ms debounced save timer to fire.
Future<void> _waitForSave() async {
  await Future<void>.delayed(const Duration(milliseconds: 900));
}

void main() {
  group('NotesNotifier', () {
    test('build() ensures exactly maxDraftNotes draft slots', () {
      final svc = _FakeNotesService();
      final c = _makeContainer(service: svc);
      addTearDown(c.dispose);

      final state = c.read(notesProvider);
      expect(state.draftNotes.length, 5);
      // New drafts should have been upserted to the service.
      expect(svc.upsertCalls, isNotEmpty);
    });

    test('addNote prepends to the list and marks dirty for save', () async {
      final svc = _FakeNotesService();
      final c = _makeContainer(service: svc);
      addTearDown(c.dispose);

      c.read(notesProvider.notifier).addNote('hello');

      final state = c.read(notesProvider);
      expect(state.notes.first.content, 'hello');
      expect(state.notes.first.isDraft, isFalse);

      await _waitForSave();
      expect(svc.upsertCalls.last, contains(state.notes.first.id));
    });

    test(
      'updateNote uses replaceContent — unrelated columns stay identical',
      () async {
        final now = DateTime.now().toUtc();
        final today = Note(
          id: 'today',
          content: 'today text',
          createdAt: now,
          updatedAt: now,
        );
        final old = Note(
          id: 'old',
          content: 'old text',
          createdAt: now.subtract(const Duration(days: 30)),
          updatedAt: now.subtract(const Duration(days: 30)),
        );

        final svc = _FakeNotesService();
        final c = _makeContainer(service: svc, initial: [today, old]);
        addTearDown(c.dispose);

        final before = c.read(notesProvider).timeColumns;
        // Sanity: today + at least one historical column.
        expect(before.length, greaterThanOrEqualTo(2));
        final oldColBefore = before.firstWhere(
          (col) => col.notes.any((n) => n.id == 'old'),
        );

        c.read(notesProvider.notifier).updateNote('today', 'today text!');

        final after = c.read(notesProvider).timeColumns;
        final oldColAfter = after.firstWhere(
          (col) => col.notes.any((n) => n.id == 'old'),
        );

        // The historical column's reference must be preserved verbatim — that's
        // the whole point of replaceContent.
        expect(identical(oldColAfter, oldColBefore), isTrue);

        // The today column, however, must be a new reference with new content.
        final todayColAfter = after.firstWhere(
          (col) => col.bucketKey == 'today',
        );
        expect(
          todayColAfter.notes.firstWhere((n) => n.id == 'today').content,
          'today text!',
        );
      },
    );

    test('updateNote preserves draftNotes / trashedNotes references when '
        'editing a regular note', () {
      final now = DateTime.now().toUtc();
      final regular = Note(
        id: 'r',
        content: 'r',
        createdAt: now,
        updatedAt: now,
      );
      final svc = _FakeNotesService();
      final c = _makeContainer(service: svc, initial: [regular]);
      addTearDown(c.dispose);

      final before = c.read(notesProvider);
      c.read(notesProvider.notifier).updateNote('r', 'r2');
      final after = c.read(notesProvider);

      expect(identical(after.draftNotes, before.draftNotes), isTrue);
      expect(identical(after.trashedNotes, before.trashedNotes), isTrue);
    });

    test('deleteNote moves note to trash and refuses drafts', () {
      final now = DateTime.now().toUtc();
      final regular = Note(
        id: 'r',
        content: 'r',
        createdAt: now,
        updatedAt: now,
      );
      final svc = _FakeNotesService();
      final c = _makeContainer(service: svc, initial: [regular]);
      addTearDown(c.dispose);

      c.read(notesProvider.notifier).deleteNote('r');
      final state = c.read(notesProvider);
      expect(state.trashedNotes.map((n) => n.id), contains('r'));
      expect(state.timeColumns.expand((col) => col.notes), isEmpty);

      // Drafts are protected.
      final draftId = state.draftNotes.first.id;
      c.read(notesProvider.notifier).deleteNote(draftId);
      expect(c.read(notesProvider).draftNotes.first.id, draftId);
    });

    test('restoreNote moves trashed note back to a time column', () {
      final now = DateTime.now().toUtc();
      final trashed = Note(
        id: 't',
        content: 't',
        createdAt: now,
        updatedAt: now,
        deletedAt: now,
      );
      final svc = _FakeNotesService();
      final c = _makeContainer(service: svc, initial: [trashed]);
      addTearDown(c.dispose);

      c.read(notesProvider.notifier).restoreNote('t');
      final state = c.read(notesProvider);
      expect(state.trashedNotes, isEmpty);
      expect(
        state.timeColumns.expand((col) => col.notes).map((n) => n.id),
        contains('t'),
      );
    });

    test('permanentlyDeleteNote removes from list and from DB', () async {
      final now = DateTime.now().toUtc();
      final trashed = Note(
        id: 't',
        content: 't',
        createdAt: now,
        updatedAt: now,
        deletedAt: now,
      );
      final svc = _FakeNotesService();
      final c = _makeContainer(service: svc, initial: [trashed]);
      addTearDown(c.dispose);

      c.read(notesProvider.notifier).permanentlyDeleteNote('t');
      expect(c.read(notesProvider).notes.any((n) => n.id == 't'), isFalse);

      await _waitForSave();
      expect(svc.deleteCalls.last, contains('t'));
    });

    test('emptyTrash drops all soft-deleted notes', () async {
      final now = DateTime.now().toUtc();
      final svc = _FakeNotesService();
      final c = _makeContainer(
        service: svc,
        initial: [
          Note(
            id: 'a',
            content: 'a',
            createdAt: now,
            updatedAt: now,
            deletedAt: now,
          ),
          Note(
            id: 'b',
            content: 'b',
            createdAt: now,
            updatedAt: now,
            deletedAt: now,
          ),
          Note(id: 'c', content: 'c', createdAt: now, updatedAt: now),
        ],
      );
      addTearDown(c.dispose);

      c.read(notesProvider.notifier).emptyTrash();
      final state = c.read(notesProvider);
      expect(state.trashedNotes, isEmpty);
      expect(state.notes.any((n) => n.id == 'c'), isTrue);

      await _waitForSave();
      // The two trashed ids must be in some delete call.
      final allDeleted = svc.deleteCalls.expand((s) => s).toSet();
      expect(allDeleted, containsAll(['a', 'b']));
    });

    test('focus requests increment monotonically', () {
      final svc = _FakeNotesService();
      final c = _makeContainer(service: svc);
      addTearDown(c.dispose);

      final before = c.read(notesProvider).newNoteFocusRequest;
      c.read(notesProvider.notifier).requestNewNoteFocus();
      c.read(notesProvider.notifier).requestNewNoteFocus();
      expect(c.read(notesProvider).newNoteFocusRequest, before + 2);
    });

    test('importNotes replaces all data and saves immediately', () async {
      final svc = _FakeNotesService();
      final c = _makeContainer(service: svc);
      addTearDown(c.dispose);

      final imported = [
        Note.create(content: 'imported 1'),
        Note.create(content: 'imported 2'),
      ];
      await c.read(notesProvider.notifier).importNotes(imported);

      final state = c.read(notesProvider);
      // 2 imported + 5 ensured drafts (importNotes preserves the invariant).
      expect(state.notes.length, 2 + 5);
      // Imported notes are written immediately by saveNotes; ensured drafts
      // are written via the post-import unawaited _safeUpsert. The exact
      // count depends on microtask interleaving, but both sets must persist.
      expect(svc.store.values.any((n) => n.content == 'imported 1'), isTrue);
      expect(svc.store.values.any((n) => n.content == 'imported 2'), isTrue);
    });

    test('upsert error is reported via saveErrorProvider', () async {
      final svc = _FakeNotesService()..throwOnUpsert = StateError('disk full');
      final c = _makeContainer(service: svc);
      addTearDown(c.dispose);

      c.read(notesProvider.notifier).addNote('boom');
      await _waitForSave();

      expect(c.read(saveErrorProvider), contains('disk full'));
    });
  });
}
