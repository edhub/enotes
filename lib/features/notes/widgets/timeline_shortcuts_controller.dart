import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notes_provider.dart';
import '../providers/search_provider.dart';

class TimelineShortcutsController {
  TimelineShortcutsController({
    required this.ref,
    required this.hScroll,
    required this.isMounted,
  });

  final WidgetRef ref;
  final ScrollController hScroll;
  final bool Function() isMounted;

  bool handleGlobalKey(KeyEvent event) {
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
        _animateToStart();
        ref.read(notesProvider.notifier).activateDraftAndFocus(draftIndex);
      });
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyK) {
      _triggerFocusAction(() {
        _animateToStart();
        ref.read(notesProvider.notifier).requestNewNoteFocus();
      });
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      _triggerFocusAction(() {
        _animateToStart();
        ref.read(searchQueryProvider.notifier).requestFocus();
      });
      return true;
    }

    return false;
  }

  void _animateToStart() {
    hScroll.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _triggerFocusAction(VoidCallback action) {
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null && focus.context != null) {
      action();
      return;
    }

    Future.delayed(const Duration(milliseconds: 80), () {
      if (!isMounted()) return;
      action();
    });
  }
}
