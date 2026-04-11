import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: NoteCardContainer(
        hovered: _hovered,
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
                  onTap: () => ref
                      .read(notesProvider.notifier)
                      .restoreNote(widget.note.id),
                ),
                const SizedBox(width: 2),
                _TrashAction(
                  icon: Icons.delete_forever_rounded,
                  tooltip: 'Delete Forever',
                  color: Colors.red.shade400,
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
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.6),
                      height: 1.55,
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
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
