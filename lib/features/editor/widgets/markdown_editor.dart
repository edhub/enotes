import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/markdown_controller.dart';

/// A lightweight Markdown-aware text editor built on Flutter's [TextField].
///
/// - Renders Markdown syntax visually (editor mode: raw syntax stays visible
///   but is styled, so cursor positions remain accurate).
/// - Adapts colours to dark / light theme automatically via [NoteColors].
/// - Use [MarkdownController] as the controller type.
class MarkdownEditor extends StatelessWidget {
  const MarkdownEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hint,
    this.minLines,
    this.style,
    this.hintStyle,
  });

  final MarkdownController controller;
  final FocusNode focusNode;
  final String? hint;
  final int? minLines;
  final TextStyle? style;
  final TextStyle? hintStyle;

  @override
  Widget build(BuildContext context) {
    final nc = Theme.of(context).extension<NoteColors>();
    final textColor = nc?.editorText;
    final hintColor = nc?.editorHint;
    final cursorColor = nc?.editorCursor ?? Theme.of(context).colorScheme.primary;
    final baseStyle = TextStyle(
      fontSize: 14,
      height: 1.64,
      letterSpacing: 0.05,
      color: textColor,
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      textAlignVertical: TextAlignVertical.top,
      // Let TextField expand naturally based on content.
      // minLines ensures a minimum visual height, maxLines allows unlimited growth.
      minLines: minLines ?? 1,
      maxLines: null,
      style: baseStyle.merge(style),
      cursorColor: cursorColor,
      cursorWidth: 1.5,
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintText: hint,
        hintStyle: baseStyle.copyWith(
          color: hintColor,
          fontWeight: FontWeight.w400,
        ).merge(hintStyle),
      ),
    );
  }
}
