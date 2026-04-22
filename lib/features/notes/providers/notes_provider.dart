import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_constants.dart';
import '../models/note.dart';
import '../models/time_group.dart';
import '../services/notes_service.dart';
import 'now_provider.dart';

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
final saveErrorProvider =
    NotifierProvider<SaveErrorNotifier, String?>(SaveErrorNotifier.new);

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
  ///
  /// [now] anchors the time-column bucketing. Defaults to `DateTime.now()`;
  /// pass an explicit value (e.g. from [currentDayProvider]) to keep
  /// bucketing stable across mutations and to make tests deterministic.
  NotesState({
    required List<Note> notes,
    DateTime? now,
    int activeDraftIndex = 0,
    int newNoteFocusRequest = 0,
    int draftFocusRequest = 0,
  }) : this._(
          notes: notes,
          now: now ?? DateTime.now(),
          draftNotes: _computeDraftNotes(notes),
          timeColumns: _computeTimeColumns(notes, now ?? DateTime.now()),
          trashedNotes: _computeTrashedNotes(notes),
          activeDraftIndex: activeDraftIndex,
          newNoteFocusRequest: newNoteFocusRequest,
          draftFocusRequest: draftFocusRequest,
        );

  /// Internal constructor: all fields supplied directly.
  /// Used by [copyWith] / [replaceContent] to preserve list references when
  /// the relevant slice of [notes] is unchanged.
  const NotesState._({
    required this.notes,
    required this.now,
    required this.draftNotes,
    required this.timeColumns,
    required this.trashedNotes,
    required this.activeDraftIndex,
    required this.newNoteFocusRequest,
    required this.draftFocusRequest,
  });

  /// All notes in insertion order (index 0 = most recently added).
  final List<Note> notes;

  /// Reference instant used for time-bucket computation. Stable across
  /// content-only mutations (see [replaceContent]); only changes when a
  /// new "now" is explicitly supplied (e.g. crossing midnight).
  final DateTime now;

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

  /// Incremented each time user requests focus on the active draft note editor
  /// (e.g. via Cmd+1~5). Draft card listens to this counter and grabs focus.
  final int draftFocusRequest;

  /// All notes unmodifiable (for export / backup).
  List<Note> get allNotes => List<Note>.unmodifiable(notes);

  // ── Copy helper ────────────────────────────────────────────────────────────

  /// When [notes] is omitted, derived list fields keep their current
  /// references — [select] sees no change and skips widget rebuilds.
  /// When [notes] is provided, all three derived lists are recomputed.
  ///
  /// [now], when provided, replaces the bucketing anchor and forces a
  /// full timeColumns recompute even if [notes] is unchanged (this is
  /// how midnight crossings are handled).
  NotesState copyWith({
    List<Note>? notes,
    DateTime? now,
    int? activeDraftIndex,
    int? newNoteFocusRequest,
    int? draftFocusRequest,
  }) {
    if (notes == null && now == null) {
      return NotesState._(
        notes: this.notes,
        now: this.now,
        draftNotes: draftNotes,
        timeColumns: timeColumns,
        trashedNotes: trashedNotes,
        activeDraftIndex: activeDraftIndex ?? this.activeDraftIndex,
        newNoteFocusRequest: newNoteFocusRequest ?? this.newNoteFocusRequest,
        draftFocusRequest: draftFocusRequest ?? this.draftFocusRequest,
      );
    }
    final effectiveNotes = notes ?? this.notes;
    final effectiveNow = now ?? this.now;
    return NotesState._(
      notes: effectiveNotes,
      now: effectiveNow,
      draftNotes: notes != null
          ? _computeDraftNotes(effectiveNotes)
          : draftNotes,
      timeColumns: _computeTimeColumns(effectiveNotes, effectiveNow),
      trashedNotes: notes != null
          ? _computeTrashedNotes(effectiveNotes)
          : trashedNotes,
      activeDraftIndex: activeDraftIndex ?? this.activeDraftIndex,
      newNoteFocusRequest: newNoteFocusRequest ?? this.newNoteFocusRequest,
      draftFocusRequest: draftFocusRequest ?? this.draftFocusRequest,
    );
  }

  /// Returns a new state where exactly one note has been replaced in-place
  /// (same id, different content / updatedAt). Optimised for the common
  /// per-keystroke editing path: only the affected derived list (drafts,
  /// timeColumns, or trash) is rebuilt. The other two retain their old
  /// references, so widgets that subscribe via `select` to *unrelated*
  /// columns will skip rebuilding entirely.
  ///
  /// Caller must guarantee that [oldNote] and [newNote] share the same
  /// `id`, `isDraft`, and `isDeleted` flags — [updateNote] is the only
  /// caller and enforces this.
  NotesState replaceContent({
    required List<Note> notes,
    required Note oldNote,
    required Note newNote,
  }) {
    assert(oldNote.id == newNote.id);
    assert(oldNote.isDraft == newNote.isDraft);
    assert(oldNote.isDeleted == newNote.isDeleted);

    final newDraftNotes = newNote.isDraft && !newNote.isDeleted
        ? _replaceInList(draftNotes, oldNote, newNote)
        : draftNotes;
    final newTrashedNotes = newNote.isDeleted
        ? _replaceInList(trashedNotes, oldNote, newNote)
        : trashedNotes;
    final newTimeColumns = (!newNote.isDraft && !newNote.isDeleted)
        ? _replaceInTimeColumns(timeColumns, oldNote, newNote)
        : timeColumns;

    return NotesState._(
      notes: notes,
      now: now,
      draftNotes: newDraftNotes,
      timeColumns: newTimeColumns,
      trashedNotes: newTrashedNotes,
      activeDraftIndex: activeDraftIndex,
      newNoteFocusRequest: newNoteFocusRequest,
      draftFocusRequest: draftFocusRequest,
    );
  }

  // ── Static computation helpers ─────────────────────────────────────────────

  static List<Note> _computeDraftNotes(List<Note> notes) =>
      notes.where((n) => n.isDraft && !n.isDeleted).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  static List<TimeColumnData> _computeTimeColumns(
    List<Note> notes,
    DateTime now,
  ) {
    final Map<String, List<Note>> buckets = {'today': []};
    for (final note in notes.where((n) => !n.isDraft && !n.isDeleted)) {
      final key = TimeGroupHelper.bucketKey(note.createdAt, now: now);
      (buckets[key] ??= []).add(note);
    }
    return buckets.entries
        .map((entry) {
          final sortedNotes = List<Note>.from(entry.value)
            ..sort(_compareByCreatedAtDesc);
          return TimeColumnData(
            bucketKey: entry.key,
            label: TimeGroupHelper.labelFromKey(entry.key),
            notes: sortedNotes,
            sortOrder: TimeGroupHelper.sortOrder(entry.key, now: now),
          );
        })
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  static int _compareByCreatedAtDesc(Note a, Note b) {
    final byCreatedAt = b.createdAt.compareTo(a.createdAt);
    if (byCreatedAt != 0) return byCreatedAt;
    return b.id.compareTo(a.id);
  }

  static List<Note> _computeTrashedNotes(List<Note> notes) =>
      notes.where((n) => n.isDeleted).toList()
        ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));

  /// Returns a new list with [oldNote] replaced by [newNote] (matched by id).
  /// If no element matches, returns the original list reference unchanged.
  static List<Note> _replaceInList(
    List<Note> list,
    Note oldNote,
    Note newNote,
  ) {
    final idx = list.indexWhere((n) => n.id == oldNote.id);
    if (idx == -1) return list;
    final updated = List<Note>.from(list);
    updated[idx] = newNote;
    return updated;
  }

  /// Walks [columns] looking for [oldNote]; rebuilds only the column
  /// containing it. Other column references are preserved verbatim.
  static List<TimeColumnData> _replaceInTimeColumns(
    List<TimeColumnData> columns,
    Note oldNote,
    Note newNote,
  ) {
    for (var i = 0; i < columns.length; i++) {
      final col = columns[i];
      final idx = col.notes.indexWhere((n) => n.id == oldNote.id);
      if (idx == -1) continue;
      final newNotes = List<Note>.from(col.notes);
      newNotes[idx] = newNote;
      final updated = List<TimeColumnData>.from(columns);
      updated[i] = TimeColumnData(
        bucketKey: col.bucketKey,
        label: col.label,
        notes: newNotes,
        sortOrder: col.sortOrder,
      );
      return updated;
    }
    return columns;
  }
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

    // Re-bucket time columns when the calendar day changes (e.g. midnight).
    ref.listen(currentDayProvider, (_, today) {
      // Use the day boundary as the new "now": noon-of-today is good enough,
      // it just needs to fall inside the new day.
      state = state.copyWith(
        now: today.add(const Duration(hours: 12)),
      );
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
    state = state.copyWith(
      newNoteFocusRequest: state.newNoteFocusRequest + 1,
    );
  }

  /// Signals the currently active draft editor to take keyboard focus.
  void requestDraftFocus() {
    state = state.copyWith(
      draftFocusRequest: state.draftFocusRequest + 1,
    );
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
  Future<void> _persistDirty() async {
    final service = ref.read(notesServiceProvider);

    if (_dirtyIds.isNotEmpty) {
      final dirtyNotes =
          state.notes.where((n) => _dirtyIds.contains(n.id)).toList();
      _dirtyIds.clear();
      await _safeUpsert(dirtyNotes);
    }

    if (_removedIds.isNotEmpty) {
      final ids = Set<String>.from(_removedIds);
      _removedIds.clear();
      await _safeDelete(service, ids);
    }
  }

  Future<void> _safeUpsert(List<Note> notes) async {
    if (notes.isEmpty) return;
    try {
      await ref.read(notesServiceProvider).upsertNotes(notes);
    } catch (e, st) {
      log('NotesNotifier: upsert failed: $e', error: e, stackTrace: st);
      ref
          .read(saveErrorProvider.notifier)
          .report('Failed to save changes: $e');
    }
  }

  Future<void> _safeDelete(NotesService service, Set<String> ids) async {
    try {
      await service.deleteNotesByIds(ids);
    } catch (e, st) {
      log('NotesNotifier: delete failed: $e', error: e, stackTrace: st);
      ref
          .read(saveErrorProvider.notifier)
          .report('Failed to delete notes: $e');
    }
  }
}
