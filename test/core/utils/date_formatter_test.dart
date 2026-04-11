import 'package:flutter_test/flutter_test.dart';

import 'package:enotes/core/utils/date_formatter.dart';

void main() {
  group('DateFormatter.relative', () {
    test('just now — less than 60 seconds ago', () {
      final now = DateTime.now();
      final result = DateFormatter.relative(now.toUtc());
      expect(result, 'just now');
    });

    test('minutes ago', () {
      final time = DateTime.now().subtract(const Duration(minutes: 5)).toUtc();
      final result = DateFormatter.relative(time);
      expect(result, '5m ago');
    });

    test('hours ago', () {
      final time = DateTime.now().subtract(const Duration(hours: 3)).toUtc();
      final result = DateFormatter.relative(time);
      expect(result, '3h ago');
    });

    test('yesterday', () {
      final time = DateTime.now().subtract(const Duration(hours: 30)).toUtc();
      final result = DateFormatter.relative(time);
      expect(result, 'yesterday');
    });

    test('days ago', () {
      final time = DateTime.now().subtract(const Duration(days: 10)).toUtc();
      final result = DateFormatter.relative(time);
      expect(result, '10d ago');
    });

    test('months ago', () {
      final time = DateTime.now().subtract(const Duration(days: 60)).toUtc();
      final result = DateFormatter.relative(time);
      expect(result, '2mo ago');
    });

    test('with prefix', () {
      final now = DateTime.now();
      final result = DateFormatter.relative(now.toUtc(), prefix: 'deleted');
      expect(result, 'deleted just now');
    });

    test('with prefix — days ago', () {
      final time = DateTime.now().subtract(const Duration(days: 5)).toUtc();
      final result = DateFormatter.relative(time, prefix: 'deleted');
      expect(result, 'deleted 5d ago');
    });
  });

  group('DateFormatter.absolute', () {
    test('formats date with month name and time', () {
      // Use a fixed local time for predictable output.
      final dt = DateTime.utc(2026, 3, 15, 14, 30);
      final result = DateFormatter.absolute(dt);
      // The output depends on local timezone offset, but the format is stable.
      expect(result, contains('Mar'));
      expect(result, contains(':'));
    });
  });
}
