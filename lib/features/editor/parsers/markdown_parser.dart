import 'package:flutter/material.dart';

// ── Theme colours ─────────────────────────────────────────────────────────────

class _Colors {
  final Color heading;
  final Color quote;
  final Color list;
  final Color link;
  final Color codeText;
  final Color codeBg;
  final Color punct; // subtle markdown punctuation (---, list bullet…)
  final Color highlightBg;

  const _Colors({
    required this.heading,
    required this.quote,
    required this.list,
    required this.link,
    required this.codeText,
    required this.codeBg,
    required this.punct,
    required this.highlightBg,
  });

  static const dark = _Colors(
    heading: Color(0xFFE5C07B),
    quote: Color(0xFF7F848E),
    list: Color(0xFF7F848E),
    link: Color(0xFF61AFEF),
    codeText: Color(0xFFABB2BF),
    codeBg: Color(0xFF2C313A),
    punct: Color(0xFF5C6370),
    highlightBg: Color(0xFF4B4000),
  );

  static const light = _Colors(
    heading: Color(0xFF0550AE),
    quote: Color(0xFF9CA3AF),
    list: Color(0xFF9CA3AF),
    link: Color(0xFF0969DA),
    codeText: Color(0xFF383A42),
    codeBg: Color(0xFFF0F0F0),
    punct: Color(0xFFBBBEC5),
    highlightBg: Color(0xFFFFF8CC),
  );
}

// ── Public API ────────────────────────────────────────────────────────────────

/// Converts a Markdown [text] string into a styled [TextSpan] tree.
///
/// **Editor mode**: raw Markdown syntax is kept visible but visually styled,
/// so cursor positions in a [TextField] remain correct.
///
/// Supported constructs:
/// - Headings `# … ######`
/// - Blockquotes `>`
/// - Unordered lists `- / * / +`
/// - Ordered lists `1.`
/// - Fenced code blocks ` ``` `
/// - Horizontal rules `---`
/// - Inline: bold (`*`/`**`/`***`/`_`/`__`),
///   strikethrough (`~~`), highlight (`==`), inline code (`` ` ``),
///   links `[text](url)`
///   Note: single `*`/`_` also render as bold — no separate italic style.
class MarkdownParser {
  MarkdownParser._();

  static const _mono = 'monospace';

  static const _headingSizes = [26.0, 22.0, 19.0, 17.0, 15.0, 14.0];

  /// Build a [TextSpan] tree from [text].
  static TextSpan buildSpan({
    required String text,
    required TextStyle baseStyle,
    required bool isDark,
  }) {
    if (text.isEmpty) return TextSpan(text: '', style: baseStyle);
    final c = isDark ? _Colors.dark : _Colors.light;
    return _buildLines(text, baseStyle, c);
  }

  // ── Line-level ─────────────────────────────────────────────────────────────

  static final _fenceRe = RegExp(r'^\s*```');
  static final _headingRe = RegExp(r'^(#{1,6})(\s.*)$');
  static final _hrRe = RegExp(r'^(\*{3,}|-{3,}|_{3,})\s*$');
  static final _quoteRe = RegExp(r'^(>+\s*)(.*)$');
  static final _ulRe = RegExp(r'^(\s*[-*+]\s+)(.*)$');
  static final _olRe = RegExp(r'^(\s*\d+\.\s+)(.*)$');

  static TextSpan _buildLines(String text, TextStyle base, _Colors c) {
    final lines = text.split('\n');
    final spans = <InlineSpan>[];
    var inFencedCode = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (_fenceRe.hasMatch(line)) {
        inFencedCode = !inFencedCode;
        spans.add(_codeLineSpan(line, base, c));
      } else if (inFencedCode) {
        spans.add(_codeLineSpan(line, base, c));
      } else {
        spans.add(_parseLine(line, base, c));
      }

      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: base));
      }
    }

    return TextSpan(style: base, children: spans);
  }

  static TextSpan _codeLineSpan(String line, TextStyle base, _Colors c) =>
      TextSpan(
        text: line,
        style: base.copyWith(
          fontFamily: _mono,
          color: c.codeText,
          backgroundColor: c.codeBg,
        ),
      );

  static TextSpan _parseLine(String line, TextStyle base, _Colors c) {
    if (line.isEmpty) return TextSpan(text: '', style: base);

    // Heading
    final hm = _headingRe.firstMatch(line);
    if (hm != null) {
      final level = (hm.group(1)!.length - 1).clamp(0, 5);
      final headStyle = base.copyWith(
        fontSize: _headingSizes[level],
        fontWeight: FontWeight.bold,
        color: c.heading,
      );
      // group(1) = "#+" prefix, group(2) = " text" (space included).
      // Only the body goes through inline parsing; "#" never triggers bold.
      return TextSpan(
        style: base,
        children: [
          TextSpan(text: hm.group(1), style: headStyle),
          ..._parseInline(hm.group(2)!, headStyle, c),
        ],
      );
    }

    // Horizontal rule
    if (_hrRe.hasMatch(line)) {
      return TextSpan(text: line, style: base.copyWith(color: c.punct));
    }

    // Blockquote
    final qm = _quoteRe.firstMatch(line);
    if (qm != null) {
      final quoteStyle = base.copyWith(
        color: c.quote,
        fontStyle: FontStyle.italic,
      );
      return TextSpan(
        style: base,
        children: [
          TextSpan(text: qm.group(1), style: quoteStyle),
          ..._parseInline(qm.group(2)!, quoteStyle, c),
        ],
      );
    }

    // Unordered list
    final um = _ulRe.firstMatch(line);
    if (um != null) {
      return TextSpan(
        style: base,
        children: [
          TextSpan(text: um.group(1), style: base.copyWith(color: c.list)),
          ..._parseInline(um.group(2)!, base, c),
        ],
      );
    }

    // Ordered list
    final om = _olRe.firstMatch(line);
    if (om != null) {
      return TextSpan(
        style: base,
        children: [
          TextSpan(text: om.group(1), style: base.copyWith(color: c.list)),
          ..._parseInline(om.group(2)!, base, c),
        ],
      );
    }

    return TextSpan(style: base, children: _parseInline(line, base, c));
  }

  // ── Inline-level ──────────────────────────────────────────────────────────

  /// Scan [text] left-to-right: at each position find the earliest-starting
  /// (longest on tie) pattern match, emit it, then advance past it.
  ///
  /// [RegExp.allMatches] is called with a [start] offset so lookbehind
  /// assertions still see the original text before the cursor.  This avoids
  /// the "consumed delimiter" false-positive where the closing `**` of a bold
  /// span can form a spurious opening `*` for the next italic span when all
  /// matches are collected up-front with a single pass.
  static List<InlineSpan> _parseInline(
    String text,
    TextStyle base,
    _Colors c,
  ) {
    if (text.isEmpty) return const [];

    final spans = <InlineSpan>[];
    var pos = 0;

    while (pos < text.length) {
      RegExpMatch? best;
      _SpanBuilder? bestBuilder;

      for (final p in _inlinePatterns) {
        final m = _firstFrom(p.re, text, pos);
        if (m == null) continue;
        if (best == null ||
            m.start < best.start ||
            (m.start == best.start && m.end > best.end)) {
          best = m;
          bestBuilder = p.span;
        }
      }

      if (best == null) {
        spans.add(TextSpan(text: text.substring(pos), style: base));
        break;
      }

      if (best.start > pos) {
        spans.add(TextSpan(text: text.substring(pos, best.start), style: base));
      }
      spans.add(bestBuilder!(best, base, c));
      pos = best.end;
    }

    return spans;
  }

  /// Returns the first match of [re] in [text] at or after [start],
  /// or `null` if there is no such match.
  static RegExpMatch? _firstFrom(RegExp re, String text, int start) {
    for (final m in re.allMatches(text, start)) {
      return m;
    }
    return null;
  }

  static final _inlinePatterns = <_Pattern>[
    // Inline code  `code`
    _Pattern(
      RegExp(r'`([^`\n]+)`'),
      (m, base, c) => TextSpan(
        text: m.group(0),
        style: base.copyWith(
          fontFamily: _mono,
          color: c.codeText,
          backgroundColor: c.codeBg,
        ),
      ),
    ),
    // Bold  ***text***  **text**  *text*  __text__  _text_
    // Single * and _ also render as bold — no separate italic style.
    // (_ variants guarded against snake_case with word-boundary assertions.)
    _Pattern(
      RegExp(
        r'\*{1,3}(?!\s)([^*\n]+)(?<!\s)\*{1,3}'
        r'|(?<!\w)_{1,2}([^_\n]+)_{1,2}(?!\w)',
      ),
      (m, base, c) => TextSpan(
        text: m.group(0),
        style: base.copyWith(fontWeight: FontWeight.bold),
      ),
    ),
    // Strikethrough  ~~text~~
    _Pattern(
      RegExp(r'~~(?!\s)([^~\n]+)(?<!\s)~~'),
      (m, base, c) => TextSpan(
        text: m.group(0),
        style: base.copyWith(
          decoration: TextDecoration.lineThrough,
          decorationColor: base.color,
        ),
      ),
    ),
    // Highlight  ==text==
    _Pattern(
      RegExp(r'==(?!\s)([^=\n]+)(?<!\s)=='),
      (m, base, c) => TextSpan(
        text: m.group(0),
        style: base.copyWith(backgroundColor: c.highlightBg),
      ),
    ),
    // Link  [text](url)
    _Pattern(
      RegExp(r'\[([^\]\n]+)\]\([^)\n]+\)'),
      (m, base, c) => TextSpan(
        text: m.group(0),
        style: base.copyWith(
          color: c.link,
          decoration: TextDecoration.underline,
          decorationColor: c.link,
        ),
      ),
    ),
  ];
}

// ── Private helpers ───────────────────────────────────────────────────────────

typedef _SpanBuilder =
    InlineSpan Function(RegExpMatch m, TextStyle base, _Colors c);

class _Pattern {
  const _Pattern(this.re, this.span);
  final RegExp re;
  final _SpanBuilder span;
}
