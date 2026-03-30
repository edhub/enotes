import 'package:flutter/material.dart';

import '../parsers/markdown_parser.dart';

/// A [TextEditingController] that renders Markdown syntax with inline styles.
///
/// Drop-in replacement for [TextEditingController]: just swap the class name.
/// Theme (dark / light) is read automatically from [BuildContext] each frame.
class MarkdownController extends TextEditingController {
  MarkdownController({super.text});

  // ── Parse cache ────────────────────────────────────────────────────────────
  // Re-parsing on every frame is unnecessary when the text hasn't changed.
  // Cache is keyed on (text, isDark); invalidated automatically when either
  // changes.  baseStyle is intentionally excluded: it is a constant TextStyle
  // set by MarkdownEditor and never changes at runtime.
  String? _cachedText;
  bool? _cachedDark;
  TextSpan? _cachedSpan;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // No active IME composing region → full markdown parse with cache.
    if (!value.composing.isValid || !withComposing) {
      if (text == _cachedText && isDark == _cachedDark && _cachedSpan != null) {
        return _cachedSpan!;
      }
      final span = MarkdownParser.buildSpan(
        text: text,
        baseStyle: base,
        isDark: isDark,
      );
      _cachedText = text;
      _cachedDark = isDark;
      _cachedSpan = span;
      return span;
    }

    // Active IME composing: parse the full text without splitting around the
    // composing boundary.  Splitting would break markdown constructs that cross
    // it (e.g. "**bo[ld]**" where [] is the composing region).  The platform
    // IME commits text correctly without an explicit underline span.
    return MarkdownParser.buildSpan(text: text, baseStyle: base, isDark: isDark);
  }
}
