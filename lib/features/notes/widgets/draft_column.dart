import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/notes_provider.dart';
import '../providers/search_provider.dart';
import 'note_card.dart';
import 'note_search_bar.dart';

/// The left-most column. Five permanent draft tabs at the top, Chrome-style:
/// the active tab has no bottom border and merges visually with the content
/// area below it. Tab labels are fixed numbers 1–5.
class DraftColumn extends ConsumerWidget {
  const DraftColumn({super.key, required this.availableHeight});

  final double availableHeight;

  static const _tabBarHeight = 42.0;

  double get _cardHeight =>
      availableHeight -
      _tabBarHeight -
      NoteSearchBar.totalHeight -
      LayoutConstants.pageVPad * 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nc = Theme.of(context).extension<NoteColors>();
    final draftBg =
        nc?.draftCardBackground ?? Theme.of(context).cardTheme.color!;
    final borderColor = nc?.columnBorder ?? const Color(0xFFE2E8F0);

    final drafts = ref.watch(notesProvider.select((s) => s.draftNotes));
    final safeIndex = ref
        .watch(notesProvider.select((s) => s.activeDraftIndex))
        .clamp(0, drafts.length - 1);
    final focusReq = ref.watch(
      notesProvider.select((s) => s.draftFocusRequest),
    );
    final searchFocusReq = ref.watch(
      searchQueryProvider.select((s) => s.focusRequest),
    );

    final headerBg = nc?.columnHeader ?? Theme.of(context).colorScheme.surface;

    return SizedBox(
      width: LayoutConstants.draftColumnWidth,
      height: availableHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: draftBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.16)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              ColoredBox(
                color: headerBg,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LayoutConstants.pageHPad,
                  ),
                  child: NoteSearchBar(focusRequestToken: searchFocusReq),
                ),
              ),
              Container(
                height: 1,
                color: borderColor.withValues(alpha: 0.7),
              ),
              Container(
                color: headerBg,
                child: _ChromeTabBar(
                  count: drafts.length,
                  activeIndex: safeIndex,
                  activeBg: draftBg,
                  borderColor: borderColor,
                  backgroundColor: headerBg,
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: draftBg,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: LayoutConstants.pageHPad,
                      vertical: LayoutConstants.pageVPad,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: child,
                      ),
                      child: NoteCard(
                        key: ValueKey(drafts[safeIndex].id),
                        note: drafts[safeIndex],
                        isDraftView: true,
                        columnWidth: LayoutConstants.draftColumnWidth,
                        focusRequestToken: focusReq,
                        minHeight: _cardHeight,
                        minLines: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chrome-style tab bar ──────────────────────────────────────────────────────

class _ChromeTabBar extends ConsumerWidget {
  const _ChromeTabBar({
    required this.count,
    required this.activeIndex,
    required this.activeBg,
    required this.borderColor,
    required this.backgroundColor,
  });

  final int count;
  final int activeIndex;
  final Color activeBg;
  final Color borderColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nc = Theme.of(context).extension<NoteColors>();

    final inactiveBg =
        nc?.controlSurface ?? Theme.of(context).colorScheme.surface;

    return Container(
      height: DraftColumn._tabBarHeight,
      color: backgroundColor,
      padding: const EdgeInsets.only(
        left: LayoutConstants.pageHPad,
        right: LayoutConstants.pageHPad,
        top: 6,
        // No bottom padding: active tab's bottom edge touches content area.
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(count, (i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
              child: _ChromeTab(
                label: '${i + 1}',
                isActive: i == activeIndex,
                activeBg: activeBg,
                borderColor: borderColor,
                inactiveBg: inactiveBg,
                onTap: () =>
                    ref.read(notesProvider.notifier).setActiveDraftIndex(i),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Single Chrome tab ─────────────────────────────────────────────────────────

class _ChromeTab extends StatefulWidget {
  const _ChromeTab({
    required this.label,
    required this.isActive,
    required this.activeBg,
    required this.borderColor,
    required this.inactiveBg,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final Color activeBg;
  final Color borderColor;
  final Color inactiveBg;
  final VoidCallback onTap;

  @override
  State<_ChromeTab> createState() => _ChromeTabState();
}

class _ChromeTabState extends State<_ChromeTab> {
  bool _hovered = false;

  @override
  void didUpdateWidget(covariant _ChromeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive && _hovered) {
      _hovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nc = Theme.of(context).extension<NoteColors>();

    if (widget.isActive) {
      return Container(
        decoration: BoxDecoration(
          color: widget.activeBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
          border: Border(
            top: BorderSide(color: widget.borderColor),
            left: BorderSide(color: widget.borderColor),
            right: BorderSide(color: widget.borderColor),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: scheme.primary,
          ),
        ),
      );
    }

    final hoverBg = _hovered
        ? (nc?.controlSurfaceHover ?? widget.inactiveBg)
        : widget.inactiveBg;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(top: 4, bottom: 3),
          decoration: BoxDecoration(
            color: hoverBg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: _hovered
                  ? (nc?.cardBorderHover ?? widget.borderColor)
                  : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.labelSmall?.color,
            ),
          ),
        ),
      ),
    );
  }
}
