import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_constants.dart';
import '../providers/search_provider.dart';
import 'draft_column.dart';
import 'jump_to_today_button.dart';
import 'time_column.dart';
import 'timeline_shortcuts_controller.dart';

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
  ConsumerState<TimelineKanbanView> createState() => _TimelineKanbanViewState();
}

class _TimelineKanbanViewState extends ConsumerState<TimelineKanbanView> {
  final _hScroll = ScrollController();
  late final TimelineShortcutsController _shortcuts;
  bool _showJumpButton = false;

  @override
  void initState() {
    super.initState();
    _shortcuts = TimelineShortcutsController(
      ref: ref,
      hScroll: _hScroll,
      isMounted: () => mounted,
    );
    _hScroll.addListener(_onHScroll);
    HardwareKeyboard.instance.addHandler(_shortcuts.handleGlobalKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_shortcuts.handleGlobalKey);
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
          JumpToTodayButton(visible: _showJumpButton, onPressed: _jumpToStart),
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
      height: LayoutConstants.columnHeaderHeight + LayoutConstants.pageHPad * 2,
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
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: LayoutConstants.pageHPad,
              ),
              child: _buildRow(context, availH - LayoutConstants.pageHPad * 2),
            ),
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
        const SizedBox(width: LayoutConstants.pageHPad),
      ],
    );
  }
}
