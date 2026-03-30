import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';

/// The right-most column. Shows recently soft-deleted notes.
///
/// Mirrors the structure of [TimeColumn]: a [CustomScrollView] with a sticky
/// header and per-column independent scrolling. Note cards are read-only and
/// offer "Restore" and "Delete Forever" actions.
class TrashColumn extends StatefulWidget {
  const TrashColumn({super.key, required this.availableHeight});

  final double availableHeight;

  @override
  State<TrashColumn> createState() => _TrashColumnState();
}

class _TrashColumnState extends State<TrashColumn> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: LayoutConstants.trashColumnWidth,
      height: widget.availableHeight,
      child: Consumer<NotesProvider>(
        builder: (context, provider, _) {
          final notes = provider.trashedNotes;
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _TrashHeaderDelegate(
                  count: notes.length,
                  onEmptyTrash:
                      notes.isEmpty ? null : provider.emptyTrash,
                ),
              ),
              if (notes.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: const _EmptyTrashState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(
                    top: LayoutConstants.pageVPad,
                    bottom: LayoutConstants.pageVPad * 4,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: const EdgeInsets.only(
                          left: LayoutConstants.pageHPad,
                          right: LayoutConstants.pageHPad,
                          bottom: LayoutConstants.cardMarginBottom,
                        ),
                        child: TrashNoteCard(
                          key: ValueKey(notes[i].id),
                          note: notes[i],
                        ),
                      ),
                      childCount: notes.length,
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

// ── Sticky header delegate ────────────────────────────────────────────────────

class _TrashHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TrashHeaderDelegate({required this.count, required this.onEmptyTrash});

  final int count;
  final VoidCallback? onEmptyTrash;

  @override
  double get minExtent => LayoutConstants.columnHeaderHeight;

  @override
  double get maxExtent => LayoutConstants.columnHeaderHeight;

  @override
  bool shouldRebuild(_TrashHeaderDelegate old) =>
      old.count != count || old.onEmptyTrash != onEmptyTrash;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      _TrashHeader(count: count, onEmptyTrash: onEmptyTrash);
}

// ── Header ────────────────────────────────────────────────────────────────────

class _TrashHeader extends StatelessWidget {
  const _TrashHeader({required this.count, required this.onEmptyTrash});

  final int count;
  final VoidCallback? onEmptyTrash;

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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text('Recently Deleted', style: tt.titleMedium),
          if (count > 0) ...[
            const SizedBox(width: 8),
            _CountBadge(count: count),
          ],
          const Spacer(),
          if (onEmptyTrash != null)
            TextButton(
              onPressed: onEmptyTrash,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade400,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Empty', style: TextStyle(fontSize: 12)),
            ),
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
      child: Text('$count', style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyTrashState extends StatelessWidget {
  const _EmptyTrashState();

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).textTheme.labelSmall?.color;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline_rounded, size: 40, color: secondary),
          const SizedBox(height: 12),
          Text(
            'No deleted notes.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

// ── Trash note card ────────────────────────────────────────────────────────────

/// A read-only card shown in the trash column.
/// Provides "Restore" and "Delete Forever" actions, always visible.
class TrashNoteCard extends StatefulWidget {
  const TrashNoteCard({super.key, required this.note});

  final Note note;

  @override
  State<TrashNoteCard> createState() => _TrashNoteCardState();
}

class _TrashNoteCardState extends State<TrashNoteCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nc = Theme.of(context).extension<NoteColors>();
    final provider = context.read<NotesProvider>();

    final borderColor = nc?.cardBorder ?? Colors.grey.shade200;
    final bgColor = Theme.of(context).cardTheme.color;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius:
              BorderRadius.circular(LayoutConstants.cardBorderRadius),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: _hovered
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
        padding: const EdgeInsets.all(LayoutConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: Theme.of(context).textTheme.labelSmall?.color,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDeletedAt(widget.note.deletedAt!),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                _TrashAction(
                  icon: Icons.restore_rounded,
                  tooltip: 'Restore',
                  color: Theme.of(context).colorScheme.primary,
                  onTap: () => provider.restoreNote(widget.note.id),
                ),
                const SizedBox(width: 2),
                _TrashAction(
                  icon: Icons.delete_forever_rounded,
                  tooltip: 'Delete Forever',
                  color: Colors.red.shade400,
                  onTap: () =>
                      provider.permanentlyDeleteNote(widget.note.id),
                ),
              ],
            ),
            if (widget.note.content.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(
                widget.note.content,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.6),
                      height: 1.55,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDeletedAt(DateTime deletedAt) {
    final local = deletedAt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inSeconds < 60) return 'deleted just now';
    if (diff.inMinutes < 60) return 'deleted ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'deleted ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'deleted yesterday';
    if (diff.inDays < 30) return 'deleted ${diff.inDays}d ago';
    return 'deleted ${diff.inDays ~/ 30}mo ago';
  }
}

class _TrashAction extends StatelessWidget {
  const _TrashAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}
