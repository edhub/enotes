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
  late final Set<String> _seenNoteIds;

  @override
  void initState() {
    super.initState();
    final allNotes = ref.read(notesProvider).notes;
    _seenNoteIds = allNotes.map((n) => n.id).toSet();
  }

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
      child: Column(
        children: [
          ColumnHeader(
            label: widget.data.label,
            noteCount: widget.data.totalCount,
          ),
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // ── New-note composer (Today column only) ───────────────────
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

                // ── Note cards ──────────────────────────────────────────────
                SliverPadding(
                  padding: EdgeInsets.only(
                    top: isToday ? 0 : LayoutConstants.pageVPad,
                    bottom: LayoutConstants.pageVPad * 4,
                  ),
                  sliver: _buildNoteList(context),
                ),
              ],
            ),
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
          final isNew = !_seenNoteIds.contains(note.id);
          if (isNew) {
            _seenNoteIds.add(note.id);
          }

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
                columnWidth: LayoutConstants.timeColumnWidth,
              ),
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

// ── Slide-in Animation ────────────────────────────────────────────────────────

class _SlideInNewItem extends StatefulWidget {
  const _SlideInNewItem({
    super.key,
    required this.child,
    required this.isNew,
  });

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
      axisAlignment: -1.0, // Aligns to top, pushing content downwards
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _controller,
          curve: Curves.easeIn,
        ),
        child: widget.child,
      ),
    );
  }
}

