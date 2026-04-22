import 'package:flutter/material.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_theme.dart';

/// Sticky column header showing the time group label and optional note count.
class ColumnHeader extends StatelessWidget {
  const ColumnHeader({
    super.key,
    required this.label,
    this.noteCount,
    this.emphasized = false,
  });

  final String label;
  final int? noteCount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: LayoutConstants.columnHeaderHeight,
      decoration: BoxDecoration(
        color: nc?.columnHeader ?? Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: nc?.columnBorder ?? Theme.of(context).dividerColor,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: LayoutConstants.pageHPad + 2,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: tt.titleMedium?.copyWith(
              color: emphasized ? scheme.primary : null,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          if (noteCount != null && noteCount! > 0) ...[
            const SizedBox(width: 8),
            CountBadge(count: noteCount!),
          ],
        ],
      ),
    );
  }
}

/// Small rounded badge showing a numeric count.
///
/// Shared across [ColumnHeader], [TrashColumn], and other column headers.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:
            nc?.badgeBackground ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: nc?.columnBorder ?? Theme.of(context).dividerColor,
        ),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: nc?.badgeForeground,
        ),
      ),
    );
  }
}
