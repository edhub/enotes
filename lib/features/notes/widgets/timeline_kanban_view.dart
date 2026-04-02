import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/layout_constants.dart';
import '../providers/notes_provider.dart';
import '../services/export_service.dart';
import 'draft_column.dart';
import 'time_column.dart';
import 'trash_column.dart';

/// Root layout widget.
///
/// Horizontal scroll contains all columns side by side.
/// Each column owns its own vertical [ScrollController] (via [CustomScrollView]).
/// Shift + mouse-wheel is captured at this level and forwarded to the
/// horizontal [ScrollController].
///
/// Columns: Draft | Today | Yesterday | … | Recently Deleted
class TimelineKanbanView extends StatefulWidget {
  const TimelineKanbanView({super.key});

  @override
  State<TimelineKanbanView> createState() => _TimelineKanbanViewState();
}

class _TimelineKanbanViewState extends State<TimelineKanbanView> {
  final _hScroll = ScrollController();
  bool _showJumpButton = false;

  @override
  void initState() {
    super.initState();
    _hScroll.addListener(_onHScroll);
  }

  @override
  void dispose() {
    _hScroll.removeListener(_onHScroll);
    _hScroll.dispose();
    super.dispose();
  }

  void _onHScroll() {
    final shouldShow = _hScroll.offset > LayoutConstants.jumpButtonThreshold;
    if (shouldShow != _showJumpButton) {
      setState(() => _showJumpButton = shouldShow);
    }
  }

  void _jumpToStart() {
    _hScroll.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _handleShiftScroll(double dy) {
    if (!_hScroll.hasClients) return;
    final target = (_hScroll.offset + dy).clamp(
      _hScroll.position.minScrollExtent,
      _hScroll.position.maxScrollExtent,
    );
    _hScroll.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          // Scroll horizontal view back to the start (Today column).
          _hScroll.animateTo(
            0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
          context.read<NotesProvider>().requestNewNoteFocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Stack(
            children: [
              _buildScrollArea(context),
              _buildJumpButton(),
              const _DataMenuButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollArea(BuildContext context) {
    final availH = MediaQuery.of(context).size.height;
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        if (HardwareKeyboard.instance.isShiftPressed) {
          _handleShiftScroll(event.scrollDelta.dy);
        }
      },
      child: Scrollbar(
        controller: _hScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            height: availH,
            child: _buildRow(context, availH),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, double availH) {
    final provider = context.watch<NotesProvider>();
    final columns = provider.timeColumns;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: LayoutConstants.pageHPad),
        DraftColumn(availableHeight: availH),
        const SizedBox(width: LayoutConstants.columnGap),
        ...columns.map(
          (col) => Row(
            children: [
              TimeColumn(data: col, availableHeight: availH),
              const SizedBox(width: LayoutConstants.columnGap),
            ],
          ),
        ),
        TrashColumn(availableHeight: availH),
        const SizedBox(width: LayoutConstants.pageHPad),
      ],
    );
  }

  Widget _buildJumpButton() {
    return Positioned(
      left: 24,
      bottom: 24,
      child: AnimatedOpacity(
        opacity: _showJumpButton ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_showJumpButton,
          child: FloatingActionButton.small(
            heroTag: 'jumpToToday',
            tooltip: 'Back to Today',
            onPressed: _jumpToStart,
            child: const Icon(Icons.first_page_rounded),
          ),
        ),
      ),
    );
  }
}

// ── Data menu (import / export) ────────────────────────────────────────────

enum _MenuAction { exportJson, exportMarkdown, importJson }

/// Fixed top-right button that opens the import / export popup menu.
class _DataMenuButton extends StatefulWidget {
  const _DataMenuButton();

  @override
  State<_DataMenuButton> createState() => _DataMenuButtonState();
}

class _DataMenuButtonState extends State<_DataMenuButton> {
  final _export = const ExportService();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 24,
      top: 16,
      child: PopupMenuButton<_MenuAction>(
        icon: const Icon(Icons.more_vert),
        tooltip: 'Import / Export',
        onSelected: _handleAction,
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
    );
  }

  Future<void> _handleAction(_MenuAction action) async {
    final provider = context.read<NotesProvider>();

    switch (action) {
      case _MenuAction.exportJson:
        final result = await _export.exportJson(provider.allNotes);
        if (!mounted || result == null) return;
        _snack(result ? '✓ JSON backup saved' : 'Export failed — check logs');

      case _MenuAction.exportMarkdown:
        final result = await _export.exportMarkdown(provider.allNotes);
        if (!mounted || result == null) return;
        _snack(result ? '✓ Markdown export saved' : 'Export failed — check logs');

      case _MenuAction.importJson:
        final confirmed = await _confirmImport();
        if (!mounted || !confirmed) return;
        final notes = await _export.importJson();
        if (!mounted) return;
        if (notes == null) {
          _snack('Import failed — invalid or unsupported file');
          return;
        }
        if (notes.isEmpty) return; // user cancelled the file picker
        await provider.importNotes(notes);
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
