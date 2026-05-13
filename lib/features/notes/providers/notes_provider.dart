import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_constants.dart';
import '../models/note.dart';
import '../models/time_group.dart';
import '../services/notes_service.dart';
import 'now_provider.dart';

part 'notes_state.part.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

/// The SQLite-backed note service. Must be overridden in [ProviderScope]
/// after [NotesService.init] completes in [main].
final notesServiceProvider = Provider<NotesService>((ref) {
  throw UnimplementedError(
    'notesServiceProvider must be overridden in ProviderScope. '
    'Ensure NotesService.init() is called in main() before runApp().',
  );
});

/// Notes loaded at startup before [runApp]. Overridden in [ProviderScope].
final initialNotesProvider = Provider<List<Note>>((ref) {
  throw UnimplementedError(
    'initialNotesProvider must be overridden in ProviderScope. '
    'Ensure notes are loaded in main() before runApp().',
  );
});

/// Surfaces the most recent persistence error (if any).
///
/// `null` means everything is healthy. The root widget listens to this and
/// shows a non-blocking SnackBar when it transitions to a non-null value.
final saveErrorProvider = NotifierProvider<SaveErrorNotifier, String?>(
  SaveErrorNotifier.new,
);

class SaveErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void report(String message) => state = message;
  void clear() => state = null;
}

// ── Domain provider ───────────────────────────────────────────────────────────

/// Central provider for all note state and mutations.
///
/// Future features (tags, tasks) create their own providers and `ref.watch`
/// this one for cross-feature derived state — no [ProxyProvider] chains needed.
final notesProvider = NotifierProvider<NotesNotifier, NotesState>(
  NotesNotifier.new,
);

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Business logic for all note mutations.
///
/// Accessed via `ref.read(notesProvider.notifier)`.
///
/// Uses incremental saves: only dirty (added/modified) notes are upserted,
/// and only permanently deleted notes are removed from the DB. This avoids
/// full-table DELETE + INSERT on every keystroke.
class NotesNotifier extends Notifier<NotesState> {
  Timer? _saveTimer;

  /// IDs of notes that need to be upserted (added or modified).
  final Set<String> _dirtyIds = {};

  /// IDs of notes that have been permanently removed from the list.
  final Set<String> _removedIds = {};

  @override
  NotesState build() {
    ref.onDispose(() => _saveTimer?.cancel());

    // Re-bucket time columns when the calendar day changes (e.g. midnight).
    ref.listen(currentDayProvider, (_, today) {
      // Use the day boundary as the new "now": noon-of-today is good enough,
      // it just needs to fall inside the new day.
      state = state.copyWith(now: today.add(const Duration(hours: 12)));
    });

    final initialNotes = ref.read(initialNotesProvider);
    final initialDay = ref.read(currentDayProvider);
    return _ensureDraftSlots(
      NotesState(
        notes: List<Note>.from(initialNotes),
        now: initialDay.add(const Duration(hours: 12)),
      ),
    );
  }

  // ── Focus ──────────────────────────────────────────────────────────────────

  /// Signals the Today column's new-note composer to take keyboard focus.
  void requestNewNoteFocus() {
    state = state.copyWith(newNoteFocusRequest: state.newNoteFocusRequest + 1);
  }

  /// Signals the currently active draft editor to take keyboard focus.
  void requestDraftFocus() {
    state = state.copyWith(draftFocusRequest: state.draftFocusRequest + 1);
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  /// Adds a new regular (non-draft) note.
  ///
  /// Time columns render newest-first, so newly created notes appear at the
  /// top and keep that position across restarts.
  void addNote(String content) {
    final note = Note.create(content: content, isDraft: false);
    final updated = [note, ...state.notes];
    // addNote affects bucket assignment → full recompute (with the latest now).
    state = state.copyWith(notes: updated, now: DateTime.now());
    _markDirty(note.id);
  }

  /// Updates note content in-place. Position in the list is preserved.
  ///
  /// Uses [NotesState.replaceContent] for incremental updates: only the
  /// derived list containing this note (drafts | one timeColumn | trash)
  /// is rebuilt, sparing every other column from a needless rebuild.
  void updateNote(String id, String content) {
    final idx = state.notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final oldNote = state.notes[idx];
    final newNote = oldNote.copyWith(
      content: content,
      updatedAt: DateTime.now().toUtc(),
    );
    final updatedNotes = List<Note>.from(state.notes);
    updatedNotes[idx] = newNote;
    state = state.replaceContent(
      notes: updatedNotes,
      oldNote: oldNote,
      newNote: newNote,
    );
    _markDirty(id);
  }

  /// Soft-deletes a regular note (moves to trash). Draft notes cannot be deleted.
  void deleteNote(String id) {
    final idx = state.notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    if (state.notes[idx].isDraft) {
      log('NotesNotifier: draft notes cannot be deleted');
      return;
    }
    final updated = List<Note>.from(state.notes);
    updated[idx] = updated[idx].copyWith(deletedAt: DateTime.now().toUtc());
    state = state.copyWith(notes: updated);
    _markDirty(id);
  }

  /// Restores a soft-deleted note back to its original time column.
  void restoreNote(String id) {
    final idx = state.notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final updated = List<Note>.from(state.notes);
    updated[idx] = updated[idx].copyWith(clearDeletedAt: true);
    state = state.copyWith(notes: updated);
    _markDirty(id);
  }

  /// Permanently removes a single note from storage (trash only).
  void permanentlyDeleteNote(String id) {
    final updated = state.notes.where((n) => n.id != id).toList();
    state = state.copyWith(notes: updated);
    _markRemoved(id);
  }

  /// Permanently removes all soft-deleted notes.
  void emptyTrash() {
    final trashed = state.notes.where((n) => n.isDeleted).map((n) => n.id);
    for (final id in trashed) {
      _removedIds.add(id);
      _dirtyIds.remove(id);
    }
    final updated = state.notes.where((n) => !n.isDeleted).toList();
    state = state.copyWith(notes: updated);
    _scheduleSave();
  }

  /// Replaces ALL notes with [notes] (full overwrite — used by import).
  ///
  /// Draft slots are re-ensured after the replace. Saves to disk immediately
  /// (no debounce) so the caller can await completion. Throws on persistence
  /// failure so the UI can surface the error.
  Future<void> importNotes(List<Note> notes) async {
    _saveTimer?.cancel();
    _saveTimer = null;
    _dirtyIds.clear();
    _removedIds.clear();

    var newState = NotesState(
      notes: List<Note>.from(notes),
      now: DateTime.now(),
    );
    newState = _ensureDraftSlots(newState);
    state = newState;

    try {
      await ref
          .read(notesServiceProvider)
          .saveNotes(List<Note>.unmodifiable(state.notes));
    } catch (e, st) {
      log('NotesNotifier.importNotes failed: $e', error: e, stackTrace: st);
      ref
          .read(saveErrorProvider.notifier)
          .report('Import failed to persist: $e');
      rethrow;
    }
  }

  /// Switches the visible draft tab. Clamps to valid range automatically.
  void setActiveDraftIndex(int index) {
    final drafts = state.draftNotes;
    if (drafts.isEmpty) return;
    final clamped = index.clamp(0, drafts.length - 1);
    if (state.activeDraftIndex == clamped) return;
    state = state.copyWith(activeDraftIndex: clamped);
  }

  /// Switches the active draft tab and asks the draft editor to grab focus.
  ///
  /// Unlike [setActiveDraftIndex], this always emits a focus request even when
  /// the requested tab is already active.
  void activateDraftAndFocus(int index) {
    final drafts = state.draftNotes;
    if (drafts.isEmpty) return;
    final clamped = index.clamp(0, drafts.length - 1);
    state = state.copyWith(
      activeDraftIndex: clamped,
      draftFocusRequest: state.draftFocusRequest + 1,
    );
  }

  /// Cancels the debounce timer and writes to disk immediately.
  /// Call from app lifecycle hooks (paused / hidden / detached).
  Future<void> flushSave() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _persistDirty();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  /// Ensures exactly [LayoutConstants.maxDraftNotes] draft slots exist.
  /// If new drafts are created, upserts only the new ones immediately.
  NotesState _ensureDraftSlots(NotesState s) {
    final existing = s.notes.where((n) => n.isDraft).length;
    if (existing >= LayoutConstants.maxDraftNotes) return s;

    final updated = List<Note>.from(s.notes);
    final newDrafts = <Note>[];
    for (int i = existing; i < LayoutConstants.maxDraftNotes; i++) {
      final draft = Note.create(content: '', isDraft: true);
      updated.add(draft);
      newDrafts.add(draft);
    }
    // Save only the newly created slots — no full-table rewrite.
    unawaited(_safeUpsert(newDrafts));
    return s.copyWith(notes: updated);
  }

  void _markDirty(String id) {
    _dirtyIds.add(id);
    _removedIds.remove(id);
    _scheduleSave();
  }

  void _markRemoved(String id) {
    _removedIds.add(id);
    _dirtyIds.remove(id);
    _scheduleSave();
  }

  /// Schedules a debounced (800 ms) incremental save to disk.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 800),
      () => unawaited(_persistDirty()),
    );
  }

  /// Writes only dirty and removed notes to the database.
  ///
  /// IMPORTANT: Only clears [_dirtyIds] and [_removedIds] AFTER successful
  /// persistence. This prevents silent data loss if the database temporarily
  /// fails — dirty IDs are preserved for retry on the next save cycle.
  Future<void> _persistDirty() async {
    final service = ref.read(notesServiceProvider);

    if (_dirtyIds.isNotEmpty) {
      final dirtyIdsToSave = Set<String>.from(_dirtyIds);
      final dirtyNotes = state.notes
          .where((n) => dirtyIdsToSave.contains(n.id))
          .toList();
      final success = await _safeUpsert(dirtyNotes);
      if (success) {
        _dirtyIds.removeAll(dirtyIdsToSave);
      }
    }

    if (_removedIds.isNotEmpty) {
      final idsToRemove = Set<String>.from(_removedIds);
      final success = await _safeDelete(service, idsToRemove);
      if (success) {
        _removedIds.removeAll(idsToRemove);
      }
    }
  }

  /// Upserts notes and returns `true` on success, `false` on failure.
  ///
  /// Errors are logged and reported to [saveErrorProvider], but not rethrown.
  /// The caller uses the return value to decide whether to clear dirty IDs.
  Future<bool> _safeUpsert(List<Note> notes) async {
    if (notes.isEmpty) return true;
    try {
      await ref.read(notesServiceProvider).upsertNotes(notes);
      return true;
    } catch (e, st) {
      log('NotesNotifier: upsert failed: $e', error: e, stackTrace: st);
      ref.read(saveErrorProvider.notifier).report('Failed to save changes: $e');
      return false;
    }
  }

  /// Deletes notes and returns `true` on success, `false` on failure.
  ///
  /// Errors are logged and reported to [saveErrorProvider], but not rethrown.
  /// The caller uses the return value to decide whether to clear removed IDs.
  Future<bool> _safeDelete(NotesService service, Set<String> ids) async {
    if (ids.isEmpty) return true;
    try {
      await service.deleteNotesByIds(ids);
      return true;
    } catch (e, st) {
      log('NotesNotifier: delete failed: $e', error: e, stackTrace: st);
      ref.read(saveErrorProvider.notifier).report('Failed to delete notes: $e');
      return false;
    }
  }
}
