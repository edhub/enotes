import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/notes_provider.dart';
import '../services/export_service.dart';

enum _MenuAction { exportJson, exportMarkdown, importJson }

/// Fixed top-right button that opens the import / export popup menu.
class DataMenuButton extends ConsumerStatefulWidget {
  const DataMenuButton({super.key});

  @override
  ConsumerState<DataMenuButton> createState() => _DataMenuButtonState();
}

class _DataMenuButtonState extends ConsumerState<DataMenuButton> {
  final _export = const ExportService();

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();

    return Positioned(
      right: LayoutConstants.pageHPad + 8,
      top: LayoutConstants.pageHPad,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: nc?.controlSurface ?? Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: nc?.searchBarBorder ?? Theme.of(context).dividerColor,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.035),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: PopupMenuButton<_MenuAction>(
          icon: const Icon(Icons.more_horiz_rounded),
          tooltip: 'Import / Export',
          onSelected: _handleAction,
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(36, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _MenuAction.exportJson,
              child: ListTile(
                leading: Icon(Icons.backup_outlined),
                title: Text('Export JSON (full backup)'),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            PopupMenuItem(
              value: _MenuAction.exportMarkdown,
              child: ListTile(
                leading: Icon(Icons.description_outlined),
                title: Text('Export Markdown (plain text)'),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: _MenuAction.importJson,
              child: ListTile(
                leading: Icon(Icons.restore_outlined),
                title: Text('Import JSON…'),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(_MenuAction action) async {
    final notifier = ref.read(notesProvider.notifier);

    switch (action) {
      case _MenuAction.exportJson:
        final result = await _export.exportJson(
          ref.read(notesProvider).allNotes,
        );
        if (!mounted || result == null) return;
        _snack(result ? '✓ JSON backup saved' : 'Export failed — check logs');

      case _MenuAction.exportMarkdown:
        final result = await _export.exportMarkdown(
          ref.read(notesProvider).allNotes,
        );
        if (!mounted || result == null) return;
        _snack(
          result ? '✓ Markdown export saved' : 'Export failed — check logs',
        );

      case _MenuAction.importJson:
        final confirmed = await _confirmImport();
        if (!mounted || !confirmed) return;
        final notes = await _export.importJson();
        if (!mounted) return;
        if (notes == null) {
          _snack('Import failed — invalid or unsupported file');
          return;
        }
        if (notes.isEmpty) return;
        await notifier.importNotes(notes);
        if (!mounted) return;
        _snack('✓ Imported ${notes.length} notes');
    }
  }

  Future<bool> _confirmImport() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Notes'),
        content: const Text(
          'This will replace ALL current notes with the contents of the '
          'selected file. This cannot be undone.\n\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replace All'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        width: 360,
      ),
    );
  }
}
