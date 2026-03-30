import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enotes/features/editor/parsers/markdown_parser.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

const _base = TextStyle(fontSize: 14, color: Color(0xFF1F2328));

TextSpan _build(String text, {bool isDark = false}) =>
    MarkdownParser.buildSpan(text: text, baseStyle: _base, isDark: isDark);

/// Flatten a [TextSpan] tree into a list of leaf spans (those with text).
List<TextSpan> _flat(InlineSpan root) {
  final out = <TextSpan>[];
  void visit(InlineSpan s) {
    if (s is TextSpan) {
      if (s.text != null && s.text!.isNotEmpty) out.add(s);
      s.children?.forEach(visit);
    }
  }
  visit(root);
  return out;
}

/// Find the first span whose [TextSpan.text] equals [t], or `null`.
TextSpan? _spanOf(List<TextSpan> spans, String t) =>
    spans.cast<TextSpan?>().firstWhere((s) => s?.text == t, orElse: () => null);

// Style predicate shortcuts ────────────────────────────────────────────────────
bool _bold(List<TextSpan> s) =>
    s.any((e) => e.style?.fontWeight == FontWeight.bold);
bool _italic(List<TextSpan> s) =>
    s.any((e) => e.style?.fontStyle == FontStyle.italic);
bool _strike(List<TextSpan> s) => s.any(
  (e) => e.style?.decoration?.contains(TextDecoration.lineThrough) ?? false,
);
bool _hl(List<TextSpan> s) => s.any((e) => e.style?.backgroundColor != null);
bool _mono(List<TextSpan> s) =>
    s.any((e) => e.style?.fontFamily == 'monospace');
bool _ul(List<TextSpan> s) => s.any(
  (e) => e.style?.decoration?.contains(TextDecoration.underline) ?? false,
);
bool _sz(List<TextSpan> s, double size) =>
    s.any((e) => e.style?.fontSize == size);

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── inline — bold (*  **  ***  _  __) ─────────────────────────────────────
  // *x* and _x_ also render as bold (no italic style).

  group('inline — bold', () {
    // ✅ **  and  __
    test('**bold** en', () {
      final s = _flat(_build('**bold**'));
      expect(_bold(s), isTrue);
      expect(_spanOf(s, '**bold**')?.style?.fontWeight, FontWeight.bold);
    });

    test('**粗体文字** zh', () {
      final s = _flat(_build('**粗体文字**'));
      expect(_spanOf(s, '**粗体文字**')?.style?.fontWeight, FontWeight.bold);
    });

    test('__bold__ en', () => expect(_bold(_flat(_build('__bold__'))), isTrue));

    test('__粗体__ zh', () => expect(_bold(_flat(_build('__粗体__'))), isTrue));

    // ✅ single *  and  _  → also bold
    test('*bold* en', () {
      final s = _flat(_build('*bold*'));
      expect(_spanOf(s, '*bold*')?.style?.fontWeight, FontWeight.bold);
    });

    test('*粗体* zh', () {
      expect(_bold(_flat(_build('*粗体*'))), isTrue);
    });

    test('_bold_ en', () => expect(_bold(_flat(_build('_bold_'))), isTrue));

    test('_粗体_ zh', () => expect(_bold(_flat(_build('_粗体_'))), isTrue));

    // ✅ ***  → bold (no italic)
    test('***bold*** en', () {
      final s = _flat(_build('***bold***'));
      expect(_spanOf(s, '***bold***')?.style?.fontWeight, FontWeight.bold);
    });

    test('***粗体*** zh', () => expect(_bold(_flat(_build('***粗体***'))), isTrue));

    // ✅ surrounding text preserved
    test('surrounding text — en', () {
      final s = _flat(_build('before **bold** after'));
      expect(_spanOf(s, '**bold**')?.style?.fontWeight, FontWeight.bold);
      expect(_spanOf(s, 'before ')?.style?.fontWeight, isNot(FontWeight.bold));
      expect(_spanOf(s, ' after')?.style?.fontWeight, isNot(FontWeight.bold));
    });

    test('surrounding text — zh', () {
      final s = _flat(_build('前面**粗体**后面'));
      expect(_spanOf(s, '**粗体**')?.style?.fontWeight, FontWeight.bold);
      expect(_spanOf(s, '前面')?.style?.fontWeight, isNot(FontWeight.bold));
    });

    test('*x* after **bold** on same line — zh', () {
      // Key regression: closing ** must not shadow the following *x* match.
      final s = _flat(_build('**粗体**和*斜体*'));
      expect(_spanOf(s, '**粗体**')?.style?.fontWeight, FontWeight.bold);
      expect(_spanOf(s, '*斜体*')?.style?.fontWeight, FontWeight.bold);
    });

    test('multiple bold spans — mixed', () {
      final s = _flat(_build('**bold1** text **粗体2**'));
      expect(_spanOf(s, '**bold1**')?.style?.fontWeight, FontWeight.bold);
      expect(_spanOf(s, '**粗体2**')?.style?.fontWeight, FontWeight.bold);
    });

    // ❌ no match — no closing delimiter
    test('no close ** → no bold', () => expect(_bold(_flat(_build('**bold'))), isFalse));
    test('no close * → no bold', () => expect(_bold(_flat(_build('*bold'))), isFalse));
    test('no close zh → no bold', () => expect(_bold(_flat(_build('**粗体'))), isFalse));
    test('no close * zh → no bold', () => expect(_bold(_flat(_build('*粗体'))), isFalse));

    // ❌ no match — space after open / before close
    test('space after ** open → no bold', () => expect(_bold(_flat(_build('** bold**'))), isFalse));
    test('space after * open → no bold', () => expect(_bold(_flat(_build('* bold*'))), isFalse));
    test('space before ** close → no bold', () => expect(_bold(_flat(_build('**bold **'))), isFalse));
    test('space before * close → no bold', () => expect(_bold(_flat(_build('*bold *'))), isFalse));
    test('both spaces * → no bold', () => expect(_bold(_flat(_build('* bold *'))), isFalse));

    // ❌ no match — snake_case / word-adjacent _
    test('__ inside snake_case → no bold', () => expect(_bold(_flat(_build('foo__bar__baz'))), isFalse));
    test('_ inside foo_bar_baz → no bold', () => expect(_bold(_flat(_build('foo_bar_baz'))), isFalse));
    test('__ word-adjacent zh → no bold', () => expect(_bold(_flat(_build('foo__中文__bar'))), isFalse));

    // ❌ unrelated * (surrounded by spaces)
    test('* as multiply → no bold', () => expect(_bold(_flat(_build(r'$5 * 3 = $15'))), isFalse));
    test('unrelated * → only adjacent pair matches', () {
      final s = _flat(_build('use * to multiply and *also* to denote'));
      expect(_spanOf(s, '*also*')?.style?.fontWeight, FontWeight.bold);
      final mul = s.where((e) => e.text?.contains('multiply') ?? false);
      expect(mul.any((e) => e.style?.fontWeight == FontWeight.bold), isFalse);
    });
  });

  // ── inline — strikethrough ─────────────────────────────────────────────────

  group('inline — strikethrough', () {
    test('~~strike~~ en', () => expect(_strike(_flat(_build('~~strike~~'))), isTrue));

    test('~~删除线~~ zh', () => expect(_strike(_flat(_build('~~删除线~~'))), isTrue));

    test('surrounded — en', () {
      final s = _flat(_build('text ~~deleted~~ text'));
      expect(_spanOf(s, '~~deleted~~')?.style?.decoration, TextDecoration.lineThrough);
    });

    test('surrounded — zh', () {
      final s = _flat(_build('这段~~过期内容~~请忽略'));
      expect(_spanOf(s, '~~过期内容~~')?.style?.decoration, TextDecoration.lineThrough);
    });

    test('multiple — mixed', () {
      final s = _flat(_build('~~old~~ and ~~废弃~~'));
      expect(_spanOf(s, '~~old~~')?.style?.decoration, TextDecoration.lineThrough);
      expect(_spanOf(s, '~~废弃~~')?.style?.decoration, TextDecoration.lineThrough);
    });

    // ❌
    test('no close → no strike', () => expect(_strike(_flat(_build('~~strike'))), isFalse));
    test('no close zh → no strike', () => expect(_strike(_flat(_build('~~删除线'))), isFalse));
    test('space after open → no strike', () => expect(_strike(_flat(_build('~~ strike~~'))), isFalse));
    test('space before close → no strike', () => expect(_strike(_flat(_build('~~strike ~~'))), isFalse));
  });

  // ── inline — highlight ─────────────────────────────────────────────────────

  group('inline — highlight', () {
    test('==highlight== en', () => expect(_hl(_flat(_build('==highlight=='))), isTrue));
    test('==重要内容== zh', () => expect(_hl(_flat(_build('==重要内容=='))), isTrue));

    test('surrounded — zh', () {
      expect(_spanOf(_flat(_build('请注意==关键字==内容')), '==关键字==')?.style?.backgroundColor, isNotNull);
    });

    test('surrounded — en', () {
      expect(
        _spanOf(_flat(_build('remember to ==fix this== before merge')), '==fix this==')
            ?.style?.backgroundColor,
        isNotNull,
      );
    });

    test('multiple — mixed', () {
      final s = _flat(_build('==important== and ==关键=='));
      expect(_spanOf(s, '==important==')?.style?.backgroundColor, isNotNull);
      expect(_spanOf(s, '==关键==')?.style?.backgroundColor, isNotNull);
    });

    // ❌
    test('no close → no highlight', () => expect(_hl(_flat(_build('==sdf'))), isFalse));
    test('space after open → no highlight', () => expect(_hl(_flat(_build('== sdf=='))), isFalse));
    test('space before close → no highlight', () => expect(_hl(_flat(_build('==sdf =='))), isFalse));
  });

  // ── inline — inline code ───────────────────────────────────────────────────

  group('inline — inline code', () {
    test('`code` en', () {
      final s = _flat(_build('`code`'));
      expect(_mono(s), isTrue);
      expect(_spanOf(s, '`code`')?.style?.backgroundColor, isNotNull);
    });

    test('`代码` zh', () => expect(_mono(_flat(_build('`代码`'))), isTrue));

    test('surrounded — en', () {
      final s = _flat(_build('run `npm install` first'));
      expect(_spanOf(s, '`npm install`')?.style?.fontFamily, 'monospace');
      expect(_spanOf(s, 'run ')?.style?.fontFamily, isNot('monospace'));
    });

    test('surrounded — zh', () {
      final s = _flat(_build('执行`git commit`命令'));
      expect(_spanOf(s, '`git commit`')?.style?.fontFamily, 'monospace');
      expect(_spanOf(s, '执行')?.style?.fontFamily, isNot('monospace'));
    });

    test('code bg in dark mode', () {
      expect(_spanOf(_flat(_build('`code`', isDark: true)), '`code`')?.style?.backgroundColor, isNotNull);
    });

    // ❌
    test('no close → no mono', () => expect(_mono(_flat(_build('`code'))), isFalse));
  });

  // ── inline — link ──────────────────────────────────────────────────────────

  group('inline — link', () {
    test('[text](url) en', () {
      final s = _flat(_build('[click here](https://example.com)'));
      expect(_ul(s), isTrue);
      expect(_spanOf(s, '[click here](https://example.com)')?.style?.color, isNotNull);
    });

    test('[中文链接](url) zh', () => expect(_ul(_flat(_build('[点击这里](https://example.com)'))), isTrue));

    test('link among sentence — zh', () {
      final s = _flat(_build('详情请查看[文档](https://docs.example.com)了解'));
      expect(
        _spanOf(s, '[文档](https://docs.example.com)')?.style?.decoration,
        TextDecoration.underline,
      );
      expect(
        _spanOf(s, '详情请查看')?.style?.decoration,
        isNot(TextDecoration.underline),
      );
    });

    test('link among sentence — en', () {
      final s = _flat(_build('see [release notes](https://github.com/releases) for details'));
      expect(
        _spanOf(s, '[release notes](https://github.com/releases)')?.style?.decoration,
        TextDecoration.underline,
      );
    });

    test('multiple links', () {
      final s = _flat(_build('[home](/) and [关于我们](/about)'));
      expect(_spanOf(s, '[home](/)')?.style?.decoration, TextDecoration.underline);
      expect(_spanOf(s, '[关于我们](/about)')?.style?.decoration, TextDecoration.underline);
    });
  });

  // ── inline — multiple constructs on one line ───────────────────────────────

  group('inline — mixed on one line', () {
    test('bold variants + strike — en', () {
      final s = _flat(_build('**bold** and *also bold* ~~del~~'));
      expect(_spanOf(s, '**bold**')?.style?.fontWeight, FontWeight.bold);
      expect(_spanOf(s, '*also bold*')?.style?.fontWeight, FontWeight.bold);
      expect(_strike(s), isTrue);
    });

    test('bold + strike — zh', () {
      final s = _flat(_build('**粗体**和~~删除~~'));
      expect(_spanOf(s, '**粗体**')?.style?.fontWeight, FontWeight.bold);
      expect(_spanOf(s, '~~删除~~')?.style?.decoration, TextDecoration.lineThrough);
    });

    test('code + bold + strike — en', () {
      final s = _flat(_build('`code` **bold** ~~del~~'));
      expect(_mono(s), isTrue);
      expect(_bold(s), isTrue);
      expect(_strike(s), isTrue);
    });

    test('all inline types — mixed zh/en', () {
      final s = _flat(_build(
        '今天**很重要**，请*认真*阅读`README`，~~旧版本~~已废弃，==高亮==关键内容',
      ));
      expect(_spanOf(s, '**很重要**')?.style?.fontWeight, FontWeight.bold);
      expect(_spanOf(s, '*认真*')?.style?.fontWeight, FontWeight.bold);
      expect(_spanOf(s, '`README`')?.style?.fontFamily, 'monospace');
      expect(_spanOf(s, '~~旧版本~~')?.style?.decoration, TextDecoration.lineThrough);
      expect(_spanOf(s, '==高亮==')?.style?.backgroundColor, isNotNull);
    });

    test('bold + link — zh', () {
      final s = _flat(_build('参考**规范**，详见[RFC](https://rfc.example)'));
      expect(_spanOf(s, '**规范**')?.style?.fontWeight, FontWeight.bold);
      expect(_spanOf(s, '[RFC](https://rfc.example)')?.style?.decoration, TextDecoration.underline);
    });
  });

  // ── block — heading ────────────────────────────────────────────────────────

  group('block — heading', () {
    test('H1 font size 26 — en', () => expect(_sz(_flat(_build('# Hello')), 26.0), isTrue));
    test('H2 font size 22 — en', () => expect(_sz(_flat(_build('## Hello')), 22.0), isTrue));
    test('H3 font size 19 — en', () => expect(_sz(_flat(_build('### Hello')), 19.0), isTrue));
    test('H4 font size 17 — en', () => expect(_sz(_flat(_build('#### Hello')), 17.0), isTrue));
    test('H5 font size 15 — en', () => expect(_sz(_flat(_build('##### Hello')), 15.0), isTrue));
    test('H6 font size 14 — en', () => expect(_sz(_flat(_build('###### Hello')), 14.0), isTrue));

    test('H1 is bold', () => expect(_bold(_flat(_build('# Hello'))), isTrue));

    test('H1 zh — 一级标题', () {
      final s = _flat(_build('# 一级标题'));
      expect(_sz(s, 26.0), isTrue);
      expect(_bold(s), isTrue);
    });

    test('H2 zh — 二级标题', () => expect(_sz(_flat(_build('## 二级标题')), 22.0), isTrue));

    test('H3 zh — 三级标题 with number prefix', () {
      final s = _flat(_build('### 一、项目背景'));
      expect(_sz(s, 19.0), isTrue);
      expect(_bold(s), isTrue);
    });

    test('bold inside heading body', () {
      final s = _flat(_build('## **bold** heading'));
      expect(_spanOf(s, '**bold**')?.style?.fontWeight, FontWeight.bold);
    });

    test('heading prefix "#" uses heading colour — light', () {
      expect(_flat(_build('# Title', isDark: false)).first.style?.color, const Color(0xFF0550AE));
    });

    test('heading prefix "#" uses heading colour — dark', () {
      expect(_flat(_build('# Title', isDark: true)).first.style?.color, const Color(0xFFE5C07B));
    });

    // ❌
    test('no space after # → not a heading', () => expect(_sz(_flat(_build('#heading')), 26.0), isFalse));
  });

  // ── block — blockquote ─────────────────────────────────────────────────────
  // Blockquote applies fontStyle.italic as a block-level style (independent of inline).

  group('block — blockquote', () {
    test('> quote en — italic block style', () {
      expect(_italic(_flat(_build('> some quote'))), isTrue);
    });

    test('> 引用内容 zh', () => expect(_italic(_flat(_build('> 孔子曰：学而时习之'))), isTrue));

    test('> prefix is italic', () {
      expect(_spanOf(_flat(_build('> text')), '> ')?.style?.fontStyle, FontStyle.italic);
    });

    test('>> nested quote', () => expect(_italic(_flat(_build('>> 嵌套引用'))), isTrue));

    test('bold inline inside quote', () {
      final s = _flat(_build('> **important** note'));
      expect(_italic(s), isTrue);
      expect(_bold(s), isTrue);
    });

    test('bold *x* inside zh blockquote', () {
      final s = _flat(_build('> 这是*强调*引用'));
      expect(_italic(s), isTrue); // block-level italic from quote style
      expect(_bold(s), isTrue);  // *强调* is bold
    });
  });

  // ── block — unordered list ─────────────────────────────────────────────────

  group('block — unordered list', () {
    test('- item en', () {
      final s = _flat(_build('- list item'));
      expect(_spanOf(s, '- '), isNotNull);
      expect(_spanOf(s, 'list item'), isNotNull);
    });

    test('* item en', () => expect(_flat(_build('* item')).any((e) => e.text == '* '), isTrue));
    test('+ item en', () => expect(_flat(_build('+ item')).any((e) => e.text == '+ '), isTrue));

    test('- 列表项 zh', () {
      final s = _flat(_build('- 中文列表项'));
      expect(_spanOf(s, '- '), isNotNull);
      expect(_spanOf(s, '中文列表项'), isNotNull);
    });

    test('bold in list body', () => expect(_bold(_flat(_build('- **bold** item'))), isTrue));

    test('multiline list — prefix count', () {
      expect(_flat(_build('- 第一项\n- 第二项\n- 第三项')).where((e) => e.text == '- ').length, 3);
    });
  });

  // ── block — ordered list ───────────────────────────────────────────────────

  group('block — ordered list', () {
    test('1. item en', () {
      final s = _flat(_build('1. first item'));
      expect(_spanOf(s, '1. '), isNotNull);
      expect(_spanOf(s, 'first item'), isNotNull);
    });

    test('1. 有序列表 zh', () {
      final s = _flat(_build('1. 有序列表项'));
      expect(_spanOf(s, '1. '), isNotNull);
      expect(_spanOf(s, '有序列表项'), isNotNull);
    });

    test('multiline ordered — prefix count', () {
      expect(
        _flat(_build('1. first\n2. second\n3. third'))
            .where((e) => e.text?.endsWith('. ') ?? false)
            .length,
        3,
      );
    });

    test('multiline ordered zh — prefix count', () {
      expect(
        _flat(_build('1. 准备\n2. 实施\n3. 验收'))
            .where((e) => e.text?.endsWith('. ') ?? false)
            .length,
        3,
      );
    });
  });

  // ── block — horizontal rule ────────────────────────────────────────────────

  group('block — horizontal rule', () {
    test('--- rule text preserved', () {
      expect(_flat(_build('---')).any((e) => e.text == '---'), isTrue);
    });

    test('*** rule text preserved', () {
      expect(_flat(_build('***')).any((e) => e.text == '***'), isTrue);
    });

    test('___ rule text preserved', () {
      expect(_flat(_build('___')).any((e) => e.text == '___'), isTrue);
    });

    test('--- rule has punct colour (light)', () {
      expect(
        _flat(_build('---', isDark: false)).firstWhere((e) => e.text == '---').style?.color,
        const Color(0xFFBBBEC5),
      );
    });

    test('--- rule has punct colour (dark)', () {
      expect(
        _flat(_build('---', isDark: true)).firstWhere((e) => e.text == '---').style?.color,
        const Color(0xFF5C6370),
      );
    });
  });

  // ── block — fenced code ────────────────────────────────────────────────────

  group('block — fenced code', () {
    const fence = '```\nfoo = bar\nbaz()\n```';

    test('fence lines are monospace', () => expect(_mono(_flat(_build(fence))), isTrue));

    test('code content is monospace', () {
      expect(_spanOf(_flat(_build(fence)), 'foo = bar')?.style?.fontFamily, 'monospace');
    });

    test('code content has background colour', () {
      expect(_spanOf(_flat(_build(fence)), 'foo = bar')?.style?.backgroundColor, isNotNull);
    });

    test('lang tag line (```dart) is styled', () {
      expect(_spanOf(_flat(_build('```dart\nfinal x = 1;\n```')), '```dart')?.style?.fontFamily, 'monospace');
    });

    test('line after closing fence is NOT code', () {
      final s = _flat(_build('```\ncode\n```\nnormal text'));
      expect(_spanOf(s, 'normal text')?.style?.fontFamily, isNot('monospace'));
      expect(_spanOf(s, 'normal text')?.style?.backgroundColor, isNull);
    });

    test('zh content inside code block', () {
      expect(_spanOf(_flat(_build('```\n打印("你好")\n```')), '打印("你好")')?.style?.fontFamily, 'monospace');
    });

    test('markdown inside fence is NOT parsed', () {
      final s = _flat(_build('```\n**bold**\n```'));
      final span = _spanOf(s, '**bold**');
      expect(span, isNotNull);
      expect(span?.style?.fontWeight, isNot(FontWeight.bold));
    });
  });

  // ── multiline — no cross-line matching ────────────────────────────────────

  group('multiline', () {
    test('bold open on line 1, close on line 2 → no bold', () {
      expect(_bold(_flat(_build('**open\nclose**'))), isFalse);
    });

    test('* open on line 1, close on line 2 → no bold', () {
      expect(_bold(_flat(_build('*open\nclose*'))), isFalse);
    });

    test('strike open on line 1, close on line 2 → no strike', () {
      expect(_strike(_flat(_build('~~open\nclose~~'))), isFalse);
    });

    test('independent bold per line', () {
      final s = _flat(_build('**bold line**\n*also bold*'));
      expect(_spanOf(s, '**bold line**')?.style?.fontWeight, FontWeight.bold);
      expect(_spanOf(s, '*also bold*')?.style?.fontWeight, FontWeight.bold);
    });

    test('zh: independent bold per line', () {
      final s = _flat(_build('**粗体行**\n*也是粗体*'));
      expect(_spanOf(s, '**粗体行**')?.style?.fontWeight, FontWeight.bold);
      expect(_spanOf(s, '*也是粗体*')?.style?.fontWeight, FontWeight.bold);
    });
  });

  // ── edge cases ─────────────────────────────────────────────────────────────

  group('edge cases', () {
    test('empty string returns empty span', () {
      expect(_build('').text, '');
    });

    test('plain text en — no styling applied', () {
      final s = _flat(_build('just plain text'));
      expect(_bold(s), isFalse);
      expect(_strike(s), isFalse);
    });

    test('plain text zh — no styling applied', () {
      final s = _flat(_build('普通中文文字不应有任何样式'));
      expect(_bold(s), isFalse);
      expect(_strike(s), isFalse);
    });

    test('dark/light heading colour differs', () {
      final light = _flat(_build('# Title', isDark: false));
      final dark = _flat(_build('# Title', isDark: true));
      expect(light.first.style?.color, isNot(equals(dark.first.style?.color)));
    });

    test('dark/light code bg colour differs', () {
      final l = _spanOf(_flat(_build('`code`', isDark: false)), '`code`')?.style?.backgroundColor;
      final d = _spanOf(_flat(_build('`code`', isDark: true)), '`code`')?.style?.backgroundColor;
      expect(l, isNot(equals(d)));
    });
  });
}
