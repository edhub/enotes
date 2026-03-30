import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import '../../../core/constants/layout_constants.dart';
import '../models/note.dart';
import '../models/time_group.dart';
import '../services/notes_service.dart';

/// Central state for all notes.
///
/// Responsibilities:
///   - Owns the single [_notes] list (insertion order, newest at index 0)
///   - Derives [draftNotes] and [timeColumns] as pure computed views
///   - Handles CRUD with stable position guarantee (update ≠ re-order)
///   - Schedules debounced persistence via [NotesService]
class NotesProvider extends ChangeNotifier {
  NotesProvider({
    required NotesService service,
    required List<Note> initialNotes,
  })  : _service = service,
        _notes = List<Note>.from(initialNotes);

  final NotesService _service;

  /// All notes in insertion order. Index 0 = most recently added.
  /// Never sort this list — order = display order within each column.
  final List<Note> _notes;

  int _activeDraftIndex = 0;
  Timer? _saveTimer;

  /// ID of the note that should receive focus on its next build.
  /// Set by [addNote]; cleared by the NoteCard itself after requesting focus.
  String? _pendingFocusNoteId;
  String? get pendingFocusNoteId => _pendingFocusNoteId;

  void clearPendingFocus() => _pendingFocusNoteId = null;

  // ── Computed views ─────────────────────────────────────────────────────────

  /// Up to [LayoutConstants.maxDraftNotes] drafts, ordered newest-first.
  List<Note> get draftNotes {
    final drafts = _notes.where((n) => n.isDraft).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return drafts.take(LayoutConstants.maxDraftNotes).toList();
  }

  /// Whether a new draft can be created.
  bool get canAddDraft => draftNotes.length < LayoutConstants.maxDraftNotes;

  /// Index of the currently visible draft card (0-based).
  int get activeDraftIndex => _activeDraftIndex;

  /// Non-draft notes grouped into time columns, sorted most-recent first.
  /// Notes within each column preserve [_notes] insertion order (stable).
  List<TimeColumnData> get timeColumns {
    final now = DateTime.now();
    final Map<String, List<Note>> buckets = {};

    for (final note in _notes.where((n) => !n.isDraft)) {
      final key = TimeGroupHelper.bucketKey(note.createdAt, now: now);
      (buckets[key] ??= []).add(note);
    }

    return buckets.entries.map((entry) {
      final notes = entry.value;
      final pinned = notes.where((n) => n.isPinned).toList()
        ..sort((a, b) => (b.pinnedOrder ?? 0).compareTo(a.pinnedOrder ?? 0));
      final regular = notes.where((n) => !n.isPinned).toList();

      return TimeColumnData(
        bucketKey: entry.key,
        group: TimeGroupHelper.groupFromKey(entry.key),
        label: TimeGroupHelper.labelFromKey(entry.key),
        pinnedNotes: pinned,
        regularNotes: regular,
        sortOrder: TimeGroupHelper.sortOrder(entry.key, now: now),
      );
    }).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  /// Adds a new note. Draft notes are placed in the draft switcher.
  /// Ignored if [isDraft] is true and [canAddDraft] is false.
  void addNote(String content, {bool isDraft = false}) {
    if (isDraft && !canAddDraft) {
      log('NotesProvider: draft slots full (max ${LayoutConstants.maxDraftNotes})');
      return;
    }
    final note = Note.create(content: content, isDraft: isDraft);
    _notes.insert(0, note);
    _pendingFocusNoteId = note.id;
    if (isDraft) _activeDraftIndex = 0;
    _commitAndNotify();
  }

  /// Updates note content in-place. Position in the list is preserved.
  void updateNote(String id, String content) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    _notes[idx] = _notes[idx].copyWith(
      content: content,
      updatedAt: DateTime.now().toUtc(),
    );
    _commitAndNotify();
  }

  /// Toggles the pinned state. Newly pinned notes get the current timestamp
  /// as [pinnedOrder] so they appear at the top of their column.
  void togglePin(String id) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final note = _notes[idx];
    _notes[idx] = note.isPinned
        ? note.copyWith(isPinned: false, clearPinnedOrder: true)
        : note.copyWith(
            isPinned: true,
            pinnedOrder: DateTime.now().millisecondsSinceEpoch,
          );
    _commitAndNotify();
  }

  /// Moves a note between draft and timeline.
  /// No-op if moving to draft and [canAddDraft] is false.
  void toggleDraft(String id) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final note = _notes[idx];
    if (!note.isDraft && !canAddDraft) {
      log('NotesProvider: cannot move to draft — slots full');
      return;
    }
    _notes[idx] = note.copyWith(isDraft: !note.isDraft);
    _clampDraftIndex();
    _commitAndNotify();
  }

  /// Permanently removes a note.
  void deleteNote(String id) {
    _notes.removeWhere((n) => n.id == id);
    _clampDraftIndex();
    _commitAndNotify();
  }

  /// Switches the visible draft card. Clamps to valid range automatically.
  void setActiveDraftIndex(int index) {
    final drafts = draftNotes;
    if (drafts.isEmpty) return;
    final clamped = index.clamp(0, drafts.length - 1);
    if (_activeDraftIndex == clamped) return;
    _activeDraftIndex = clamped;
    notifyListeners();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Cancels the debounce timer and writes immediately.
  /// Call from [WidgetsBindingObserver] when the app goes inactive.
  void flushSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _service.saveNotes(List<Note>.unmodifiable(_notes));
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  /// Ensures [_activeDraftIndex] stays in bounds after a draft list change.
  void _clampDraftIndex() {
    final len = draftNotes.length;
    if (len == 0) {
      _activeDraftIndex = 0;
    } else if (_activeDraftIndex >= len) {
      _activeDraftIndex = len - 1;
    }
  }

  /// Notifies listeners and schedules a debounced (800ms) save.
  void _commitAndNotify() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 800),
      () => _service.saveNotes(List<Note>.unmodifiable(_notes)),
    );
  }
}
