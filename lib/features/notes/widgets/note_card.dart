import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/layout_constants.dart';
import '../../editor/controllers/markdown_controller.dart';
import '../../editor/services/markdown_shortcuts.dart';
import '../../editor/widgets/markdown_editor.dart';
import '../../../core/theme/app_theme.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';

/// A note card with fully inline editing via [MarkdownEditor].
///
/// - ESC unfocuses the editor.
/// - No timestamp is shown in the header by default.
/// - On hover/focus a ⋯ button appears; tapping it opens a popover with
///   timestamps and (for non-draft cards) a "Move to Trash" action.
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
  final double? minHeight;

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
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

  // ── Key / focus / text listeners ───────────────────────────────────────────

  /// Handles keyboard shortcuts:
  /// - ESC → unfocus the editor
  /// - Cmd+B → toggle bold
  /// - Cmd+L → toggle unordered list
  /// - Shift+Cmd+L → toggle ordered list
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // ESC → unfocus
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      node.unfocus();
      return KeyEventResult.handled;
    }

    // Check for Cmd (macOS) / Ctrl (other platforms) modifier
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

    // Cmd+B → toggle bold
    if (event.logicalKey == LogicalKeyboardKey.keyB) {
      _applyShortcut(MarkdownShortcuts.toggleBold);
      return KeyEventResult.handled;
    }

    // Cmd+L → toggle unordered list
    if (event.logicalKey == LogicalKeyboardKey.keyL && !isShift) {
      _applyShortcut(MarkdownShortcuts.toggleUnorderedList);
      return KeyEventResult.handled;
    }

    // Shift+Cmd+L → toggle ordered list
    if (event.logicalKey == LogicalKeyboardKey.keyL && isShift) {
      _applyShortcut(MarkdownShortcuts.toggleOrderedList);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Applies a markdown shortcut transformation to the current text/selection.
  void _applyShortcut(
    (String, TextSelection) Function(String, TextSelection) shortcut,
  ) {
    final (newText, newSelection) = shortcut(
      _controller.text,
      _controller.selection,
    );
    _updatingController = true;
    _controller.text = newText;
    _controller.selection = newSelection;
    _updatingController = false;
    _flushSave();
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
      context.read<NotesProvider>().updateNote(widget.note.id, content);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  // Minimum visual height: 3 lines of text + top/bottom padding.
  static const _minLineHeight = 14.0 * 1.6; // fontSize * lineHeight
  static const _minContentHeight = 1 * _minLineHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nc = Theme.of(context).extension<NoteColors>();

    final borderColor = _focused
        ? Theme.of(context).colorScheme.primary
        : (nc?.cardBorder ?? Colors.grey.shade200);

    final bgColor = widget.isDraftView
        ? (nc?.draftCardBackground ?? Theme.of(context).cardTheme.color)
        : Theme.of(context).cardTheme.color;

    final minCardHeight =
        widget.minHeight ??
        (_minContentHeight + LayoutConstants.cardPadding * 2);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: BoxConstraints(minHeight: minCardHeight),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(LayoutConstants.cardBorderRadius),
          border: Border.all(color: borderColor, width: 1.0),
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
        child: Stack(
          children: [
            MarkdownEditor(
              controller: _controller,
              focusNode: _focusNode,
              hint: 'Start writing…',
            ),
            // ⋯ button floats at top-right; zero layout impact.
            Positioned(
              top: 0,
              right: 0,
              child: _InfoButton(
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

// ── Global note-info menu (singleton OverlayEntry) ───────────────────────────
//
// Only one info popover exists at any time, inserted directly into the root
// Overlay so it is completely independent of any note card's focus / hover
// state.  Clicking outside the popover, or selecting an action, dismisses it.

abstract final class _NoteInfoMenu {
  static OverlayEntry? _entry;
  static String? _noteId;

  static bool isShowingFor(String id) => _entry != null && _noteId == id;

  /// Opens the menu anchored to [link].  If already open for the same note,
  /// toggles it closed instead.
  static void show({
    required BuildContext context,
    required String noteId,
    required LayerLink link,
    required Note note,
    required bool isDraftView,
  }) {
    if (isShowingFor(noteId)) {
      dismiss();
      return;
    }
    dismiss(); // close any previously open menu
    _noteId = noteId;
    _entry = OverlayEntry(
      builder: (ctx) => _NoteInfoOverlay(
        link: link,
        note: note,
        isDraftView: isDraftView,
        onDismiss: dismiss,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  static void dismiss() {
    _entry?.remove();
    _entry = null;
    _noteId = null;
  }
}

// ── Info button (trigger) ─────────────────────────────────────────────────────

class _InfoButton extends StatefulWidget {
  const _InfoButton({
    required this.note,
    required this.isDraftView,
    required this.hovered,
    required this.focused,
  });

  final Note note;
  final bool isDraftView;
  final bool hovered;
  final bool focused;

  @override
  State<_InfoButton> createState() => _InfoButtonState();
}

class _InfoButtonState extends State<_InfoButton> {
  // Each button owns a LayerLink used both for positioning the follower and
  // as the TapRegion groupId so clicking the button never fires onTapOutside.
  final _link = LayerLink();

  @override
  void dispose() {
    // If this button's menu is open, close it when the card is recycled.
    if (_NoteInfoMenu.isShowingFor(widget.note.id)) _NoteInfoMenu.dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).textTheme.labelSmall?.color;
    final visible = widget.hovered || widget.focused;

    // ⚠️  CompositedTransformTarget MUST be the outermost widget so it is
    // always included in the paint tree.  Flutter's RenderOpacity skips
    // painting entirely when opacity == 0 (performance optimisation), which
    // would prevent the LeaderLayer from being pushed to the compositing tree,
    // breaking the LayerLink and making the overlay follower disappear.
    // By keeping CompositedTransformTarget *outside* AnimatedOpacity the
    // LeaderLayer is always active regardless of button visibility.
    return CompositedTransformTarget(
      link: _link,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: IgnorePointer(
          ignoring: !visible,
          child: TapRegion(
            groupId: _link,
            child: Tooltip(
              message: 'Note info',
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => _NoteInfoMenu.show(
                  context: context,
                  noteId: widget.note.id,
                  link: _link,
                  note: widget.note,
                  isDraftView: widget.isDraftView,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 15,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Overlay widget (positioned independently in root Overlay) ─────────────────

class _NoteInfoOverlay extends StatelessWidget {
  const _NoteInfoOverlay({
    required this.link,
    required this.note,
    required this.isDraftView,
    required this.onDismiss,
  });

  final LayerLink link;
  final Note note;
  final bool isDraftView;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    // CompositedTransformFollower must be the overlay root for positioning.
    // Align(widthFactor/heightFactor: 1) shrinks the subtree to content size
    // so TapRegion's hit area matches only the visible popover box.
    return CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomRight,
      followerAnchor: Alignment.topRight,
      offset: const Offset(0, 6),
      child: Align(
        alignment: Alignment.topRight,
        widthFactor: 1,
        heightFactor: 1,
        child: TapRegion(
          groupId: link,
          onTapOutside: (_) => onDismiss(),
          child: Material(
            type: MaterialType.transparency,
            child: _InfoPopover(
              note: note,
              isDraftView: isDraftView,
              onClose: onDismiss,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Info popover content ──────────────────────────────────────────────────────

class _InfoPopover extends StatelessWidget {
  const _InfoPopover({
    required this.note,
    required this.isDraftView,
    required this.onClose,
  });

  final Note note;
  final bool isDraftView;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nc = Theme.of(context).extension<NoteColors>();
    final bgColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final borderColor = nc?.cardBorder ?? Colors.grey.shade200;

    return Container(
      width: 216,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timestamps ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                _TimeRow(
                  icon: Icons.access_time_rounded,
                  label: 'Modified',
                  time: note.updatedAt.toLocal(),
                ),
                const SizedBox(height: 10),
                _TimeRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Created',
                  time: note.createdAt.toLocal(),
                ),
              ],
            ),
          ),
          // ── Delete action (non-draft only) ───────────────────────────────
          if (!isDraftView) ...[
            Divider(height: 1, color: borderColor),
            _DeleteRow(note: note, onClose: onClose),
          ],
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.icon, required this.label, required this.time});

  final IconData icon;
  final String label;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).textTheme.labelSmall?.color;
    final primary = Theme.of(context).textTheme.bodyMedium?.color;

    return Row(
      children: [
        Icon(icon, size: 13, color: secondary),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: secondary)),
            const SizedBox(height: 1),
            Text(
              _format(time),
              style: TextStyle(
                fontSize: 12,
                color: primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _format(DateTime local) {
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    const months = [
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
    ];
    return '${months[local.month]} ${local.day},  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _DeleteRow extends StatefulWidget {
  const _DeleteRow({required this.note, required this.onClose});

  final Note note;
  final VoidCallback onClose;

  @override
  State<_DeleteRow> createState() => _DeleteRowState();
}

class _DeleteRowState extends State<_DeleteRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          widget.onClose();
          context.read<NotesProvider>().deleteNote(widget.note.id);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovered
                ? (isDark
                      ? Colors.red.withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.06))
                : Colors.transparent,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 14,
                color: Colors.red.shade400,
              ),
              const SizedBox(width: 10),
              Text(
                'Move to Trash',
                style: TextStyle(fontSize: 13, color: Colors.red.shade400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
