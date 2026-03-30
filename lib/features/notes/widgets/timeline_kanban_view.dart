import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/layout_constants.dart';
import '../providers/notes_provider.dart';
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
    return Scaffold(
      body: Stack(
        children: [
          _buildScrollArea(context),
          _buildJumpButton(),
          _buildFab(context),
        ],
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

  Widget _buildFab(BuildContext context) {
    return const Positioned(
      right: 24,
      bottom: 24,
      child: _AddNoteFab(),
    );
  }
}

class _AddNoteFab extends StatelessWidget {
  const _AddNoteFab();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'addNote',
      tooltip: 'New note',
      onPressed: () => context.read<NotesProvider>().addNote(''),
      child: const Icon(Icons.add),
    );
  }
}
