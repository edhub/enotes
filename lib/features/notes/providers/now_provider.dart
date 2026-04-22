import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the current local calendar day (year/month/day at 00:00) and
/// emits a new value whenever the day changes.
///
/// Subscribed by [notesProvider] so that the time-column buckets are
/// re-computed across midnight without requiring any user interaction —
/// without this, a note created at 23:59 would still appear in "Today"
/// the next morning until the user typed something.
///
/// We deliberately track *day* rather than wall-clock time: this keeps
/// the bucket-recompute work to at most one trigger per day, instead of
/// once per minute as a naive `DateTime.now()` ticker would.
final currentDayProvider = NotifierProvider<CurrentDayNotifier, DateTime>(
  CurrentDayNotifier.new,
);

class CurrentDayNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final today = _today();
      if (today != state) state = today;
    });
    return _today();
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
