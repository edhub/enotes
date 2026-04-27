import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enotes/core/theme/app_theme.dart';
import 'package:enotes/features/notes/models/note.dart';
import 'package:enotes/features/notes/providers/notes_provider.dart';
import 'package:enotes/features/notes/providers/now_provider.dart';
import 'package:enotes/features/notes/services/notes_service.dart';
import 'package:enotes/features/notes/widgets/draft_column.dart';

class _FixedCurrentDayNotifier extends CurrentDayNotifier {
  _FixedCurrentDayNotifier(this.day);

  final DateTime day;

  @override
  DateTime build() => day;
}

class _FakeNotesService extends NotesService {
  @override
  Future<void> init() async {}

  @override
  Future<List<Note>> loadNotes() async => const [];

  @override
  Future<void> saveNotes(List<Note> notes) async {}

  @override
  Future<void> upsertNotes(List<Note> notes) async {}

  @override
  Future<void> deleteNotesByIds(Set<String> ids) async {}

  @override
  void dispose() {}
}

void main() {
  testWidgets('tapping a tab updates activeDraftIndex', (tester) async {
    final now = DateTime.now().toUtc();
    final container = ProviderContainer(
      overrides: [
        currentDayProvider.overrideWith(
          () =>
              _FixedCurrentDayNotifier(DateTime(now.year, now.month, now.day)),
        ),
        notesServiceProvider.overrideWithValue(_FakeNotesService()),
        initialNotesProvider.overrideWithValue([
          Note(
            id: 'd1',
            content: 'Draft 1',
            createdAt: now.subtract(const Duration(minutes: 1)),
            updatedAt: now.subtract(const Duration(minutes: 1)),
            isDraft: true,
          ),
          Note(
            id: 'd2',
            content: 'Draft 2',
            createdAt: now,
            updatedAt: now,
            isDraft: true,
          ),
        ]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 760,
                child: DraftColumn(availableHeight: 760),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(notesProvider).activeDraftIndex, 0);

    await tester.tap(find.text('2').first);
    await tester.pumpAndSettle();

    expect(container.read(notesProvider).activeDraftIndex, 1);
  });
}
