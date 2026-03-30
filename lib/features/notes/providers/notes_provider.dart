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
///   - Derives [draftNotes], [timeColumns], and [trashedNotes] as pure computed views
///   - Draft notes: always exactly [LayoutConstants.maxDraftNotes] slots (permanent tabs)
///   - Regular notes: soft-deleted into [trashedNotes]; restored or permanently removed
///   - Schedules debounced persistence via [NotesService]
class NotesProvider extends ChangeNotifier {
  NotesProvider({
    required NotesService service,
    required List<Note> initialNotes,
  })  : _service = service,
        _notes = List<Note>.from(initialNotes) {
    _ensureFiveDrafts();
  }

  final NotesService _service;

  /// All notes in insertion order. Index 0 = most recently added.
  final List<Note> _notes;

  int _activeDraftIndex = 0;
  Timer? _saveTimer;

  /// ID of the note that should receive focus on its next build.
  String? _pendingFocusNoteId;
  String? get pendingFocusNoteId => _pendingFocusNoteId;

  void clearPendingFocus() => _pendingFocusNoteId = null;

  // ── Computed views ─────────────────────────────────────────────────────────

  /// Exactly [LayoutConstants.maxDraftNotes] drafts, ordered by createdAt
  /// ascending (oldest = tab 0, newest = last tab). Guaranteed non-empty.
  List<Note> get draftNotes {
    return _notes
        .where((n) => n.isDraft && !n.isDeleted)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Index of the currently visible draft card (0-based).
  int get activeDraftIndex => _activeDraftIndex;

  /// Non-draft, non-deleted notes grouped into time columns, sorted most-recent first.
  /// Notes within each column preserve [_notes] insertion order (stable).
  List<TimeColumnData> get timeColumns {
    final now = DateTime.now();
    final Map<String, List<Note>> buckets = {};

    for (final note in _notes.where((n) => !n.isDraft && !n.isDeleted)) {
      final key = TimeGroupHelper.bucketKey(note.createdAt, now: now);
      (buckets[key] ??= []).add(note);
    }

    return buckets.entries.map((entry) {
      return TimeColumnData(
        bucketKey: entry.key,
        group: TimeGroupHelper.groupFromKey(entry.key),
        label: TimeGroupHelper.labelFromKey(entry.key),
        notes: entry.value,
        sortOrder: TimeGroupHelper.sortOrder(entry.key, now: now),
      );
    }).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Soft-deleted notes, sorted by deletion time (most recently deleted first).
  List<Note> get trashedNotes {
    return _notes
        .where((n) => n.isDeleted)
        .toList()
      ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  /// Adds a new regular (non-draft) note.
  void addNote(String content) {
    final note = Note.create(content: content, isDraft: false);
    _notes.insert(0, note);
    _pendingFocusNoteId = note.id;
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

  /// Soft-deletes a regular note (moves it to the trash).
  /// Draft notes cannot be deleted.
  void deleteNote(String id) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    if (_notes[idx].isDraft) {
      log('NotesProvider: draft notes cannot be deleted');
      return;
    }
    _notes[idx] = _notes[idx].copyWith(
      deletedAt: DateTime.now().toUtc(),
    );
    _commitAndNotify();
  }

  /// Restores a soft-deleted note back to its original column.
  void restoreNote(String id) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    _notes[idx] = _notes[idx].copyWith(clearDeletedAt: true);
    _commitAndNotify();
  }

  /// Permanently removes a single note from storage (trash only).
  void permanentlyDeleteNote(String id) {
    _notes.removeWhere((n) => n.id == id);
    _commitAndNotify();
  }

  /// Permanently removes all soft-deleted notes.
  void emptyTrash() {
    _notes.removeWhere((n) => n.isDeleted);
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

  /// Ensures exactly [LayoutConstants.maxDraftNotes] draft slots exist.
  /// Called once in the constructor. If new drafts are added, saves immediately.
  void _ensureFiveDrafts() {
    final existing = _notes.where((n) => n.isDraft).length;
    if (existing >= LayoutConstants.maxDraftNotes) return;
    for (int i = existing; i < LayoutConstants.maxDraftNotes; i++) {
      _notes.add(Note.create(content: '', isDraft: true));
    }
    // Persist the newly created slots without waiting for debounce.
    unawaited(_service.saveNotes(List<Note>.unmodifiable(_notes)));
  }

  /// Notifies listeners and schedules a debounced (800 ms) save.
  void _commitAndNotify() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 800),
      () => _service.saveNotes(List<Note>.unmodifiable(_notes)),
    );
  }
}
