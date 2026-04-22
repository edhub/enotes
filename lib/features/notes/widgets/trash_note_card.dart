import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import 'note_card_container.dart';

/// A read-only card shown in the trash column.
/// Provides "Restore" and "Delete Forever" actions, always visible.
class TrashNoteCard extends ConsumerStatefulWidget {
  const TrashNoteCard({super.key, required this.note});

  final Note note;

  @override
  ConsumerState<TrashNoteCard> createState() => _TrashNoteCardState();
}

class _TrashNoteCardState extends ConsumerState<TrashNoteCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();
    final mutedText = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.color
        ?.withValues(alpha: 0.68);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: NoteCardContainer(
        hovered: _hovered,
        backgroundColor: Theme.of(context).cardTheme.color?.withValues(alpha: 0.94),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: Theme.of(context).textTheme.labelSmall?.color,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormatter.relative(
                    widget.note.deletedAt!,
                    prefix: 'deleted',
                  ),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                _TrashAction(
                  icon: Icons.restore_rounded,
                  tooltip: 'Restore',
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor:
                      (nc?.hoverTint ?? Theme.of(context).colorScheme.primary.withValues(alpha: 0.10)),
                  onTap: () => ref
                      .read(notesProvider.notifier)
                      .restoreNote(widget.note.id),
                ),
                const SizedBox(width: 6),
                _TrashAction(
                  icon: Icons.delete_forever_rounded,
                  tooltip: 'Delete Forever',
                  color: nc?.destructive ?? Colors.red.shade400,
                  backgroundColor: nc?.destructiveSoft ?? Colors.red.withValues(alpha: 0.10),
                  onTap: () => ref
                      .read(notesProvider.notifier)
                      .permanentlyDeleteNote(widget.note.id),
                ),
              ],
            ),
            if (widget.note.content.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(
                widget.note.content,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedText,
                  height: 1.58,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrashAction extends StatelessWidget {
  const _TrashAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      ),
    );
  }
}
