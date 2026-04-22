import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../editor/controllers/markdown_controller.dart';
import '../../editor/services/markdown_shortcuts.dart';
import '../../editor/widgets/markdown_editor.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/search_provider.dart';
import 'note_card_container.dart';
import 'note_info_menu.dart';

/// A note card with fully inline editing via [MarkdownEditor].
///
/// - ESC unfocuses the editor.
/// - On hover/focus a ⋯ button appears; tapping it opens a popover with
///   timestamps and (for non-draft cards) a "Move to Trash" action.
class NoteCard extends ConsumerStatefulWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.isDraftView,
    required this.columnWidth,
    this.focusRequestToken,
    this.minHeight,
    this.minLines,
  });

  final Note note;
  final bool isDraftView;
  final double columnWidth;
  final int? focusRequestToken;
  final double? minHeight;
  final int? minLines;

  @override
  ConsumerState<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends ConsumerState<NoteCard> {
  late final MarkdownController _controller;
  late final FocusNode _focusNode;
  Timer? _saveTimer;
  bool _focused = false;
  bool _hovered = false;
  bool _updatingController = false;

  @override
  void initState() {
    super.initState();
    _controller = MarkdownController(text: widget.note.content);
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent)
      ..addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);

    // Initialise highlight tokens from the current search query, then keep
    // them in sync via a listener (event-driven, not in build()).
    _controller.searchTokens = _tokenize(ref.read(searchQueryProvider).query);
    ref.listenManual<String>(
      searchQueryProvider.select((s) => s.query),
      (_, query) => _controller.searchTokens = _tokenize(query),
    );

    if (widget.focusRequestToken != null && widget.focusRequestToken! > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(NoteCard old) {
    super.didUpdateWidget(old);
    if (widget.note.content != old.note.content &&
        widget.note.content != _controller.text) {
      _updatingController = true;
      _controller.text = widget.note.content;
      _updatingController = false;
    }
    if (widget.focusRequestToken != null &&
        widget.focusRequestToken != old.focusRequestToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _flushSave();
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  // ── Key / focus / text listeners ───────────────────────────────────────────

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    return MarkdownShortcuts.handleKeyEvent(
      event: event,
      node: node,
      controller: _controller,
      onApply: _flushSave,
    );
  }

  void _onFocusChanged() {
    setState(() => _focused = _focusNode.hasFocus);
    if (!_focusNode.hasFocus) _flushSave();
  }

  void _onTextChanged() {
    if (_updatingController) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _flushSave);
  }

  void _flushSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final content = _controller.text;
    if (content != widget.note.content) {
      ref.read(notesProvider.notifier).updateNote(widget.note.id, content);
    }
  }

  static List<String> _tokenize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    return trimmed
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  static const _minLineHeight = 14.0 * 1.64;
  static const _defaultMinLines = 1;

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();
    final bgColor = widget.isDraftView
        ? (nc?.draftCardBackground ?? Theme.of(context).cardTheme.color)
        : null;
    final minLines = widget.minLines ?? _defaultMinLines;
    final minContentHeight = minLines * _minLineHeight;
    final minCardHeight =
        widget.minHeight ??
        (minContentHeight + LayoutConstants.cardPadding * 2);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: NoteCardContainer(
        focused: _focused,
        hovered: _hovered,
        backgroundColor: bgColor,
        minHeight: minCardHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            MarkdownEditor(
              controller: _controller,
              focusNode: _focusNode,
              hint: widget.isDraftView ? 'Capture an idea…' : 'Start writing…',
              minLines: minLines,
              style: TextStyle(
                fontSize: widget.isDraftView ? 14.2 : 14,
                height: widget.isDraftView ? 1.66 : 1.64,
                fontWeight: FontWeight.w400,
              ),
            ),
            Positioned(
              top: -7,
              right: -7,
              child: NoteInfoButton(
                note: widget.note,
                isDraftView: widget.isDraftView,
                hovered: _hovered,
                focused: _focused,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
