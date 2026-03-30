import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';

/// A note card with fully inline editing via [CodeEditor].
///
/// Design principle: "展示即编辑" — clicking the content area starts typing
/// immediately. No modal dialog is ever opened for editing.
///
/// Auto-saves 600ms after the last keystroke, or immediately on focus loss
/// and Cmd+S.
class NoteCard extends StatefulWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.isDraftView,
    required this.columnWidth,
    this.minHeight,
  });

  final Note note;
  final bool isDraftView;
  final double columnWidth;

  /// Minimum card height (used for draft cards to fill the column).
  final double? minHeight;

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  late final CodeLineEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _saveTimer;
  bool _focused = false;
  bool _hovered = false;

  /// Guard against our own programmatic controller updates
  /// triggering the auto-save listener.
  bool _updatingController = false;

  /// Tracks current text for height calculation.
  /// Updated via setState in [_onTextChanged] so AnimatedContainer resizes
  /// as the user types — without a ValueListenableBuilder, which fires during
  /// CodeEditor.initState and causes a "setState during build" crash.
  late String _contentForHeight;

  @override
  void initState() {
    super.initState();
    _contentForHeight = widget.note.content;
    _controller = CodeLineEditingController.fromText(widget.note.content);
    _focusNode = FocusNode()..addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);

    // Auto-focus if this card was just created via addNote.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<NotesProvider>();
      if (provider.pendingFocusNoteId == widget.note.id) {
        provider.clearPendingFocus();
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(NoteCard old) {
    super.didUpdateWidget(old);
    // Sync only when content changed externally (not from our own save).
    if (widget.note.content != old.note.content &&
        widget.note.content != _controller.text) {
      _updatingController = true;
      _controller.text = widget.note.content;
      _updatingController = false;
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

  // ── Listeners ──────────────────────────────────────────────────────────────

  void _onFocusChanged() {
    setState(() => _focused = _focusNode.hasFocus);
    if (!_focusNode.hasFocus) _flushSave();
  }

  void _onTextChanged() {
    if (_updatingController) return;
    final text = _controller.text;
    if (text != _contentForHeight) {
      setState(() => _contentForHeight = text);
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _flushSave);
  }

  void _flushSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final content = _controller.text;
    if (content != widget.note.content) {
      context.read<NotesProvider>().updateNote(widget.note.id, content);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nc = Theme.of(context).extension<NoteColors>();

    final borderColor = _focused
        ? Theme.of(context).colorScheme.primary
        : widget.note.isPinned
        ? (nc?.cardBorderPinned ?? Colors.indigo)
        : (nc?.cardBorder ?? Colors.grey.shade200);

    final bgColor = widget.isDraftView
        ? (nc?.draftCardBackground ?? Theme.of(context).cardTheme.color)
        : Theme.of(context).cardTheme.color;

    final height = _NoteCardHeight.compute(
      content: _contentForHeight,
      columnWidth: widget.columnWidth,
      minHeight: widget.minHeight,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(
            LayoutConstants.cardBorderRadius,
          ),
          border: Border.all(
            color: borderColor,
            width: 1.0,
          ),
          boxShadow: (_focused || _hovered)
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
          children: [
            _CardHeader(
              note: widget.note,
              hovered: _hovered,
              focused: _focused,
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildEditor(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(bool isDark) {
    return CodeEditor(
      controller: _controller,
      focusNode: _focusNode,
      wordWrap: true,
      autofocus: false,
      hint: 'Start writing…',
      style: CodeEditorStyle(
        fontSize: 14,
        fontHeight: 1.6,
        backgroundColor: Colors.transparent,
        codeTheme: CodeHighlightTheme(
          languages: {'markdown': CodeHighlightThemeMode(mode: langMarkdown)},
          theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
        ),
      ),
      shortcutOverrideActions: {
        CodeShortcutSaveIntent: CallbackAction<CodeShortcutSaveIntent>(
          onInvoke: (_) => _flushSave(),
        ),
      },
      indicatorBuilder: null,
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.note,
    required this.hovered,
    required this.focused,
  });

  final Note note;
  final bool hovered;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (note.isPinned) ...[
          Icon(
            Icons.push_pin_rounded,
            size: 13,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          _formatTime(note.updatedAt.toLocal()),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const Spacer(),
        AnimatedOpacity(
          opacity: (hovered || focused) ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: IgnorePointer(
            ignoring: !(hovered || focused),
            child: _ActionRow(note: note),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime local) {
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    final m = const [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][local.month];
    return '$m ${local.day}, '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

// ── Action Row ────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<NotesProvider>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CardAction(
          icon: note.isPinned
              ? Icons.push_pin_rounded
              : Icons.push_pin_outlined,
          tooltip: note.isPinned ? 'Unpin' : 'Pin to top',
          onTap: () => provider.togglePin(note.id),
          active: note.isPinned,
        ),
        _CardAction(
          icon: note.isDraft
              ? Icons.move_to_inbox_outlined
              : Icons.drafts_outlined,
          tooltip: note.isDraft ? 'Move to timeline' : 'Move to drafts',
          onTap: () => provider.toggleDraft(note.id),
        ),
        _CardAction(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Delete',
          isDestructive: true,
          onTap: () => _confirmDelete(context, provider),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, NotesProvider provider) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              provider.deleteNote(note.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.isDestructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? Colors.red.shade400
        : active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).textTheme.labelSmall?.color;
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

// ── Height Helper ─────────────────────────────────────────────────────────────

/// Estimates NoteCard height from content and column width.
///
/// Counts logical lines × word-wrap factor to approximate visual lines.
/// Slightly over-estimates to avoid internal scrolling.
abstract final class _NoteCardHeight {
  static const _fontSize = 14.0;
  static const _lineHeightMult = 1.65;
  static const _lineHeightPx = _fontSize * _lineHeightMult;
  static const _headerHeight = 36.0;
  static const _vPad = LayoutConstants.cardPadding * 2;
  static const _hPad = LayoutConstants.cardPadding * 2;
  static const _minVisualLines = 3;
  static const _charWidthRatio = 0.52;

  static double compute({
    required String content,
    required double columnWidth,
    double? minHeight,
  }) {
    final availWidth = columnWidth - _hPad;
    final charsPerLine = (availWidth / (_fontSize * _charWidthRatio))
        .floor()
        .clamp(20, 200);

    int visualLines = 0;
    for (final line in content.split('\n')) {
      visualLines += max(1, (line.length / charsPerLine).ceil());
    }
    visualLines = max(visualLines, _minVisualLines);

    final computed = visualLines * _lineHeightPx + _headerHeight + _vPad;
    return minHeight != null ? max(minHeight, computed) : computed;
  }
}
