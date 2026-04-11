import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_constants.dart';
import '../../editor/controllers/markdown_controller.dart';
import '../../editor/services/markdown_shortcuts.dart';
import '../../editor/widgets/markdown_editor.dart';
import '../models/time_group.dart';
import '../providers/notes_provider.dart';
import '../providers/search_provider.dart';
import 'column_header.dart';
import 'note_card.dart';
import 'note_card_container.dart';

/// A single time-group column (Today, Yesterday, This Week, etc.).
///
/// For the Today column an always-visible [_NewNoteComposer] is pinned
/// directly below the sticky header. Typing there and then unfocusing
/// (or pressing ESC / Tab) saves the text as a brand-new note.
///
/// Uses a [CustomScrollView] so the header sticks to the top while note cards
/// scroll independently from all other columns.
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isToday = widget.data.bucketKey == 'today';

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

          // ── New-note composer (Today column only) ─────────────────────────
          if (isToday)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                LayoutConstants.pageHPad,
                LayoutConstants.pageVPad,
                LayoutConstants.pageHPad,
                LayoutConstants.cardMarginBottom,
              ),
              sliver: SliverToBoxAdapter(
                child: _NewNoteComposer(
                  scrollController: _scrollController,
                ),
              ),
            ),

          // ── Note cards ────────────────────────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.only(
              top: isToday ? 0 : LayoutConstants.pageVPad,
              bottom: LayoutConstants.pageVPad * 4,
            ),
            sliver: _buildNoteList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteList(BuildContext context) {
    final col = ref.watch(
      filteredTimeColumnsProvider.select(
        (cols) => cols.firstWhere(
          (c) => c.bucketKey == widget.data.bucketKey,
          orElse: () => widget.data,
        ),
      ),
    );

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final note = col.notes[i];
          return Padding(
            padding: const EdgeInsets.only(
              left: LayoutConstants.pageHPad,
              right: LayoutConstants.pageHPad,
              bottom: LayoutConstants.cardMarginBottom,
            ),
            child: NoteCard(
              key: ValueKey(note.id),
              note: note,
              isDraftView: false,
              columnWidth: LayoutConstants.timeColumnWidth,
            ),
          );
        },
        childCount: col.notes.length,
      ),
    );
  }
}

// ── New-note composer ─────────────────────────────────────────────────────────

/// Always-visible input card at the top of the Today column.
///
/// - Typing and then unfocusing (or pressing ESC) saves the content as a new
///   note and resets the composer to empty.
/// - Responds to [NotesProvider.newNoteFocusRequest] changes (triggered by
///   Cmd+K) to grab keyboard focus and scroll the column back to the top.
/// - Supports the same Markdown shortcuts as [NoteCard] via shared handler.
class _NewNoteComposer extends ConsumerStatefulWidget {
  const _NewNoteComposer({required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<_NewNoteComposer> createState() => _NewNoteComposerState();
}

class _NewNoteComposerState extends ConsumerState<_NewNoteComposer> {
  late final MarkdownController _controller;
  late final FocusNode _focusNode;
  bool _focused = false;

  /// Shadow of the last seen [NotesProvider.newNoteFocusRequest] value so we
  /// can detect when it increments and trigger focus.
  int _lastFocusRequest = 0;

  @override
  void initState() {
    super.initState();
    _controller = MarkdownController();
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent)
      ..addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  // ── Key / focus listeners ─────────────────────────────────────────────────

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    return MarkdownShortcuts.handleKeyEvent(
      event: event,
      node: node,
      controller: _controller,
    );
  }

  void _onFocusChanged() {
    setState(() => _focused = _focusNode.hasFocus);
    if (!_focusNode.hasFocus) _saveIfNeeded();
  }

  void _saveIfNeeded() {
    final content = _controller.text;
    if (content.trim().isEmpty) return;
    ref.read(notesProvider.notifier).addNote(content);
    _controller.value = TextEditingValue.empty;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Detect when Cmd+K increments the focus counter and grab focus.
    final req = ref.watch(notesProvider.select((s) => s.newNoteFocusRequest));
    if (req > 0 && req != _lastFocusRequest) {
      _lastFocusRequest = req;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.scrollController.hasClients) {
          widget.scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
        _focusNode.requestFocus();
      });
    }

    return NoteCardContainer(
      focused: _focused,
      minHeight: 52,
      child: MarkdownEditor(
        controller: _controller,
        focusNode: _focusNode,
        hint: 'New note…',
      ),
    );
  }
}

// ── Column header sliver delegate ─────────────────────────────────────────────

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
      ColumnHeader(label: label, noteCount: count);
}
