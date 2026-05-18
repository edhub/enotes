import 'package:flutter_test/flutter_test.dart';

import 'package:enotes/features/notes/models/time_group.dart';

void main() {
  group('TimeGroupHelper.bucketKey', () {
    test('today returns "today"', () {
      final now = DateTime(2026, 4, 11, 12, 0);
      final noteTime = DateTime(2026, 4, 11, 9, 0).toUtc();
      expect(TimeGroupHelper.bucketKey(noteTime, now: now), 'today');
    });

    test('yesterday returns "yesterday"', () {
      final now = DateTime(2026, 4, 11, 12, 0);
      final noteTime = DateTime(2026, 4, 10, 9, 0).toUtc();
      expect(TimeGroupHelper.bucketKey(noteTime, now: now), 'yesterday');
    });

    test('this week returns "this_week"', () {
      // Apr 11 2026 is Saturday; Monday of that week is Apr 6.
      final now = DateTime(2026, 4, 11, 12, 0); // Saturday
      final noteTime = DateTime(2026, 4, 7, 9, 0).toUtc(); // Tuesday
      expect(TimeGroupHelper.bucketKey(noteTime, now: now), 'this_week');
    });

    test('last week returns "last_week"', () {
      final now = DateTime(2026, 4, 11, 12, 0); // Saturday
      // Last week's Monday = Mar 30
      final noteTime = DateTime(2026, 3, 31, 9, 0).toUtc(); // Tuesday last week
      expect(TimeGroupHelper.bucketKey(noteTime, now: now), 'last_week');
    });

    test('older dates return week_YYYY_M_D', () {
      final now = DateTime(2026, 4, 11, 12, 0);
      // Two weeks ago: Monday Mar 23
      final noteTime = DateTime(2026, 3, 24, 9, 0).toUtc();
      final key = TimeGroupHelper.bucketKey(noteTime, now: now);
      expect(key, startsWith('week_'));
      expect(key, contains('2026'));
    });
  });

  group('TimeGroupHelper.labelFromKey', () {
    test('known keys return readable labels', () {
      expect(TimeGroupHelper.labelFromKey('today'), 'Today');
      expect(TimeGroupHelper.labelFromKey('yesterday'), 'Yesterday');
      expect(TimeGroupHelper.labelFromKey('this_week'), 'This Week');
      expect(TimeGroupHelper.labelFromKey('last_week'), 'Last Week');
    });

    test('with now, today and yesterday show calendar dates', () {
      final now = DateTime(2026, 5, 18, 12, 0);
      expect(TimeGroupHelper.labelFromKey('today', now: now), 'May 18');
      expect(TimeGroupHelper.labelFromKey('yesterday', now: now), 'May 17');
    });

    test('with now, last_week shows ISO week instead of generic label', () {
      final now = DateTime(2026, 4, 11, 12, 0);
      final label = TimeGroupHelper.labelFromKey('last_week', now: now);
      expect(label, isNot('Last Week'));
      expect(label, contains('2026'));
      expect(label, contains('W'));
    });

    test('iso week key returns "YYYY WNN" format', () {
      final label = TimeGroupHelper.labelFromKey('week_2026_3_16');
      expect(label, contains('2026'));
      expect(label, contains('W'));
    });
  });

  group('TimeGroupHelper.sortOrder', () {
    test('today < yesterday < this_week < last_week', () {
      final now = DateTime(2026, 4, 11, 12, 0);
      final t = TimeGroupHelper.sortOrder('today', now: now);
      final y = TimeGroupHelper.sortOrder('yesterday', now: now);
      final tw = TimeGroupHelper.sortOrder('this_week', now: now);
      final lw = TimeGroupHelper.sortOrder('last_week', now: now);
      expect(t, lessThan(y));
      expect(y, lessThan(tw));
      expect(tw, lessThan(lw));
    });

    test('older weeks have higher sort order', () {
      final now = DateTime(2026, 4, 11, 12, 0);
      final lw = TimeGroupHelper.sortOrder('last_week', now: now);
      final old = TimeGroupHelper.sortOrder('week_2026_3_16', now: now);
      expect(old, greaterThan(lw));
    });
  });

  group('TimeGroupHelper.isoWeekNumber', () {
    test('Jan 1 2026 is week 1', () {
      // Jan 1 2026 is a Thursday → ISO week 1.
      expect(TimeGroupHelper.isoWeekNumber(DateTime(2026, 1, 1)), 1);
    });

    test('Dec 31 2025 may be week 1 of 2026', () {
      // Dec 31 2025 is Wednesday → belongs to ISO week 1 of 2026.
      final week = TimeGroupHelper.isoWeekNumber(DateTime(2025, 12, 31));
      expect(week, 1);
    });
  });
}
