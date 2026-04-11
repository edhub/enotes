import 'package:flutter/material.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_theme.dart';

/// Shared card decoration wrapper used by [NoteCard], [TrashNoteCard],
/// and [_NewNoteComposer] to ensure consistent visual styling.
///
/// Provides the standard border, shadow, background, and hover/focus
/// animation that all note cards share.
class NoteCardContainer extends StatelessWidget {
  const NoteCardContainer({
    super.key,
    required this.child,
    this.focused = false,
    this.hovered = false,
    this.backgroundColor,
    this.minHeight,
    this.padding,
  });

  final Widget child;
  final bool focused;
  final bool hovered;
  final Color? backgroundColor;
  final double? minHeight;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nc = Theme.of(context).extension<NoteColors>();

    final borderColor = focused
        ? Theme.of(context).colorScheme.primary
        : (nc?.cardBorder ?? Colors.grey.shade200);

    final bgColor = backgroundColor ?? Theme.of(context).cardTheme.color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      constraints: minHeight != null
          ? BoxConstraints(minHeight: minHeight!)
          : const BoxConstraints(),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(LayoutConstants.cardBorderRadius),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: (focused || hovered)
            ? [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: padding ?? const EdgeInsets.all(LayoutConstants.cardPadding),
      child: child,
    );
  }
}
