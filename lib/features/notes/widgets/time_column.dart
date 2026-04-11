import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../editor/controllers/markdown_controller.dart';
import '../../editor/services/markdown_shortcuts.dart';
import '../../editor/widgets/markdown_editor.dart';
import '../models/time_group.dart';
import '../providers/notes_provider.dart';
import '../providers/search_provider.dart';
import 'column_header.dart';
import 'note_card.dart';

/// A single time-group column (Today, Yesterday, This Week, etc.).
///
/// For the Today column an always-visible [_NewNoteComposer] is pinned
/// directly below the sticky header. Typing there and then unfocusing
/// (or pressing ESC / Tab) saves the text as a brand-new note.
///
/// Uses a [CustomScrollView] so the header sticks to the top while note cards
/// scroll independently from all other columns. Note cards themselves have no
/// internal scroll — they are always fully expanded to fit their content.
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
              // No extra top gap below the composer; keep it for non-today cols.
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
/// - If unfocused while empty, nothing is saved.
/// - Responds to [NotesProvider.newNoteFocusRequest] changes (triggered by
///   Cmd+K) to grab keyboard focus and scroll the column back to the top.
/// - Supports the same Markdown shortcuts as [NoteCard] (Cmd+B, Cmd+L, …).
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
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // ESC → unfocus (triggers save if non-empty)
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      node.unfocus();
      return KeyEventResult.handled;
    }

    final isCmd =
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.metaLeft,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.metaRight,
        );
    final isShift =
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.shiftLeft,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.shiftRight,
        );

    if (!isCmd) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.keyB) {
      _applyShortcut(MarkdownShortcuts.toggleBold);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyL && !isShift) {
      _applyShortcut(MarkdownShortcuts.toggleUnorderedList);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyL && isShift) {
      _applyShortcut(MarkdownShortcuts.toggleOrderedList);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _applyShortcut(
    (String, TextSelection) Function(String, TextSelection) fn,
  ) {
    final (newText, newSel) = fn(_controller.text, _controller.selection);
    _controller.value = _controller.value.copyWith(
      text: newText,
      selection: newSel,
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
    // Reset composer so it is ready for the next note.
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
        // Scroll Today column back to top so the composer is visible.
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nc = Theme.of(context).extension<NoteColors>();

    final borderColor = _focused
        ? Theme.of(context).colorScheme.primary
        : (nc?.cardBorder ?? Colors.grey.shade200);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(LayoutConstants.cardBorderRadius),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: _focused
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
