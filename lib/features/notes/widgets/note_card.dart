import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../editor/controllers/markdown_controller.dart';
import '../../editor/services/ime_composing.dart';
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
    this.focusRequestToken,
    this.minHeight,
    this.minLines,
  });

  final Note note;
  final bool isDraftView;
  final int? focusRequestToken;
  final double? minHeight;
  final int? minLines;

  @override
  ConsumerState<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends ConsumerState<NoteCard> {
  static const _saveDebounce = Duration(milliseconds: 600);
  static const _imeRetryDelay = Duration(milliseconds: 160);

  late final MarkdownController _controller;
  late final FocusNode _focusNode;
  Timer? _saveTimer;
  bool _focused = false;
  bool _hovered = false;
  bool _updatingController = false;
  bool _disposing = false;

  @override
  void initState() {
    super.initState();
    _controller = MarkdownController(text: widget.note.content);
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent)
      ..addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);

    // Initialise highlight tokens from the current search query, then keep
    // them in sync via a listener (event-driven, not in build()).
    _controller.searchTokens = searchTokens(ref.read(searchQueryProvider).query);
    ref.listenManual<String>(
      searchQueryProvider.select((s) => s.query),
      (_, query) => _controller.searchTokens = searchTokens(query),
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

    if (widget.note.content != old.note.content) {
      final hasLocalPendingEdits = _controller.text != old.note.content;
      final shouldAcceptExternalSync = !_controller.hasActiveComposing &&
          !(_focusNode.hasFocus && hasLocalPendingEdits);

      if (widget.note.content != _controller.text && shouldAcceptExternalSync) {
        _replaceControllerText(widget.note.content);
      }
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
    _disposing = true;
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
    _scheduleSave();
  }

  void _scheduleSave([Duration delay = _saveDebounce]) {
    if (_disposing) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(delay, _flushSave);
  }

  void _flushSave() {
    if (_controller.hasActiveComposing) {
      if (!_disposing) _scheduleSave(_imeRetryDelay);
      return;
    }

    _saveTimer?.cancel();
    _saveTimer = null;

    final content = _controller.text;
    if (content != widget.note.content) {
      ref.read(notesProvider.notifier).updateNote(widget.note.id, content);
    }
  }

  void _replaceControllerText(String text) {
    // Preserve the current cursor position; clamp if the new text is shorter.
    final oldSelection = _controller.selection;
    final newLength = text.length;
    final selection = oldSelection.isValid
        ? TextSelection(
            baseOffset: oldSelection.baseOffset.clamp(0, newLength),
            extentOffset: oldSelection.extentOffset.clamp(0, newLength),
          )
        : TextSelection.collapsed(offset: newLength);

    _updatingController = true;
    _controller.value = TextEditingValue(text: text, selection: selection);
    _updatingController = false;
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
