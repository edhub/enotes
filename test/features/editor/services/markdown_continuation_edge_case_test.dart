import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enotes/features/editor/services/markdown_shortcuts.dart';

void main() {
  group('MarkdownContinuation edge cases', () {
    // These test the applyEnterContinuation behavior
    // Note: Bug #8 - RangeError when cursor at position 0
    // Tests that trigger this bug are skipped until fixed
    
    test('cursor in middle of non-list text returns false', () {
      final controller = TextEditingController(text: 'hello world');
      controller.selection = TextSelection.collapsed(offset: 5);
      final result = MarkdownShortcuts.applyEnterContinuation(controller);
      expect(result, false);
    });

    test('cursor at end of non-list text returns false', () {
      final controller = TextEditingController(text: 'hello world');
      controller.selection = TextSelection.collapsed(offset: 11);
      final result = MarkdownShortcuts.applyEnterContinuation(controller);
      expect(result, false);
    });

    test('non-collapsed selection returns false', () {
      final controller = TextEditingController(text: '- item');
      controller.selection = TextSelection(baseOffset: 2, extentOffset: 6);
      final result = MarkdownShortcuts.applyEnterContinuation(controller);
      expect(result, false);
    });

    test('empty list item terminates list', () {
      final controller = TextEditingController(text: '- '); // cursor at position 2
      controller.selection = TextSelection.collapsed(offset: 2);
      final result = MarkdownShortcuts.applyEnterContinuation(controller);
      expect(result, true);
      expect(controller.text, ''); // List prefix removed
      expect(controller.selection.start, 0);
    });

    test('ordered list empty item terminates', () {
      final controller = TextEditingController(text: '1. '); // cursor at position 3
      controller.selection = TextSelection.collapsed(offset: 3);
      final result = MarkdownShortcuts.applyEnterContinuation(controller);
      expect(result, true);
      expect(controller.text, '');
    });

    test('quote empty item terminates', () {
      final controller = TextEditingController(text: '> '); // cursor at position 2
      controller.selection = TextSelection.collapsed(offset: 2);
      final result = MarkdownShortcuts.applyEnterContinuation(controller);
      expect(result, true);
      expect(controller.text, '');
    });

    test('nested quote continues', () {
      final controller = TextEditingController(text: '> > content');
      controller.selection = TextSelection.collapsed(offset: 11); // End of text
      final result = MarkdownShortcuts.applyEnterContinuation(controller);
      expect(result, true);
      // Note: The continuation only captures one '>' not both
      expect(controller.text, '> > content\n> ');
    });

    test('ordered list increments number', () {
      final controller = TextEditingController(text: '5. item');
      controller.selection = TextSelection.collapsed(offset: 7);
      final result = MarkdownShortcuts.applyEnterContinuation(controller);
      expect(result, true);
      expect(controller.text, '5. item\n6. ');
    });

    test('unordered list with content continues', () {
      final controller = TextEditingController(text: '- first item');
      controller.selection = TextSelection.collapsed(offset: 12);
      final result = MarkdownShortcuts.applyEnterContinuation(controller);
      expect(result, true);
      expect(controller.text, '- first item\n- ');
    });

    test('list with indent continues with indent', () {
      final controller = TextEditingController(text: '  - nested');
      controller.selection = TextSelection.collapsed(offset: 10);
      final result = MarkdownShortcuts.applyEnterContinuation(controller);
      expect(result, true);
      expect(controller.text, '  - nested\n  - ');
    });

    test('single character list item', () {
      final controller = TextEditingController(text: '- a');
      controller.selection = TextSelection.collapsed(offset: 3);
      final result = MarkdownShortcuts.applyEnterContinuation(controller);
      expect(result, true);
      expect(controller.text, '- a\n- ');
    });

    // Bug #8: RangeError when cursor at position 0 (FIXED)
    test('Bug #8 - cursor at position 0 in empty text returns false (fixed)', () {
      final controller = TextEditingController(text: '');
      controller.selection = TextSelection.collapsed(offset: 0);
      // After fix: should return false (not throw)
      final result = MarkdownShortcuts.applyEnterContinuation(controller);
      expect(result, false);
    });

    test('cursor at position 0 in list continues list', () {
      final controller = TextEditingController(text: '- item');
      controller.selection = TextSelection.collapsed(offset: 0);
      // After fix: no crash. Since cursor is on the first line which is a list,
      // it returns true and tries to continue the list
      final result = MarkdownShortcuts.applyEnterContinuation(controller);
      expect(result, true);
    });
  });

  group('MarkdownIndentation edge cases', () {
    test('indent empty text', () {
      final (text, sel) = MarkdownShortcuts.applyIndent('', TextSelection.collapsed(offset: 0));
      expect(text, '  '); // Adds 2 spaces
      expect(sel.extentOffset, 2);
    });

    test('indent single line', () {
      final (text, sel) = MarkdownShortcuts.applyIndent('hello', TextSelection.collapsed(offset: 3));
      expect(text, '  hello');
    });

    test('outdent empty text', () {
      final (text, sel) = MarkdownShortcuts.applyOutdent('', TextSelection.collapsed(offset: 0));
      expect(text, '');
    });

    test('outdent text with no indent', () {
      final (text, sel) = MarkdownShortcuts.applyOutdent('hello', TextSelection.collapsed(offset: 3));
      expect(text, 'hello');
    });

    test('outdent partially indented text', () {
      final (text, sel) = MarkdownShortcuts.applyOutdent(' hello', TextSelection.collapsed(offset: 6));
      expect(text, 'hello');
    });

    test('outdent fully indented text (2 spaces)', () {
      final (text, sel) = MarkdownShortcuts.applyOutdent('  hello', TextSelection.collapsed(offset: 7));
      expect(text, 'hello');
    });

    test('outdent tab indented text', () {
      final (text, sel) = MarkdownShortcuts.applyOutdent('\thello', TextSelection.collapsed(offset: 6));
      expect(text, 'hello');
    });
  });
}
