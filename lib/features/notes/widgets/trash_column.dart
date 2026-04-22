import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/notes_provider.dart';
import 'column_header.dart';
import 'trash_note_card.dart';

/// The right-most column. Shows recently soft-deleted notes.
///
/// Mirrors [TimeColumn]: a fixed header plus per-column independent scrolling
/// body. Note cards are read-only and offer "Restore" and "Delete Forever"
/// actions.
class TrashColumn extends ConsumerStatefulWidget {
  const TrashColumn({super.key, required this.availableHeight});

  final double availableHeight;

  @override
  ConsumerState<TrashColumn> createState() => _TrashColumnState();
}

class _TrashColumnState extends ConsumerState<TrashColumn> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider.select((s) => s.trashedNotes));
    final nc = Theme.of(context).extension<NoteColors>();
    final borderColor = nc?.columnBorder ?? Theme.of(context).dividerColor;
    final columnSurface =
        nc?.columnSurface ?? Theme.of(context).colorScheme.surface;

    return SizedBox(
      width: LayoutConstants.trashColumnWidth,
      height: widget.availableHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: columnSurface,
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
              _TrashHeader(
                count: notes.length,
                onEmptyTrash: notes.isEmpty
                    ? null
                    : ref.read(notesProvider.notifier).emptyTrash,
              ),
              Expanded(
                child: ColoredBox(
                  color: columnSurface,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      if (notes.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyTrashState(),
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

// ── Header ────────────────────────────────────────────────────────────────────

class _TrashHeader extends StatelessWidget {
  const _TrashHeader({required this.count, required this.onEmptyTrash});

  final int count;
  final VoidCallback? onEmptyTrash;

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();
    final tt = Theme.of(context).textTheme;
    final destructive = nc?.destructive ?? Colors.red.shade400;

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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: destructive,
            ),
          ),
          Text('Recently Deleted', style: tt.titleMedium),
          if (count > 0) ...[
            const SizedBox(width: 8),
            CountBadge(count: count),
          ],
          const Spacer(),
          if (onEmptyTrash != null)
            TextButton(
              onPressed: onEmptyTrash,
              style: TextButton.styleFrom(
                foregroundColor: destructive,
                backgroundColor: nc?.destructiveSoft,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(color: destructive.withValues(alpha: 0.24)),
                ),
              ),
              child: const Text(
                'Empty',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyTrashState extends StatelessWidget {
  const _EmptyTrashState();

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();
    final secondary = Theme.of(context).textTheme.labelSmall?.color;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: nc?.destructiveSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.delete_outline_rounded, size: 28, color: nc?.destructive ?? secondary),
          ),
          const SizedBox(height: 12),
          Text(
            'No deleted notes.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
