import 'package:intl/intl.dart';

import 'note.dart';

/// Data for one rendered time column.
class TimeColumnData {
  const TimeColumnData({
    required this.bucketKey,
    required this.label,
    required this.notes,
    required this.sortOrder,
  });

  /// Unique stable key (e.g. 'today', 'last_week', 'week_2026_3_16').
  final String bucketKey;

  /// Human-readable header label ("May 18", "2026 W11", …).
  final String label;

  /// Active notes in a stable, explicit UI order.
  ///
  /// eNotes renders notes oldest-first within each time column (newest at the
  /// bottom); order is by [Note.createdAt] ascending.
  final List<Note> notes;

  /// Lower value = more recent = rendered further left.
  final int sortOrder;

  int get totalCount => notes.length;
}

/// Pure-function helpers for time grouping. No state.
abstract final class TimeGroupHelper {
  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns the bucket key for a note's [createdAt] (converted to local time).
  ///
  /// Key format:
  ///   'today' | 'yesterday' | 'this_week' | 'last_week' | 'week_YYYY_M_D'
  static String bucketKey(DateTime createdAt, {DateTime? now}) {
    final today = _dateOnly(now?.toLocal() ?? DateTime.now());
    final noteDate = _dateOnly(createdAt.toLocal());

    if (noteDate == today) return 'today';
    if (noteDate == today.subtract(const Duration(days: 1))) return 'yesterday';

    final thisMonday = _weekMonday(today);
    final noteMonday = _weekMonday(noteDate);

    if (noteMonday == thisMonday) return 'this_week';

    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    if (noteMonday == lastMonday) return 'last_week';

    return 'week_${noteMonday.year}_${noteMonday.month}_${noteMonday.day}';
  }

  /// Human-readable column header label for a given bucket key.
  ///
  /// When [now] is provided, 'today' and 'yesterday' show the actual date
  /// (e.g. "May 18") instead of the generic word.
  static String labelFromKey(String key, {DateTime? now}) {
    if (now != null) {
      final today = _dateOnly(now.toLocal());
      final fmt = DateFormat('MMM d');
      if (key == 'today') return fmt.format(today);
      if (key == 'yesterday') {
        return fmt.format(today.subtract(const Duration(days: 1)));
      }
      if (key == 'last_week') {
        final lastMonday = _weekMonday(today).subtract(const Duration(days: 7));
        return _weekLabel(lastMonday);
      }
    }
    return switch (key) {
      'today' => 'Today',
      'yesterday' => 'Yesterday',
      'this_week' => 'This Week',
      'last_week' => 'Last Week',
      _ => _isoWeekLabel(key),
    };
  }

  /// Sort priority: lower = more recent = further left on screen.
  static int sortOrder(String key, {DateTime? now}) => switch (key) {
    'today' => 0,
    'yesterday' => 1,
    'this_week' => 2,
    'last_week' => 3,
    _ => _isoWeekSortOrder(key, now: now),
  };

  /// ISO 8601 week number (Monday-based, 1-53).
  static int isoWeekNumber(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final jan1 = DateTime(thursday.year, 1, 1);
    return ((thursday.difference(jan1).inDays) / 7).floor() + 1;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static DateTime _weekMonday(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  /// Parses 'week_YYYY_M_D' into a [DateTime] (the Monday of that week).
  static DateTime? _parseWeekKey(String key) {
    final parts = key.split('_');
    if (parts.length != 4) return null;
    final year = int.tryParse(parts[1]);
    final month = int.tryParse(parts[2]);
    final day = int.tryParse(parts[3]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  static String _weekLabel(DateTime monday) {
    final week = isoWeekNumber(monday);
    return '${monday.year} W${week.toString().padLeft(2, '0')}';
  }

  static String _isoWeekLabel(String key) {
    final monday = _parseWeekKey(key);
    if (monday == null) return key;
    return _weekLabel(monday);
  }

  static int _isoWeekSortOrder(String key, {DateTime? now}) {
    final monday = _parseWeekKey(key);
    if (monday == null) return 999999;
    final daysAgo = (now?.toLocal() ?? DateTime.now())
        .difference(monday)
        .inDays;
    return 4 + daysAgo;
  }
}
