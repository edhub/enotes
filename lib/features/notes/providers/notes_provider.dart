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
/// [draftNotes], [timeColumns], [trashedNotes] are precomputed at construction
/// time and stored as final fields. [copyWith] reuses the same list references
/// when [notes] is unchanged, so Riverpod's [select] can correctly detect
/// "nothing changed" via reference equality and skip widget rebuilds.
@immutable
class NotesState {
  /// Public constructor: derives [draftNotes], [timeColumns], [trashedNotes]
  /// from [notes] immediately.
  NotesState({
    required List<Note> notes,
    int activeDraftIndex = 0,
    int newNoteFocusRequest = 0,
  }) : this._(
          notes: notes,
          draftNotes: _computeDraftNotes(notes),
          timeColumns: _computeTimeColumns(notes),
          trashedNotes: _computeTrashedNotes(notes),
          activeDraftIndex: activeDraftIndex,
          newNoteFocusRequest: newNoteFocusRequest,
        );

  /// Internal constructor: all fields supplied directly.
  /// Used by [copyWith] to preserve list references when [notes] is unchanged.
  const NotesState._(
      {required this.notes,
      required this.draftNotes,
      required this.timeColumns,
      required this.trashedNotes,
      required this.activeDraftIndex,
      required this.newNoteFocusRequest});

  /// All notes in insertion order (index 0 = most recently added).
  final List<Note> notes;

  /// Exactly [LayoutConstants.maxDraftNotes] drafts, oldest first (tab 0).
  /// Stable reference: rebuilt only when [notes] changes.
  final List<Note> draftNotes;

  /// Non-draft, non-deleted notes in time columns, most-recent first.
  /// Stable reference: rebuilt only when [notes] changes.
  final List<TimeColumnData> timeColumns;

  /// Soft-deleted notes, most recently deleted first.
  /// Stable reference: rebuilt only when [notes] changes.
  final List<Note> trashedNotes;

  /// Index of the currently visible draft tab (0-based).
  final int activeDraftIndex;

  /// Incremented each time the user requests focus on the new-note composer
  /// (e.g. via Cmd+K). Widgets detect the increment and grab keyboard focus.
  final int newNoteFocusRequest;

  /// All notes unmodifiable (for export / backup).
  List<Note> get allNotes => List<Note>.unmodifiable(notes);

  // ── Copy helper ────────────────────────────────────────────────────────────

  /// When [notes] is omitted, derived list fields keep their current
  /// references — [select] sees no change and skips widget rebuilds.
  /// When [notes] is provided, all three derived lists are recomputed.
  NotesState copyWith({
    List<Note>? notes,
    int? activeDraftIndex,
    int? newNoteFocusRequest,
  }) {
    if (notes == null) {
      // Only scalar fields changed — reuse existing list references.
      return NotesState._(
        notes: this.notes,
        draftNotes: draftNotes,
        timeColumns: timeColumns,
        trashedNotes: trashedNotes,
        activeDraftIndex: activeDraftIndex ?? this.activeDraftIndex,
        newNoteFocusRequest: newNoteFocusRequest ?? this.newNoteFocusRequest,
      );
    }
    // notes changed — recompute all derived views.
    return NotesState._(
      notes: notes,
      draftNotes: _computeDraftNotes(notes),
      timeColumns: _computeTimeColumns(notes),
      trashedNotes: _computeTrashedNotes(notes),
      activeDraftIndex: activeDraftIndex ?? this.activeDraftIndex,
      newNoteFocusRequest: newNoteFocusRequest ?? this.newNoteFocusRequest,
    );
  }

  // ── Static computation helpers ─────────────────────────────────────────────

  static List<Note> _computeDraftNotes(List<Note> notes) =>
      notes.where((n) => n.isDraft && !n.isDeleted).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  static List<TimeColumnData> _computeTimeColumns(List<Note> notes) {
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

  static List<Note> _computeTrashedNotes(List<Note> notes) =>
      notes.where((n) => n.isDeleted).toList()
        ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
}

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

    final initialNotes = ref.read(initialNotesProvider);
    return _ensureDraftSlots(
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
    _markDirty(note.id);
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
  /// (no debounce) so the caller can await completion.
  Future<void> importNotes(List<Note> notes) async {
    _saveTimer?.cancel();
    _saveTimer = null;
    _dirtyIds.clear();
    _removedIds.clear();

    var newState = NotesState(notes: List<Note>.from(notes));
    newState = _ensureDraftSlots(newState);
    state = newState;

    // Full overwrite for import — uses DELETE + INSERT.
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
    _persistDirty();
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
    unawaited(ref.read(notesServiceProvider).upsertNotes(newDrafts));
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
    _saveTimer = Timer(const Duration(milliseconds: 800), _persistDirty);
  }

  /// Writes only dirty and removed notes to the database.
  void _persistDirty() {
    final service = ref.read(notesServiceProvider);

    if (_dirtyIds.isNotEmpty) {
      final dirtyNotes =
          state.notes.where((n) => _dirtyIds.contains(n.id)).toList();
      unawaited(service.upsertNotes(dirtyNotes));
      _dirtyIds.clear();
    }

    if (_removedIds.isNotEmpty) {
      unawaited(service.deleteNotesByIds(Set<String>.from(_removedIds)));
      _removedIds.clear();
    }
  }
}
