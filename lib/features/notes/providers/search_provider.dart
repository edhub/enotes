import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class SearchQueryNotifier extends Notifier<SearchState> {
  @override
  SearchState build() => const SearchState();

  void set(String query) => state = state.copyWith(query: query);

  void clear() => state = state.copyWith(query: '');

  /// Signals [NoteSearchBar] to grab keyboard focus (used by Cmd+F).
  void requestFocus() =>
      state = state.copyWith(focusRequest: state.focusRequest + 1);
}

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
      final content = note.content.toLowerCase();
      return tokens.every((token) => content.contains(token));
    }).toList();

    if (matched.isNotEmpty) {
      result.add(
        TimeColumnData(
          bucketKey: col.bucketKey,
          group: col.group,
          label: col.label,
          notes: matched,
          sortOrder: col.sortOrder,
        ),
      );
    }
  }
  return result;
});
