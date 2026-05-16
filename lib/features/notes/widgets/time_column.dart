import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../models/time_group.dart';
import '../providers/notes_provider.dart';
import '../providers/search_provider.dart';
import 'column_header.dart';
import 'column_panel.dart';
import 'note_card.dart';

/// A single time-group column (Today, Yesterday, This Week, etc.).
///
/// The Today column shows a "new note" control at the bottom of the scroll
/// area (same action as Cmd+K: add a note, scroll down, focus the editor).
///
/// Uses a fixed header + independent [CustomScrollView] body per column.
class TimeColumn extends ConsumerStatefulWidget {
  const TimeColumn({
    super.key,
    required this.data,
    required this.availableHeight,
  });

  final TimeColumnData data;
  final double availableHeight;

  @override
  ConsumerState<TimeColumn> createState() => _TimeColumnState();
}

class _TimeColumnState extends ConsumerState<TimeColumn> {
  final _scrollController = ScrollController();

  /// Wall-clock instant captured when this column entered the tree.
  /// Notes whose [Note.createdAt] is strictly after this point are
  /// considered "freshly added" and play the slide-in animation.
  ///
  /// This avoids the cross-column tracking the previous Set-based
  /// implementation needed: each column only cares about "did this note
  /// appear after I was built?", a purely local question.
  late final DateTime _mountedAt;

  @override
  void initState() {
    super.initState();
    _mountedAt = DateTime.now().toUtc();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isToday = widget.data.bucketKey == 'today';
    final nc = Theme.of(context).extension<NoteColors>();
    final columnSurface =
        nc?.columnSurface ?? Theme.of(context).colorScheme.surface;

    if (isToday) {
      ref.listen<int>(notesProvider.select((s) => s.todayNoteFocusToken), (
        prev,
        next,
      ) {
        if (prev != next && next > 0) {
          void scrollToEnd() {
            if (!mounted) return;
            if (!_scrollController.hasClients) return;
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
            );
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            scrollToEnd();
            WidgetsBinding.instance.addPostFrameCallback((_) => scrollToEnd());
          });
        }
      });
    }

    final todayFocus = isToday
        ? ref.watch(
            notesProvider.select(
              (s) => (s.todayNoteFocusId, s.todayNoteFocusToken),
            ),
          )
        : (null, 0) as (String?, int);

    final bodyHeight =
        widget.availableHeight - LayoutConstants.columnHeaderHeight;
    final readingGap = LayoutConstants.columnBottomReadingGap(bodyHeight);

    return ColumnPanel(
      surfaceColor: columnSurface,
      width: LayoutConstants.timeColumnWidth,
      height: widget.availableHeight,
      child: Column(
        children: [
          ColumnHeader(
            label: widget.data.label,
            noteCount: widget.data.totalCount,
            emphasized: isToday,
          ),
          Expanded(
            child: ColoredBox(
              color: columnSurface,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.only(
                        top: LayoutConstants.pageVPad,
                      ),
                      sliver: _buildNoteList(context, todayFocus),
                    ),
                    if (isToday)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          LayoutConstants.pageHPad,
                          2,
                          LayoutConstants.pageHPad,
                          LayoutConstants.cardMarginBottom,
                        ),
                        sliver: const SliverToBoxAdapter(
                          child: _AddTodayNoteButton(),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: readingGap + LayoutConstants.pageVPad,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteList(BuildContext context, (String?, int) todayFocus) {
    final col = ref.watch(
      filteredTimeColumnsProvider.select(
        (cols) => cols.firstWhere(
          (c) => c.bucketKey == widget.data.bucketKey,
          orElse: () => TimeColumnData(
            bucketKey: widget.data.bucketKey,
            label: widget.data.label,
            notes: [],
            sortOrder: widget.data.sortOrder,
          ),
        ),
      ),
    );

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, i) {
        final note = col.notes[i];
        final age = DateTime.now().toUtc().difference(note.createdAt);
        final isNew = note.createdAt.isAfter(_mountedAt) && age.inSeconds < 2;

        final focusToken = note.id == todayFocus.$1 ? todayFocus.$2 : null;

        return _SlideInNewItem(
          key: ValueKey('slide-${note.id}'),
          isNew: isNew,
          child: Padding(
            padding: const EdgeInsets.only(
              left: LayoutConstants.pageHPad,
              right: LayoutConstants.pageHPad,
              bottom: LayoutConstants.cardMarginBottom,
            ),
            child: NoteCard(
              key: ValueKey(note.id),
              note: note,
              isDraftView: false,
              focusRequestToken: focusToken,
            ),
          ),
        );
      }, childCount: col.notes.length),
    );
  }
}

class _AddTodayNoteButton extends ConsumerWidget {
  const _AddTodayNoteButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nc = Theme.of(context).extension<NoteColors>();
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: '新建笔记（⌘K）',
      child: OutlinedButton.icon(
        onPressed: () {
          ref.read(notesProvider.notifier).focusOrAddTodayNote();
        },
        icon: Icon(Icons.add_rounded, size: 20, color: scheme.primary),
        label: const Text('添加笔记'),
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          backgroundColor: nc?.columnSurface,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          minimumSize: const Size.fromHeight(44),
        ),
      ),
    );
  }
}

// ── Slide-in Animation ────────────────────────────────────────────────────────

class _SlideInNewItem extends StatefulWidget {
  const _SlideInNewItem({super.key, required this.child, required this.isNew});

  final Widget child;
  final bool isNew;

  @override
  State<_SlideInNewItem> createState() => _SlideInNewItemState();
}

class _SlideInNewItemState extends State<_SlideInNewItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    if (widget.isNew) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isNew && _controller.value == 1.0) {
      return widget.child;
    }

    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _controller, curve: Curves.easeIn),
        child: widget.child,
      ),
    );
  }
}
