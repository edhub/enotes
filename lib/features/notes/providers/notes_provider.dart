import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_constants.dart';
import '../models/note.dart';
import '../models/time_group.dart';
import '../services/notes_service.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

/// The SQLite-backed note service. Must be overridden in [ProviderScope]
/// after [NotesService.init] completes in [main].
final notesServiceProvider = Provider<NotesService>((ref) {
  throw UnimplementedError(
    'notesServiceProvider must be overridden in ProviderScope',
  );
});

/// Notes loaded at startup before [runApp]. Overridden in [ProviderScope].
final initialNotesProvider = Provider<List<Note>>((ref) {
  throw UnimplementedError(
    'initialNotesProvider must be overridden in ProviderScope',
  );
});

// ── Domain provider ───────────────────────────────────────────────────────────

/// Central provider for all note state and mutations.
///
/// Future features (tags, tasks) create their own providers and `ref.watch`
/// this one for cross-feature derived state — no [ProxyProvider] chains needed.
final notesProvider = NotifierProvider<NotesNotifier, NotesState>(
  NotesNotifier.new,
);

// ── Immutable state ───────────────────────────────────────────────────────────

/// All note state in a single immutable snapshot.
///
/// Computed views ([draftNotes], [timeColumns], [trashedNotes]) are pure
/// functions of [notes] — no side effects, safe to call repeatedly.
@immutable
class NotesState {
  const NotesState({
    required this.notes,
    this.activeDraftIndex = 0,
    this.newNoteFocusRequest = 0,
  });

  /// All notes in insertion order (index 0 = most recently added).
  final List<Note> notes;

  /// Index of the currently visible draft tab (0-based).
  final int activeDraftIndex;

  /// Incremented each time the user requests focus on the new-note composer
  /// (e.g. via Cmd+K). Widgets detect the increment and grab keyboard focus.
  final int newNoteFocusRequest;

  // ── Computed views ─────────────────────────────────────────────────────────

  /// Exactly [LayoutConstants.maxDraftNotes] drafts, oldest first (tab 0).
  List<Note> get draftNotes => notes
      .where((n) => n.isDraft && !n.isDeleted)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Non-draft, non-deleted notes grouped into time columns, most-recent first.
  /// The 'today' bucket is always present so the composer is always reachable.
  List<TimeColumnData> get timeColumns {
    final now = DateTime.now();
    final Map<String, List<Note>> buckets = {'today': []};

    for (final note in notes.where((n) => !n.isDraft && !n.isDeleted)) {
      final key = TimeGroupHelper.bucketKey(note.createdAt, now: now);
      (buckets[key] ??= []).add(note);
    }

    return buckets.entries
        .map(
          (entry) => TimeColumnData(
            bucketKey: entry.key,
            group: TimeGroupHelper.groupFromKey(entry.key),
            label: TimeGroupHelper.labelFromKey(entry.key),
            notes: entry.value,
            sortOrder: TimeGroupHelper.sortOrder(entry.key, now: now),
          ),
        )
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Soft-deleted notes sorted by deletion time, most recently deleted first.
  List<Note> get trashedNotes => notes
      .where((n) => n.isDeleted)
      .toList()
    ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));

  /// All notes unmodifiable (for export / backup).
  List<Note> get allNotes => List<Note>.unmodifiable(notes);

  // ── Copy helper ────────────────────────────────────────────────────────────

  NotesState copyWith({
    List<Note>? notes,
    int? activeDraftIndex,
    int? newNoteFocusRequest,
  }) =>
      NotesState(
        notes: notes ?? this.notes,
        activeDraftIndex: activeDraftIndex ?? this.activeDraftIndex,
        newNoteFocusRequest: newNoteFocusRequest ?? this.newNoteFocusRequest,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Business logic for all note mutations.
///
/// Accessed via `ref.read(notesProvider.notifier)`.
class NotesNotifier extends Notifier<NotesState> {
  Timer? _saveTimer;

  @override
  NotesState build() {
    ref.onDispose(() => _saveTimer?.cancel());

    final initialNotes = ref.read(initialNotesProvider);
    return _ensureFiveDrafts(
      NotesState(notes: List<Note>.from(initialNotes)),
    );
  }

  // ── Focus ──────────────────────────────────────────────────────────────────

  /// Signals the Today column's new-note composer to take keyboard focus.
  void requestNewNoteFocus() {
    state = state.copyWith(
      newNoteFocusRequest: state.newNoteFocusRequest + 1,
    );
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  /// Adds a new regular (non-draft) note at the top of the list.
  void addNote(String content) {
    final note = Note.create(content: content, isDraft: false);
    final updated = [note, ...state.notes];
    state = state.copyWith(notes: updated);
    _scheduleSave();
  }

  /// Updates note content in-place. Position in the list is preserved.
  void updateNote(String id, String content) {
    final idx = state.notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final updated = List<Note>.from(state.notes);
    updated[idx] = updated[idx].copyWith(
      content: content,
      updatedAt: DateTime.now().toUtc(),
    );
    state = state.copyWith(notes: updated);
    _scheduleSave();
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
    _scheduleSave();
  }

  /// Restores a soft-deleted note back to its original time column.
  void restoreNote(String id) {
    final idx = state.notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final updated = List<Note>.from(state.notes);
    updated[idx] = updated[idx].copyWith(clearDeletedAt: true);
    state = state.copyWith(notes: updated);
    _scheduleSave();
  }

  /// Permanently removes a single note from storage (trash only).
  void permanentlyDeleteNote(String id) {
    final updated = state.notes.where((n) => n.id != id).toList();
    state = state.copyWith(notes: updated);
    _scheduleSave();
  }

  /// Permanently removes all soft-deleted notes.
  void emptyTrash() {
    final updated = state.notes.where((n) => !n.isDeleted).toList();
    state = state.copyWith(notes: updated);
    _scheduleSave();
  }

  /// Replaces ALL notes with [notes] (full overwrite — used by import).
  ///
  /// Draft slots are re-ensured after the replace. Saves to disk immediately
  /// (no debounce) so the caller can await completion.
  Future<void> importNotes(List<Note> notes) async {
    _saveTimer?.cancel();
    _saveTimer = null;

    var newState = NotesState(notes: List<Note>.from(notes));
    newState = _ensureFiveDrafts(newState);
    state = newState;

    await ref
        .read(notesServiceProvider)
        .saveNotes(List<Note>.unmodifiable(state.notes));
  }

  /// Switches the visible draft tab. Clamps to valid range automatically.
  void setActiveDraftIndex(int index) {
    final drafts = state.draftNotes;
    if (drafts.isEmpty) return;
    final clamped = index.clamp(0, drafts.length - 1);
    if (state.activeDraftIndex == clamped) return;
    state = state.copyWith(activeDraftIndex: clamped);
  }

  /// Cancels the debounce timer and writes to disk immediately.
  /// Call from app lifecycle hooks (inactive / detached).
  void flushSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
    ref
        .read(notesServiceProvider)
        .saveNotes(List<Note>.unmodifiable(state.notes));
  }

  // ── Private ────────────────────────────────────────────────────────────────

  /// Ensures exactly [LayoutConstants.maxDraftNotes] draft slots exist.
  /// If new drafts are created, saves to disk immediately.
  NotesState _ensureFiveDrafts(NotesState s) {
    final existing = s.notes.where((n) => n.isDraft).length;
    if (existing >= LayoutConstants.maxDraftNotes) return s;

    final updated = List<Note>.from(s.notes);
    for (int i = existing; i < LayoutConstants.maxDraftNotes; i++) {
      updated.add(Note.create(content: '', isDraft: true));
    }
    // Save the newly created slots without waiting for the debounce timer.
    unawaited(
      ref
          .read(notesServiceProvider)
          .saveNotes(List<Note>.unmodifiable(updated)),
    );
    return s.copyWith(notes: updated);
  }

  /// Schedules a debounced (800 ms) save to disk.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 800),
      () => ref
          .read(notesServiceProvider)
          .saveNotes(List<Note>.unmodifiable(state.notes)),
    );
  }
}
