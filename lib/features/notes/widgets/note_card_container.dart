import 'package:flutter/material.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_theme.dart';

/// Shared card decoration wrapper used by [NoteCard] and [TrashNoteCard]
/// to ensure consistent visual styling.
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
        ? (nc?.cardBorderFocused ?? Theme.of(context).colorScheme.primary)
        : hovered
        ? (nc?.cardBorderHover ?? nc?.cardBorder ?? Colors.grey.shade200)
        : (nc?.cardBorder ?? Colors.grey.shade200);

    final bgColor = backgroundColor ?? Theme.of(context).cardTheme.color;

    final shadow = switch ((focused, hovered, isDark)) {
      (true, _, true) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color:
              (nc?.cardBorderFocused ?? Theme.of(context).colorScheme.primary)
                  .withValues(alpha: 0.18),
          blurRadius: 0,
          spreadRadius: 2,
        ),
      ],
      (true, _, false) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color:
              (nc?.cardBorderFocused ?? Theme.of(context).colorScheme.primary)
                  .withValues(alpha: 0.14),
          blurRadius: 0,
          spreadRadius: 2,
        ),
      ],
      (false, true, true) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
      (false, true, false) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.07),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
      (_, _, true) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      _ => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      constraints: minHeight != null
          ? BoxConstraints(minHeight: minHeight!)
          : const BoxConstraints(),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(LayoutConstants.cardBorderRadius),
        // Keep border width stable across hover/focus states so the inner
        // content width never changes and text does not reflow when editing
        // starts. Focus is conveyed via border colour + shadow only.
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: shadow,
      ),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: child,
    );
  }
}
