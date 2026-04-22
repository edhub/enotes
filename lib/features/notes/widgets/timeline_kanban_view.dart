import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_constants.dart';
import '../providers/notes_provider.dart';
import '../providers/search_provider.dart';
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
class TimelineKanbanView extends ConsumerStatefulWidget {
  const TimelineKanbanView({super.key});

  @override
  ConsumerState<TimelineKanbanView> createState() =>
      _TimelineKanbanViewState();
}

class _TimelineKanbanViewState extends ConsumerState<TimelineKanbanView> {
  final _hScroll = ScrollController();
  bool _showJumpButton = false;

  @override
  void initState() {
    super.initState();
    _hScroll.addListener(_onHScroll);
    // Register a global hardware-keyboard handler so that Cmd+K fires even
    // when no widget inside this tree currently holds focus (e.g. after the
    // user switches to another window and returns without clicking anything).
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _hScroll.removeListener(_onHScroll);
    _hScroll.dispose();
    super.dispose();
  }

  /// Global key handler: intercepts Cmd+K regardless of focus state.
  ///
  /// Returns `true` to consume the event (prevent further propagation)
  /// only when the shortcut matches, so all other keys pass through normally.
  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!HardwareKeyboard.instance.isMetaPressed) return false;

    final draftIndex = switch (event.logicalKey) {
      LogicalKeyboardKey.digit1 => 0,
      LogicalKeyboardKey.digit2 => 1,
      LogicalKeyboardKey.digit3 => 2,
      LogicalKeyboardKey.digit4 => 3,
      LogicalKeyboardKey.digit5 => 4,
      _ => null,
    };
    if (draftIndex != null) {
      _triggerFocusAction(() {
        _hScroll.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
        ref.read(notesProvider.notifier).activateDraftAndFocus(draftIndex);
      });
      return true;
    }

    // Cmd+K → focus the new-note composer in the Today column.
    if (event.logicalKey == LogicalKeyboardKey.keyK) {
      _triggerFocusAction(() {
        _hScroll.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
        ref.read(notesProvider.notifier).requestNewNoteFocus();
      });
      return true;
    }

    // Cmd+F → focus the search bar in the Draft column.
    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      _triggerFocusAction(() {
        _hScroll.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
        ref.read(searchQueryProvider.notifier).requestFocus();
      });
      return true;
    }

    return false;
  }

  /// Executes a focus-triggering [action] immediately if some widget already
  /// holds focus, or defers it by a short delay when nothing is focused.
  ///
  /// On macOS, calling `TextInput.setClient` (triggered internally by
  /// `FocusNode.requestFocus`) while the OS "window became key" event is still
  /// being processed causes the text-input connection to not activate until the
  /// next window-activation cycle. The guard delay lets macOS complete its
  /// focus hand-off before we ask Flutter to attach a text-input client.
  void _triggerFocusAction(VoidCallback action) {
    if (FocusManager.instance.primaryFocus != null && FocusManager.instance.primaryFocus!.context != null) {
      // A widget already owns the keyboard — plain focus transfer works fine.
      action();
    } else {
      // No widget is focused: we may be in the middle of a macOS window
      // activation. Wait one frame + a small platform buffer before acting.
      Future.delayed(const Duration(milliseconds: 80), () {
        if (!mounted) return;
        action();
      });
    }
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

  void _resolveAsHorizontalScroll(PointerScrollEvent event) {
    GestureBinding.instance.pointerSignalResolver.register(event, (
      PointerSignalEvent e,
    ) {
      final scrollEvent = e as PointerScrollEvent;
      _handleShiftScroll(scrollEvent.scrollDelta.dy);
    });
    GestureBinding.instance.pointerSignalResolver.resolve(event);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
          body: Stack(
            children: [
              _buildScrollArea(context),
              _buildHeaderWheelLayer(),
              _buildJumpButton(),
              const _DataMenuButton(),
            ],
          ),
        );
  }

  Widget _buildHeaderWheelLayer() {
    // 列头区域不需要按 Shift，所有滚轮事件均转横向
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: LayoutConstants.columnHeaderHeight,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent) return;
          _resolveAsHorizontalScroll(event);
        },
      ),
    );
  }

  Widget _buildScrollArea(BuildContext context) {
    final availH = MediaQuery.of(context).size.height;
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        if (HardwareKeyboard.instance.isShiftPressed) {
          _resolveAsHorizontalScroll(event);
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
    final columns = ref.watch(filteredTimeColumnsProvider);

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
class _DataMenuButton extends ConsumerStatefulWidget {
  const _DataMenuButton();

  @override
  ConsumerState<_DataMenuButton> createState() => _DataMenuButtonState();
}

class _DataMenuButtonState extends ConsumerState<_DataMenuButton> {
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
