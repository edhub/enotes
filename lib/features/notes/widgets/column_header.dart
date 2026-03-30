import 'package:flutter/material.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_theme.dart';

/// Sticky column header showing the time group label and optional note count.
class ColumnHeader extends StatelessWidget {
  const ColumnHeader({
    super.key,
    required this.label,
    required this.isDraft,
    this.noteCount,
  });

  final String label;
  final bool isDraft;
  final int? noteCount;

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();
    final tt = Theme.of(context).textTheme;

    return Container(
      height: LayoutConstants.columnHeaderHeight,
      color: nc?.columnHeader ?? Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: LayoutConstants.pageHPad,
      ),
      child: Row(
        children: [
          if (isDraft)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.edit_note_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          Text(label, style: tt.titleMedium),
          if (noteCount != null && noteCount! > 0) ...[
            const SizedBox(width: 8),
            _CountBadge(count: noteCount!),
          ],
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
