/// Relative time formatting utilities.
///
/// Used by note cards and trash cards to display human-readable timestamps
/// like "just now", "5m ago", "2h ago", "Jan 15, 09:30".
abstract final class DateFormatter {
  /// Formats [dateTime] as a relative time string (e.g. "just now", "5m ago").
  ///
  /// If [prefix] is provided, it is prepended (e.g. prefix "deleted" →
  /// "deleted just now"). The [dateTime] is converted to local time first.
  static String relative(DateTime dateTime, {String? prefix}) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    final String body;
    if (diff.inSeconds < 60) {
      body = 'just now';
    } else if (diff.inMinutes < 60) {
      body = '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      body = '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      body = 'yesterday';
    } else if (diff.inDays < 30) {
      body = '${diff.inDays}d ago';
    } else if (diff.inDays < 365) {
      body = '${diff.inDays ~/ 30}mo ago';
    } else {
      body = _absolute(local);
    }

    if (prefix != null && prefix.isNotEmpty) return '$prefix $body';
    return body;
  }

  /// Formats [dateTime] as an absolute date string (e.g. "Jan 15, 09:30").
  ///
  /// The [dateTime] is converted to local time first.
  static String absolute(DateTime dateTime) => _absolute(dateTime.toLocal());

  static String _absolute(DateTime local) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[local.month]} ${local.day},  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
