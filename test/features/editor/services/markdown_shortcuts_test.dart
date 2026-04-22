import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enotes/features/editor/services/markdown_shortcuts.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Creates a collapsed selection at [offset].
TextSelection _sel(int offset) => TextSelection.collapsed(offset: offset);

/// Creates a selection from [start] to [end].
TextSelection _range(int start, int end) =>
    TextSelection(baseOffset: start, extentOffset: end);

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── toggleBold ──────────────────────────────────────────────────────────

  group('toggleBold', () {
    group('collapsed selection (cursor)', () {
      test('inserts ** at cursor position', () {
        final (text, sel) = MarkdownShortcuts.toggleBold('hello world', _sel(6));
        expect(text, 'hello **world');
        expect(sel.isCollapsed, isTrue);
        expect(sel.extentOffset, 7); // cursor between the two *
      });

      test('at beginning of text', () {
        final (text, sel) = MarkdownShortcuts.toggleBold('text', _sel(0));
        expect(text, '**text');
        expect(sel.extentOffset, 1);
      });

      test('at end of text', () {
        final (text, sel) = MarkdownShortcuts.toggleBold('text', _sel(4));
        expect(text, 'text**');
        expect(sel.extentOffset, 5);
      });

      test('in empty text', () {
        final (text, sel) = MarkdownShortcuts.toggleBold('', _sel(0));
        expect(text, '**');
        expect(sel.extentOffset, 1);
      });

      test('cursor inside bold region removes bold', () {
        // *world*: opening * at 6, content at 7-11, closing * at 12
        final (text, sel) = MarkdownShortcuts.toggleBold('hello *world*', _sel(9));
        expect(text, 'hello world');
        expect(sel.isCollapsed, isTrue);
        expect(sel.extentOffset, 8);
      });

      test('cursor at start of bold content removes bold', () {
        final (text, sel) = MarkdownShortcuts.toggleBold('hello *world*', _sel(7));
        expect(text, 'hello world');
        expect(sel.extentOffset, 6);
      });

      test('cursor at end of bold content removes bold', () {
        // selEnd(12) <= innerEnd(12) → still inside
        final (text, sel) = MarkdownShortcuts.toggleBold('hello *world*', _sel(12));
        expect(text, 'hello world');
        expect(sel.extentOffset, 11);
      });

      test('cursor outside bold region inserts **', () {
        final (text, sel) = MarkdownShortcuts.toggleBold('hello *world*', _sel(3));
        expect(text, 'hel**lo *world*');
        expect(sel.extentOffset, 4);
      });

      test('cursor inside empty ** removes it', () {
        // Empty bold: cursor between two consecutive `*` (after pressing cmd+b once)
        // **| -> cursor at position 1
        final (text, sel) = MarkdownShortcuts.toggleBold('hello **world', _sel(7));
        expect(text, 'hello world');
        expect(sel.extentOffset, 6);
      });

      test('cursor between ** at start of text removes it', () {
        // **| text -> cursor at position 1
        final (text, sel) = MarkdownShortcuts.toggleBold('** text', _sel(1));
        expect(text, ' text');
        expect(sel.extentOffset, 0);
      });

      test('cursor between ** at end of text removes it', () {
        // 'text **' -> t=0,e=1,x=2,t=3,space=4,*=5,*=6
        // cursor at position 6 (between the two `*`) -> removes both
        final (text, sel) = MarkdownShortcuts.toggleBold('text **', _sel(6));
        expect(text, 'text ');
        expect(sel.extentOffset, 5);
      });

      test('cursor after single * at end inserts **', () {
        // 'text *' -> t=0,e=1,x=2,t=3,space=4,*=5
        // cursor at position 5 -> inserts ** at cursor, result is 'text ***'
        final (text, sel) = MarkdownShortcuts.toggleBold('text *', _sel(5));
        expect(text, 'text ***');
        expect(sel.extentOffset, 6);
      });

      test('cursor inside empty ** in middle of text removes it', () {
        // before **|after -> cursor at position 8
        final (text, sel) = MarkdownShortcuts.toggleBold('before **after', _sel(8));
        expect(text, 'before after');
        expect(sel.extentOffset, 7);
      });
    });

    group('with selection', () {
      test('wraps selected text with *', () {
        final (text, sel) = MarkdownShortcuts.toggleBold('hello world', _range(6, 11));
        expect(text, 'hello *world*');
        expect(sel.start, 7);
        expect(sel.end, 12);
      });

      test('wraps Chinese text', () {
        final (text, sel) = MarkdownShortcuts.toggleBold('这是重要内容', _range(2, 6));
        expect(text, '这是*重要内容*');
        expect(sel.start, 3);
        expect(sel.end, 7);
      });

      test('wraps text with spaces', () {
        final (text, _) = MarkdownShortcuts.toggleBold('hello beautiful world', _range(6, 15));
        expect(text, 'hello *beautiful* world');
      });

      test('selection inside bold region removes bold', () {
        final (text, sel) = MarkdownShortcuts.toggleBold('hello *world*', _range(7, 12));
        expect(text, 'hello world');
        expect(sel.start, 6);
        expect(sel.end, 11);
      });

      test('selection inside bold region (Chinese) removes bold', () {
        // '这是*粗体*文字': * at 2, content at 3-4, * at 5
        final (text, sel) = MarkdownShortcuts.toggleBold('这是*粗体*文字', _range(3, 5));
        expect(text, '这是粗体文字');
        expect(sel.start, 2);
        expect(sel.end, 4);
      });

      test('partial selection (not completely inside) wraps with *', () {
        // selEnd(13) > innerEnd(12) → not inside → wraps
        final (text, _) = MarkdownShortcuts.toggleBold('hello *world*', _range(7, 13));
        expect(text, 'hello **world**');
      });
    });

    group('multiple toggles', () {
      test('toggle twice returns to original text', () {
        const original = 'hello world';
        final first = MarkdownShortcuts.toggleBold(original, _range(6, 11));
        expect(first.$1, 'hello *world*');
        // Selection covers inner content (7, 12) — completely inside the bold span.
        expect(first.$2.start, 7);
        expect(first.$2.end, 12);
        // Second toggle: (7, 12) is inside *world* → remove bold.
        final second = MarkdownShortcuts.toggleBold(first.$1, first.$2);
        expect(second.$1, original);
      });

      test('toggle twice with Chinese returns to original text', () {
        const original = '这是重要内容';
        final first = MarkdownShortcuts.toggleBold(original, _range(2, 6));
        expect(first.$1, '这是*重要内容*');
        final second = MarkdownShortcuts.toggleBold(first.$1, first.$2);
        expect(second.$1, original);
      });
    });

    group('multiline selection', () {
      test('wraps each full line separately', () {
        // 'line1\nline2\nline3' -> select from 0 to end
        final (text, sel) = MarkdownShortcuts.toggleBold(
          'line1\nline2\nline3',
          _range(0, 17),
        );
        expect(text, '*line1*\n*line2*\n*line3*');
      });

      test('wraps each line with partial selection', () {
        // 'hello\nworld' -> select 'ello\nwor' (positions 1-9)
        // h|ello|\n|wor|ld -> *ello*\n*wor*ld
        final (text, sel) = MarkdownShortcuts.toggleBold(
          'hello\nworld',
          _range(1, 9),
        );
        expect(text, 'h*ello*\n*wor*ld');
      });

      test('wraps Chinese lines separately', () {
        // '第一行\n第二行' -> full selection
        final (text, sel) = MarkdownShortcuts.toggleBold(
          '第一行\n第二行',
          _range(0, 7),
        );
        expect(text, '*第一行*\n*第二行*');
      });

      test('wraps partial Chinese lines', () {
        // '这是第一行\n这是第二行' -> positions: 这=0,是=1,第=2,一=3,行=4,\n=5,这=6,是=7,第=8,二=9,行=10
        // select positions 2-10: 第一行\n这是第二 (第,一,行,\n,这,是,第,二)
        // result: 这是*第一行*\n*这是第二*行
        final (text, sel) = MarkdownShortcuts.toggleBold(
          '这是第一行\n这是第二行',
          _range(2, 10),
        );
        expect(text, '这是*第一行*\n*这是第二*行');
      });

      test('single line selection (no newline) still works', () {
        final (text, sel) = MarkdownShortcuts.toggleBold(
          'hello world',
          _range(0, 11),
        );
        expect(text, '*hello world*');
      });

      test('empty lines in selection are skipped', () {
        // 'line1\n\nline3' -> select all
        final (text, sel) = MarkdownShortcuts.toggleBold(
          'line1\n\nline3',
          _range(0, 12),
        );
        expect(text, '*line1*\n\n*line3*');
      });

      test('selection starting mid-line, ending mid-line', () {
        // 'abc\ndef\nghi' -> positions: a=0, b=1, c=2, \n=3, d=4, e=5, f=6, \n=7, g=8, h=9, i=10
        // select positions 2-10 (c\ndef\ngh) -> each portion wrapped separately
        // line 0: 'abc' -> wrap [2:3]='c' -> 'ab*c*'
        // line 1: 'def' -> wrap [0:3]='def' -> '*def*'
        // line 2: 'ghi' -> wrap [0:2]='gh' -> '*gh*i'
        final (text, sel) = MarkdownShortcuts.toggleBold(
          'abc\ndef\nghi',
          _range(2, 10),
        );
        expect(text, 'ab*c*\n*def*\n*gh*i');
      });
    });
  });

  // ── toggleUnorderedList ─────────────────────────────────────────────────────

  group('toggleUnorderedList', () {
    group('single line', () {
      test('adds - prefix to plain line', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          'hello world',
          _sel(6),
        );
        expect(text, '- hello world');
        expect(sel.start, 0);
        expect(sel.end, text.length);
      });

      test('adds - prefix to Chinese line', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          '列表项',
          _sel(2),
        );
        expect(text, '- 列表项');
      });

      test('removes - prefix from unordered list', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          '- hello world',
          _sel(6),
        );
        expect(text, 'hello world');
      });

      test('removes * prefix from unordered list', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          '* hello world',
          _sel(6),
        );
        expect(text, 'hello world');
      });

      test('removes + prefix from unordered list', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          '+ hello world',
          _sel(6),
        );
        expect(text, 'hello world');
      });

      test('removes - prefix from Chinese', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          '- 列表项',
          _sel(3),
        );
        expect(text, '列表项');
      });

      test('removes ordered prefix and adds - (mutually exclusive)', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          '1. hello world',
          _sel(6),
        );
        expect(text, '- hello world');
      });

      test('removes ordered prefix 2. and adds -', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          '2. second item',
          _sel(6),
        );
        expect(text, '- second item');
      });

      test('preserves indentation', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          '  indented text',
          _sel(6),
        );
        expect(text, '  - indented text');
      });

      test('removes prefix from indented list', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          '  - indented item',
          _sel(6),
        );
        expect(text, '  indented item');
      });

      test('empty line remains unchanged', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          '',
          _sel(0),
        );
        expect(text, '');
      });

      test('whitespace-only line remains unchanged', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          '   ',
          _sel(1),
        );
        expect(text, '   ');
      });
    });

    group('multiple lines', () {
      test('adds - to multiple lines', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          'first\nsecond\nthird',
          _range(2, 15),
        );
        expect(text, '- first\n- second\n- third');
      });

      test('adds - to multiple Chinese lines', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          '第一项\n第二项\n第三项',
          _range(2, 8),
        );
        expect(text, '- 第一项\n- 第二项\n- 第三项');
      });

      test('removes - from all selected lines', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          '- first\n- second\n- third',
          _range(2, 20),
        );
        expect(text, 'first\nsecond\nthird');
      });

      test('mixed: some have prefix, some do not → add to all', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          '- first\nsecond\n- third',
          _range(2, 18),
        );
        expect(text, '- first\n- second\n- third');
      });

      test('converts ordered to unordered (mutually exclusive)', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          '1. first\n2. second\n3. third',
          _range(2, 22),
        );
        expect(text, '- first\n- second\n- third');
      });

      test('preserves indentation in multiline', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          '  first\n  second',
          _range(2, 12),
        );
        expect(text, '  - first\n  - second');
      });

      test('empty line in middle is skipped', () {
        final (text, sel) = MarkdownShortcuts.toggleUnorderedList(
          'first\n\nthird',
          _range(2, 9),
        );
        expect(text, '- first\n\n- third');
      });
    });
  });

  // ── toggleOrderedList ───────────────────────────────────────────────────────

  group('toggleOrderedList', () {
    group('single line', () {
      test('adds 1. prefix to plain line', () {
        final (text, sel) = MarkdownShortcuts.toggleOrderedList(
          'hello world',
          _sel(6),
        );
        expect(text, '1. hello world');
      });

      test('adds 1. prefix to Chinese line', () {
        final (text, sel) = MarkdownShortcuts.toggleOrderedList(
          '列表项',
          _sel(2),
        );
        expect(text, '1. 列表项');
      });

      test('removes 1. prefix from ordered list', () {
        final (text, sel) = MarkdownShortcuts.toggleOrderedList(
          '1. hello world',
          _sel(6),
        );
        expect(text, 'hello world');
      });

      test('removes 2. prefix from ordered list', () {
        final (text, sel) = MarkdownShortcuts.toggleOrderedList(
          '2. hello world',
          _sel(6),
        );
        expect(text, 'hello world');
      });

      test('removes - prefix and adds 1. (mutually exclusive)', () {
        final (text, sel) = MarkdownShortcuts.toggleOrderedList(
          '- hello world',
          _sel(6),
        );
        expect(text, '1. hello world');
      });

      test('removes * prefix and adds 1.', () {
        final (text, sel) = MarkdownShortcuts.toggleOrderedList(
          '* hello world',
          _sel(6),
        );
        expect(text, '1. hello world');
      });

      test('preserves indentation', () {
        final (text, sel) = MarkdownShortcuts.toggleOrderedList(
          '  indented text',
          _sel(6),
        );
        expect(text, '  1. indented text');
      });
    });

    group('multiple lines', () {
      test('adds numbered prefixes (1., 2., 3.)', () {
        final (text, sel) = MarkdownShortcuts.toggleOrderedList(
          'first\nsecond\nthird',
          _range(2, 15),
        );
        expect(text, '1. first\n2. second\n3. third');
      });

      test('adds numbered prefixes to Chinese lines', () {
        final (text, sel) = MarkdownShortcuts.toggleOrderedList(
          '第一项\n第二项\n第三项',
          _range(2, 8),
        );
        expect(text, '1. 第一项\n2. 第二项\n3. 第三项');
      });

      test('removes numbered prefixes from all lines', () {
        final (text, sel) = MarkdownShortcuts.toggleOrderedList(
          '1. first\n2. second\n3. third',
          _range(2, 22),
        );
        expect(text, 'first\nsecond\nthird');
      });

      test('removes non-consecutive numbered prefixes', () {
        final (text, sel) = MarkdownShortcuts.toggleOrderedList(
          '5. first\n10. second',
          _range(2, 15),
        );
        expect(text, 'first\nsecond');
      });

      test('converts unordered to ordered (mutually exclusive)', () {
        final (text, sel) = MarkdownShortcuts.toggleOrderedList(
          '- first\n- second\n- third',
          _range(2, 20),
        );
        expect(text, '1. first\n2. second\n3. third');
      });

      test('mixed prefixes → all converted to ordered', () {
        final (text, sel) = MarkdownShortcuts.toggleOrderedList(
          '- first\n1. second\n* third',
          _range(2, 18),
        );
        expect(text, '1. first\n2. second\n3. third');
      });

      test('empty line in middle is skipped', () {
        final (text, sel) = MarkdownShortcuts.toggleOrderedList(
          'first\n\nthird',
          _range(2, 9),
        );
        expect(text, '1. first\n\n2. third');
      });

      test('preserves indentation in multiline', () {
        final (text, sel) = MarkdownShortcuts.toggleOrderedList(
          '  first\n  second',
          _range(2, 12),
        );
        expect(text, '  1. first\n  2. second');
      });
    });
  });

  // ── mutual exclusivity ─────────────────────────────────────────────────────

  group('mutual exclusivity (unordered vs ordered)', () {
    test('toggleUnordered on ordered → becomes unordered', () {
      final (text, _) = MarkdownShortcuts.toggleUnorderedList(
        '1. item',
        _sel(3),
      );
      expect(text, '- item');
    });

    test('toggleOrdered on unordered → becomes ordered', () {
      final (text, _) = MarkdownShortcuts.toggleOrderedList(
        '- item',
        _sel(3),
      );
      expect(text, '1. item');
    });

    test('unordered → ordered → unordered cycle', () {
      const start = 'plain text';
      final unordered = MarkdownShortcuts.toggleUnorderedList(start, _sel(3));
      expect(unordered.$1, '- plain text');

      final ordered = MarkdownShortcuts.toggleOrderedList(unordered.$1, unordered.$2);
      expect(ordered.$1, '1. plain text');

      final backToUnordered = MarkdownShortcuts.toggleUnorderedList(ordered.$1, ordered.$2);
      expect(backToUnordered.$1, '- plain text');
    });

    test('converting multi-line ordered to unordered', () {
      final (text, _) = MarkdownShortcuts.toggleUnorderedList(
        '1. first\n2. second\n3. third',
        _range(0, 26),
      );
      expect(text, '- first\n- second\n- third');
    });

    test('converting multi-line unordered to ordered with correct numbering', () {
      final (text, _) = MarkdownShortcuts.toggleOrderedList(
        '- first\n- second\n- third',
        _range(0, 20),
      );
      expect(text, '1. first\n2. second\n3. third');
    });
  });

  // ── Enter continuation ──────────────────────────────────────────────────

  group('applyEnterContinuation', () {
    /// Helper: build a controller with caret at [offset] then call the
    /// continuation. Returns (newText, newCaret, handled).
    (String, int, bool) run(String text, int offset) {
      final c = TextEditingController(text: text)
        ..selection = _sel(offset);
      final handled = MarkdownShortcuts.applyEnterContinuation(c);
      return (c.text, c.selection.baseOffset, handled);
    }

    test('continues unordered list with the same bullet', () {
      final (text, caret, ok) = run('- first', 7);
      expect(ok, isTrue);
      expect(text, '- first\n- ');
      expect(caret, '- first\n- '.length);
    });

    test('continues ordered list incrementing the number', () {
      final (text, caret, ok) = run('1. first', 8);
      expect(ok, isTrue);
      expect(text, '1. first\n2. ');
      expect(caret, '1. first\n2. '.length);
    });

    test('continues quote with the same > marker', () {
      final (text, _, ok) = run('> hello', 7);
      expect(ok, isTrue);
      expect(text, '> hello\n> ');
    });

    test('preserves leading indentation', () {
      final (text, _, ok) = run('    - nested', 12);
      expect(ok, isTrue);
      expect(text, '    - nested\n    - ');
    });

    test('terminates list when content is empty', () {
      final (text, caret, ok) = run('- ', 2);
      expect(ok, isTrue);
      expect(text, '');
      expect(caret, 0);
    });

    test('terminates indented list preserving indent', () {
      final (text, caret, ok) = run('    - ', 6);
      expect(ok, isTrue);
      expect(text, '    ');
      expect(caret, 4);
    });

    test('does nothing on plain text', () {
      final (text, caret, ok) = run('plain text', 10);
      expect(ok, isFalse);
      expect(text, 'plain text');
      expect(caret, 10);
    });

    test('does nothing when selection is not collapsed', () {
      final c = TextEditingController(text: '- item')..selection = _range(2, 6);
      expect(MarkdownShortcuts.applyEnterContinuation(c), isFalse);
    });

    test('inserts continuation in the middle of a list line (splits content)',
        () {
      // Caret in the middle of "- hello world" between "hello" and " world".
      final (text, caret, ok) = run('- hello world', 7);
      expect(ok, isTrue);
      expect(text, '- hello\n-  world');
      expect(caret, '- hello\n- '.length);
    });
  });
}