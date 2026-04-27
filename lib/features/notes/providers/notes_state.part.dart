part of 'notes_provider.dart';

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
    return buckets.entries.map((entry) {
      final sortedNotes = List<Note>.from(entry.value)
        ..sort(_compareByCreatedAtDesc);
      return TimeColumnData(
        bucketKey: entry.key,
        label: TimeGroupHelper.labelFromKey(entry.key),
        notes: sortedNotes,
        sortOrder: TimeGroupHelper.sortOrder(entry.key, now: now),
      );
    }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
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
