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
    return SizedBox(
      width: LayoutConstants.trashColumnWidth,
      height: widget.availableHeight,
      child: Column(
        children: [
          _TrashHeader(
            count: notes.length,
            onEmptyTrash: notes.isEmpty
                ? null
                : ref.read(notesProvider.notifier).emptyTrash,
          ),
          Expanded(
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
        ],
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
            CountBadge(count: count),
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
