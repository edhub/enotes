import 'package:flutter/material.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_theme.dart';

class JumpToTodayButton extends StatelessWidget {
  const JumpToTodayButton({
    super.key,
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();

    return Positioned(
      left: LayoutConstants.pageHPad + 8,
      bottom: LayoutConstants.pageHPad + 8,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.08),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !visible,
            child: FloatingActionButton.small(
              heroTag: 'jumpToToday',
              tooltip: 'Back to Today',
              backgroundColor:
                  nc?.controlSurface ??
                  Theme.of(context).floatingActionButtonTheme.backgroundColor,
              foregroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: nc?.searchBarBorder ?? Theme.of(context).dividerColor,
                ),
              ),
              onPressed: onPressed,
              child: const Icon(Icons.first_page_rounded),
            ),
          ),
        ),
      ),
    );
  }
}
