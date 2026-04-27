import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'markdown_shortcuts_editing.part.dart';
part 'markdown_shortcuts_lists.part.dart';

/// Handles Bear-style markdown shortcuts for a text editor.
///
/// Supported shortcuts:
/// - `Tab` / `Shift+Tab`: indent / outdent selected lines by 2 spaces
/// - `Cmd+B`: toggle bold (`*...*`) around the selection
/// - `Cmd+L`: toggle unordered list (`- `) on selected lines
/// - `Shift+Cmd+L`: toggle ordered list (`1. `, `2. `…) on selected lines
/// - `Enter`: continue / terminate list and quote prefixes
/// - `ESC`: unfocus editor
class MarkdownShortcuts {
  MarkdownShortcuts._();

  /// Processes one hardware-key event.
  static KeyEventResult handleKeyEvent({
    required KeyEvent event,
    required FocusNode node,
    required TextEditingController controller,
    VoidCallback? onApply,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      node.unfocus();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_isComposing(controller)) return KeyEventResult.ignored;
      if (applyEnterContinuation(controller)) {
        onApply?.call();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (_isComposing(controller)) return KeyEventResult.ignored;
      final (newText, newSel) = _isShiftPressed()
          ? applyOutdent(controller.text, controller.selection)
          : applyIndent(controller.text, controller.selection);
      final maxOffset = newText.length;
      final safeSel = TextSelection(
        baseOffset: newSel.baseOffset.clamp(0, maxOffset),
        extentOffset: newSel.extentOffset.clamp(0, maxOffset),
      );
      final old = controller.value;
      if (newText != old.text ||
          safeSel.baseOffset != old.selection.baseOffset ||
          safeSel.extentOffset != old.selection.extentOffset) {
        controller.value = old.copyWith(text: newText, selection: safeSel);
        onApply?.call();
      }
      return KeyEventResult.handled;
    }

    if (!_isMetaPressed()) return KeyEventResult.ignored;

    final shortcut = switch (event.logicalKey) {
      LogicalKeyboardKey.keyB => toggleBold,
      LogicalKeyboardKey.keyL when !_isShiftPressed() => toggleUnorderedList,
      LogicalKeyboardKey.keyL when _isShiftPressed() => toggleOrderedList,
      _ => null,
    };
    if (shortcut == null) return KeyEventResult.ignored;

    applyShortcut(controller: controller, shortcut: shortcut);
    onApply?.call();
    return KeyEventResult.handled;
  }

  /// If the caret sits on a list / quote line, continues or terminates it.
  static bool applyEnterContinuation(TextEditingController controller) =>
      _MarkdownContinuation.apply(controller);

  /// Indents every selected line by two spaces.
  static (String text, TextSelection selection) applyIndent(
    String text,
    TextSelection selection,
  ) => _MarkdownIndentation.applyIndent(text, selection);

  /// Removes up to two leading spaces (or one tab) from each selected line.
  static (String text, TextSelection selection) applyOutdent(
    String text,
    TextSelection selection,
  ) => _MarkdownIndentation.applyOutdent(text, selection);

  /// Applies a Markdown [shortcut] transformation to [controller]'s current
  /// text and selection.
  static void applyShortcut({
    required TextEditingController controller,
    required (String, TextSelection) Function(String, TextSelection) shortcut,
  }) {
    final (newText, newSel) = shortcut(controller.text, controller.selection);
    controller.value = controller.value.copyWith(
      text: newText,
      selection: newSel,
    );
  }

  /// Toggles bold formatting (`*...*`) around the current selection.
  static (String text, TextSelection selection) toggleBold(
    String text,
    TextSelection selection,
  ) => _MarkdownBolding.toggle(text, selection);

  /// Toggles unordered list formatting on selected lines.
  static (String text, TextSelection selection) toggleUnorderedList(
    String text,
    TextSelection selection,
  ) => _MarkdownLists.toggleUnordered(text, selection);

  /// Toggles ordered list formatting on selected lines.
  static (String text, TextSelection selection) toggleOrderedList(
    String text,
    TextSelection selection,
  ) => _MarkdownLists.toggleOrdered(text, selection);

  static bool _isComposing(TextEditingController controller) {
    final composing = controller.value.composing;
    return composing.isValid && !composing.isCollapsed;
  }

  static bool _isShiftPressed() =>
      HardwareKeyboard.instance.isLogicalKeyPressed(
        LogicalKeyboardKey.shiftLeft,
      ) ||
      HardwareKeyboard.instance.isLogicalKeyPressed(
        LogicalKeyboardKey.shiftRight,
      );

  static bool _isMetaPressed() =>
      HardwareKeyboard.instance.isLogicalKeyPressed(
        LogicalKeyboardKey.metaLeft,
      ) ||
      HardwareKeyboard.instance.isLogicalKeyPressed(
        LogicalKeyboardKey.metaRight,
      );
}
