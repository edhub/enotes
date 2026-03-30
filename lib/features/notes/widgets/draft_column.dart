import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/notes_provider.dart';
import 'note_card.dart';

/// The left-most column. Five permanent draft tabs at the top, Chrome-style:
/// the active tab has no bottom border and merges visually with the content
/// area below it. Tab labels are fixed numbers 1–5.
class DraftColumn extends StatelessWidget {
  const DraftColumn({super.key, required this.availableHeight});

  final double availableHeight;

  static const _tabBarHeight = 44.0;

  double get _cardHeight =>
      availableHeight - _tabBarHeight - LayoutConstants.pageVPad * 2;

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();
    // Active tab background = content area background → seamless merge.
    final draftBg =
        nc?.draftCardBackground ?? Theme.of(context).cardTheme.color!;
    final borderColor = nc?.cardBorder ?? const Color(0xFFE2E8F0);

    return SizedBox(
      width: LayoutConstants.draftColumnWidth,
      height: availableHeight,
      child: Consumer<NotesProvider>(
        builder: (context, provider, _) {
          final drafts = provider.draftNotes;
          final safeIndex =
              provider.activeDraftIndex.clamp(0, drafts.length - 1);

          return Column(
            children: [
              _ChromeTabBar(
                count: drafts.length,
                activeIndex: safeIndex,
                activeBg: draftBg,
                borderColor: borderColor,
              ),
              // Same background as active tab — no visible seam.
              Expanded(
                child: ColoredBox(
                  color: draftBg,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: LayoutConstants.pageVPad,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: NoteCard(
                        key: ValueKey(drafts[safeIndex].id),
                        note: drafts[safeIndex],
                        isDraftView: true,
                        columnWidth: LayoutConstants.draftColumnWidth,
                        minHeight: _cardHeight,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Chrome-style tab bar ──────────────────────────────────────────────────────

class _ChromeTabBar extends StatelessWidget {
  const _ChromeTabBar({
    required this.count,
    required this.activeIndex,
    required this.activeBg,
    required this.borderColor,
  });

  final int count;
  final int activeIndex;
  final Color activeBg;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Inactive tabs sit slightly above the scaffold colour.
    final inactiveBg = isDark
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.05), scaffoldBg)
        : Color.alphaBlend(Colors.black.withValues(alpha: 0.04), scaffoldBg);

    return Container(
      height: DraftColumn._tabBarHeight,
      // Tab bar is the same colour as the outer scaffold — tabs appear to
      // "float" on top of it.
      color: scaffoldBg,
      padding: const EdgeInsets.only(
        left: LayoutConstants.pageHPad,
        right: LayoutConstants.pageHPad,
        top: 8,
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
                    context.read<NotesProvider>().setActiveDraftIndex(i),
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isActive) {
      return Container(
        decoration: BoxDecoration(
          color: widget.activeBg,
          // Rounded top corners only — bottom is open, merging with content.
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
          border: Border(
            top: BorderSide(color: widget.borderColor),
            left: BorderSide(color: widget.borderColor),
            right: BorderSide(color: widget.borderColor),
            // No bottom border → seamless join with content area.
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.primary,
          ),
        ),
      );
    }

    // ── Inactive tab ────────────────────────────────────────────────────────
    final hoverBg = isDark
        ? Color.alphaBlend(
            Colors.white.withValues(alpha: 0.07), widget.inactiveBg)
        : Color.alphaBlend(
            Colors.black.withValues(alpha: 0.05), widget.inactiveBg);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          // Slight top + bottom margin makes inactive tabs visually shorter
          // than the active tab, reinforcing the Chrome affordance.
          margin: const EdgeInsets.only(top: 3, bottom: 2),
          decoration: BoxDecoration(
            color: _hovered ? hoverBg : widget.inactiveBg,
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.labelSmall?.color,
            ),
          ),
        ),
      ),
    );
  }
}
