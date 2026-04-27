import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Shared column panel decoration used by [DraftColumn], [TimeColumn], and
/// [TrashColumn]. Provides the consistent rounded border, light shadow, and
/// surface color that all three columns share.
class ColumnPanel extends StatelessWidget {
  const ColumnPanel({
    super.key,
    required this.surfaceColor,
    required this.width,
    required this.height,
    required this.child,
  });

  final Color surfaceColor;
  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();
    final borderColor = nc?.columnBorder ?? Theme.of(context).dividerColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.16)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: child,
        ),
      ),
    );
  }
}
