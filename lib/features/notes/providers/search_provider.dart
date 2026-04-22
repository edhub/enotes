import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/note.dart';
import '../models/time_group.dart';
import 'notes_provider.dart';

// ── State ─────────────────────────────────────────────────────────────────────

/// Immutable state for the search feature.
@immutable
class SearchState {
  const SearchState({this.query = '', this.focusRequest = 0});

  /// The active filter string. Empty means no filter.
  final String query;

  /// Incremented each time Cmd+F is pressed. [NoteSearchBar] watches this
  /// to grab keyboard focus without needing a direct widget reference.
  final int focusRequest;

  SearchState copyWith({String? query, int? focusRequest}) => SearchState(
        query: query ?? this.query,
        focusRequest: focusRequest ?? this.focusRequest,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, SearchState>(
  SearchQueryNotifier.new,
);

/// Debounce window applied to keystrokes before they reach the filter.
/// Short enough to feel instant, long enough to skip per-keystroke fan-out
/// across hundreds of notes.
const _searchDebounce = Duration(milliseconds: 120);

class SearchQueryNotifier extends Notifier<SearchState> {
  Timer? _debounce;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  /// Debounced query update — call from `onChanged`.
  void set(String query) {
    _debounce?.cancel();
    if (query.isEmpty) {
      // Empty / clear is applied immediately so the UI doesn't briefly
      // keep showing stale filtered results.
      state = state.copyWith(query: query);
      return;
    }
    _debounce = Timer(_searchDebounce, () {
      state = state.copyWith(query: query);
    });
  }

  void clear() {
    _debounce?.cancel();
    state = state.copyWith(query: '');
  }

  /// Signals [NoteSearchBar] to grab keyboard focus (used by Cmd+F).
  void requestFocus() =>
      state = state.copyWith(focusRequest: state.focusRequest + 1);
}

// ── Lowercase content cache ───────────────────────────────────────────────────

/// Caches `note.content.toLowerCase()` per note id, keyed on the note's
/// `updatedAt` so it auto-invalidates whenever the content changes.
///
/// Without this cache, every keystroke in the search bar re-lowercases
/// every note's full content — wasted work for the (common) case where
/// the same notes survive across many filter passes.
class _LowercaseCache {
  final Map<String, _Entry> _cache = {};

  String get(Note note) {
    final entry = _cache[note.id];
    if (entry != null && entry.updatedAt == note.updatedAt) return entry.lower;
    final lower = note.content.toLowerCase();
    _cache[note.id] = _Entry(note.updatedAt, lower);
    return lower;
  }
}

class _Entry {
  const _Entry(this.updatedAt, this.lower);
  final DateTime updatedAt;
  final String lower;
}

final _lowercaseCache = _LowercaseCache();

// ── Filtered columns ──────────────────────────────────────────────────────────

/// Derives the visible time columns by applying [searchQueryProvider] as a
/// filter over [notesProvider]'s time columns.
///
/// Rules:
/// - Empty query → returns all columns unchanged.
/// - Non-empty query → splits by whitespace into tokens; a note matches only
///   if ALL tokens appear as case-insensitive substrings in [Note.content].
/// - Columns with zero matching notes are omitted from the result.
final filteredTimeColumnsProvider = Provider<List<TimeColumnData>>((ref) {
  final query =
      ref.watch(searchQueryProvider.select((s) => s.query)).trim();
  final columns = ref.watch(notesProvider.select((s) => s.timeColumns));

  if (query.isEmpty) return columns;

  final tokens = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  final result = <TimeColumnData>[];
  for (final col in columns) {
    final matched = col.notes.where((note) {
      final content = _lowercaseCache.get(note);
      return tokens.every((token) => content.contains(token));
    }).toList();

    if (matched.isNotEmpty) {
      result.add(
        TimeColumnData(
          bucketKey: col.bucketKey,
          label: col.label,
          notes: matched,
          sortOrder: col.sortOrder,
        ),
      );
    }
  }
  return result;
});
