import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import 'column_header.dart';
import 'note_card.dart';

/// The left-most column. Displays up to [LayoutConstants.maxDraftNotes] draft
/// notes as full-height cards, with dot indicators and arrows to switch.
class DraftColumn extends StatelessWidget {
  const DraftColumn({super.key, required this.availableHeight});

  final double availableHeight;

  double get _bodyHeight =>
      availableHeight -
      LayoutConstants.columnHeaderHeight -
      LayoutConstants.pageVPad * 2;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: LayoutConstants.draftColumnWidth,
      height: availableHeight,
      child: Column(
        children: [
          const ColumnHeader(label: 'Drafts', isDraft: true),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: LayoutConstants.pageVPad,
              ),
              child: Consumer<NotesProvider>(
                builder: (context, provider, _) {
                  final drafts = provider.draftNotes;
                  if (drafts.isEmpty) return _EmptyDraftState();
                  return _DraftSwitcher(
                    drafts: drafts,
                    activeIndex: provider.activeDraftIndex,
                    bodyHeight: _bodyHeight,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the active draft card with prev/next arrows and dot indicators.
class _DraftSwitcher extends StatelessWidget {
  const _DraftSwitcher({
    required this.drafts,
    required this.activeIndex,
    required this.bodyHeight,
  });

  final List<Note> drafts;
  final int activeIndex;
  final double bodyHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: NoteCard(
              key: ValueKey(drafts[activeIndex].id),
              note: drafts[activeIndex],
              isDraftView: true,
              columnWidth: LayoutConstants.draftColumnWidth,
              minHeight: bodyHeight - 56,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _DraftNavBar(
          count: drafts.length,
          activeIndex: activeIndex,
        ),
      ],
    );
  }
}

/// Arrow buttons + dot indicators for switching between draft cards.
class _DraftNavBar extends StatelessWidget {
  const _DraftNavBar({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();
    final provider = context.read<NotesProvider>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ArrowButton(
          icon: Icons.chevron_left_rounded,
          enabled: activeIndex > 0,
          onTap: () => provider.setActiveDraftIndex(activeIndex - 1),
        ),
        const SizedBox(width: 8),
        ...List.generate(
          count,
          (i) => _Dot(
            active: i == activeIndex,
            activeColor: nc?.dotActive ?? Colors.indigo,
            inactiveColor: nc?.dotInactive ?? Colors.grey,
            onTap: () => provider.setActiveDraftIndex(i),
          ),
        ),
        const SizedBox(width: 8),
        _ArrowButton(
          icon: Icons.chevron_right_rounded,
          enabled: activeIndex < count - 1,
          onTap: () => provider.setActiveDraftIndex(activeIndex + 1),
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      onPressed: enabled ? onTap : null,
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: active ? 20 : 8,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: active ? activeColor : inactiveColor,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _EmptyDraftState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).textTheme.labelSmall?.color;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note_rounded, size: 40, color: secondary),
          const SizedBox(height: 12),
          Text(
            'No drafts yet.\nTap + to capture a thought.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
