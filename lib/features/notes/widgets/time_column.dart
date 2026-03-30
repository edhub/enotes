import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/layout_constants.dart';
import '../models/time_group.dart';
import '../providers/notes_provider.dart';
import 'column_header.dart';
import 'note_card.dart';

/// A single time-group column (Today, Yesterday, This Week, etc.).
///
/// Uses a [CustomScrollView] so the header sticks to the top while
/// note cards scroll independently from all other columns.
class TimeColumn extends StatefulWidget {
  const TimeColumn({
    super.key,
    required this.data,
    required this.availableHeight,
  });

  final TimeColumnData data;
  final double availableHeight;

  @override
  State<TimeColumn> createState() => _TimeColumnState();
}

class _TimeColumnState extends State<TimeColumn> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: LayoutConstants.timeColumnWidth,
      height: widget.availableHeight,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _ColumnHeaderDelegate(
              label: widget.data.label,
              count: widget.data.totalCount,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(
              top: LayoutConstants.pageVPad,
              bottom: LayoutConstants.pageVPad * 4,
            ),
            sliver: _buildNoteList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteList(BuildContext context) {
    final provider = context.watch<NotesProvider>();
    // Re-derive from provider so cards reflect live state
    final col = provider.timeColumns.firstWhere(
      (c) => c.bucketKey == widget.data.bucketKey,
      orElse: () => widget.data,
    );

    final allNotes = [
      ...col.pinnedNotes,
      if (col.pinnedNotes.isNotEmpty && col.regularNotes.isNotEmpty)
        null, // sentinel for divider
      ...col.regularNotes,
    ];

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final item = allNotes[i];
          if (item == null) return _PinnedDivider();
          return Padding(
            padding: const EdgeInsets.only(
              left: LayoutConstants.pageHPad,
              right: LayoutConstants.pageHPad,
              bottom: LayoutConstants.cardMarginBottom,
            ),
            child: NoteCard(
              note: item,
              isDraftView: false,
              columnWidth: LayoutConstants.timeColumnWidth,
            ),
          );
        },
        childCount: allNotes.length,
      ),
    );
  }
}

class _ColumnHeaderDelegate extends SliverPersistentHeaderDelegate {
  _ColumnHeaderDelegate({required this.label, required this.count});

  final String label;
  final int count;

  @override
  double get minExtent => LayoutConstants.columnHeaderHeight;

  @override
  double get maxExtent => LayoutConstants.columnHeaderHeight;

  @override
  bool shouldRebuild(_ColumnHeaderDelegate old) =>
      old.label != label || old.count != count;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      ColumnHeader(label: label, noteCount: count, isDraft: false);
}

class _PinnedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LayoutConstants.pageHPad,
        vertical: 8,
      ),
      child: Row(
        children: [
          const Icon(Icons.push_pin_rounded, size: 12),
          const SizedBox(width: 4),
          Expanded(
            child: Divider(
              height: 1,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
