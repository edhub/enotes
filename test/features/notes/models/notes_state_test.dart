import 'package:flutter_test/flutter_test.dart';

import 'package:enotes/features/notes/models/note.dart';
import 'package:enotes/features/notes/providers/notes_provider.dart';

void main() {
  group('NotesState', () {
    late List<Note> sampleNotes;

    setUp(() {
      final now = DateTime.now().toUtc();
      sampleNotes = [
        Note(
          id: '1',
          content: 'Draft 1',
          createdAt: now,
          updatedAt: now,
          isDraft: true,
        ),
        Note(
          id: '2',
          content: 'Active note today',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: '3',
          content: 'Old note',
          createdAt: now.subtract(const Duration(days: 14)),
          updatedAt: now.subtract(const Duration(days: 14)),
        ),
        Note(
          id: '4',
          content: 'Deleted note',
          createdAt: now,
          updatedAt: now,
          deletedAt: now,
        ),
      ];
    });

    test('draftNotes filters correctly', () {
      final state = NotesState(notes: sampleNotes);
      expect(state.draftNotes.length, 1);
      expect(state.draftNotes.first.id, '1');
    });

    test('trashedNotes filters correctly', () {
      final state = NotesState(notes: sampleNotes);
      expect(state.trashedNotes.length, 1);
      expect(state.trashedNotes.first.id, '4');
    });

    test('timeColumns contain non-draft non-deleted notes', () {
      final state = NotesState(notes: sampleNotes);
      final allTimeNotes = state.timeColumns
          .expand((col) => col.notes)
          .toList();
      expect(allTimeNotes.length, 2);
      expect(allTimeNotes.map((n) => n.id), containsAll(['2', '3']));
    });

    test('timeColumns always include today bucket', () {
      final state = NotesState(notes: []);
      final todayCol = state.timeColumns.where((c) => c.bucketKey == 'today');
      expect(todayCol.length, 1);
      expect(todayCol.first.notes, isEmpty);
    });

    test('timeColumns are sorted by sortOrder', () {
      final state = NotesState(notes: sampleNotes);
      for (int i = 1; i < state.timeColumns.length; i++) {
        expect(
          state.timeColumns[i].sortOrder,
          greaterThanOrEqualTo(state.timeColumns[i - 1].sortOrder),
        );
      }
    });

    test('copyWith without notes preserves list references', () {
      final state = NotesState(notes: sampleNotes);
      final updated = state.copyWith(activeDraftIndex: 2);
      expect(identical(updated.draftNotes, state.draftNotes), isTrue);
      expect(identical(updated.timeColumns, state.timeColumns), isTrue);
      expect(identical(updated.trashedNotes, state.trashedNotes), isTrue);
      expect(updated.activeDraftIndex, 2);
    });

    test('copyWith with notes recomputes derived lists', () {
      final state = NotesState(notes: sampleNotes);
      final newNote = Note(
        id: '5',
        content: 'New',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      final updated = state.copyWith(notes: [...sampleNotes, newNote]);
      expect(identical(updated.timeColumns, state.timeColumns), isFalse);
    });

    test('allNotes returns unmodifiable list', () {
      final state = NotesState(notes: sampleNotes);
      expect(() => state.allNotes.add(sampleNotes.first), throwsA(anything));
    });
  });

  group('Note', () {
    test('create generates UUID and UTC timestamps', () {
      final note = Note.create(content: 'test');
      expect(note.id, isNotEmpty);
      expect(note.createdAt.isUtc, isTrue);
      expect(note.updatedAt.isUtc, isTrue);
      expect(note.isDraft, isFalse);
      expect(note.isDeleted, isFalse);
    });

    test('create with isDraft', () {
      final note = Note.create(content: '', isDraft: true);
      expect(note.isDraft, isTrue);
    });

    test('copyWith preserves createdAt', () {
      final note = Note.create(content: 'original');
      final updated = note.copyWith(content: 'changed');
      expect(updated.createdAt, note.createdAt);
      expect(updated.content, 'changed');
    });

    test('copyWith clearDeletedAt restores note', () {
      final note = Note.create(
        content: 'test',
      ).copyWith(deletedAt: DateTime.now().toUtc());
      expect(note.isDeleted, isTrue);
      final restored = note.copyWith(clearDeletedAt: true);
      expect(restored.isDeleted, isFalse);
      expect(restored.deletedAt, isNull);
    });

    test('toJson / fromJson roundtrip', () {
      final note = Note.create(content: 'hello world');
      final json = note.toJson();
      final restored = Note.fromJson(json);
      expect(restored.id, note.id);
      expect(restored.content, note.content);
      expect(restored.isDraft, note.isDraft);
      expect(
        restored.createdAt.toIso8601String(),
        note.createdAt.toIso8601String(),
      );
    });

    test('toString truncates long content', () {
      final note = Note.create(
        content:
            'This is a very long content string that exceeds twenty characters',
      );
      final str = note.toString();
      expect(str, contains('…'));
      expect(str, contains('This is a very long '));
    });

    test('toString handles short content', () {
      final note = Note.create(content: 'short');
      final str = note.toString();
      expect(str, contains('content: short'));
      expect(str, isNot(contains('…')));
    });
  });
}
