import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';

// ── Global note-info menu (singleton OverlayEntry) ───────────────────────────
//
// Only one info popover exists at any time, inserted directly into the root
// Overlay so it is completely independent of any note card's focus / hover
// state.  Clicking outside the popover, or selecting an action, dismisses it.

abstract final class NoteInfoMenu {
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

class NoteInfoButton extends StatefulWidget {
  const NoteInfoButton({
    super.key,
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
  State<NoteInfoButton> createState() => _NoteInfoButtonState();
}

class _NoteInfoButtonState extends State<NoteInfoButton> {
  // Each button owns a LayerLink used both for positioning the follower and
  // as the TapRegion groupId so clicking the button never fires onTapOutside.
  final _link = LayerLink();

  @override
  void dispose() {
    // If this button's menu is open, close it when the card is recycled.
    if (NoteInfoMenu.isShowingFor(widget.note.id)) NoteInfoMenu.dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();
    final iconColor = Theme.of(context).textTheme.labelSmall?.color;
    final visible = widget.hovered || widget.focused;

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
              child: Material(
                color: nc?.hoverTint ?? Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => NoteInfoMenu.show(
                    context: context,
                    noteId: widget.note.id,
                    link: _link,
                    note: widget.note,
                    isDraftView: widget.isDraftView,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
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
    final nc = Theme.of(context).extension<NoteColors>();
    final bgColor = nc?.controlSurface ?? Theme.of(context).cardTheme.color ?? Colors.white;
    final borderColor = nc?.columnBorder ?? Colors.grey.shade200;

    return Container(
      width: 228,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: nc?.popoverShadow ?? Colors.black.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                _TimeRow(
                  icon: Icons.access_time_rounded,
                  label: 'Modified',
                  time: note.updatedAt.toLocal(),
                ),
                const SizedBox(height: 12),
                _TimeRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Created',
                  time: note.createdAt.toLocal(),
                ),
              ],
            ),
          ),
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
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: secondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormatter.absolute(time),
              style: TextStyle(
                fontSize: 12,
                color: primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeleteRow extends ConsumerStatefulWidget {
  const _DeleteRow({required this.note, required this.onClose});

  final Note note;
  final VoidCallback onClose;

  @override
  ConsumerState<_DeleteRow> createState() => _DeleteRowState();
}

class _DeleteRowState extends ConsumerState<_DeleteRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();
    final destructive = nc?.destructive ?? Colors.red.shade400;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          widget.onClose();
          ref.read(notesProvider.notifier).deleteNote(widget.note.id);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovered ? (nc?.destructiveSoft ?? Colors.transparent) : Colors.transparent,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 14,
                color: destructive,
              ),
              const SizedBox(width: 10),
              Text(
                'Move to Trash',
                style: TextStyle(
                  fontSize: 13,
                  color: destructive,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
