import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Handles Bear-style markdown shortcuts for a text editor.
///
/// Supported shortcuts:
/// - `Tab` / `Shift+Tab`: Indent / outdent by 2 spaces at each affected line
///   start (current line when the caret is collapsed)
/// - `Cmd+B`: Toggle bold (`*`) around selection
/// - `Cmd+L`: Toggle unordered list (`- `) on selected lines
/// - `Shift+Cmd+L`: Toggle ordered list (`1. `, `2. `…) on selected lines
///
/// Unordered and ordered lists are mutually exclusive.
class MarkdownShortcuts {
  MarkdownShortcuts._();

  /// Handles keyboard shortcuts for a Markdown editor.
  ///
  /// Processes ESC (unfocus), Enter (list/quote continuation), Tab (line
  /// indent), Shift+Tab (line outdent), Cmd+B (bold), Cmd+L (unordered list),
  /// Shift+Cmd+L (ordered list). Returns
  /// [KeyEventResult.handled] if a shortcut was matched, otherwise
  /// [KeyEventResult.ignored].
  ///
  /// [onApply] is called after a text-modifying shortcut is applied
  /// (e.g. to trigger a save).
  static KeyEventResult handleKeyEvent({
    required KeyEvent event,
    required FocusNode node,
    required TextEditingController controller,
    VoidCallback? onApply,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // ESC → unfocus
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      node.unfocus();
      return KeyEventResult.handled;
    }

    // Enter → list / quote auto-continuation
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      // Bail on IME composing — pressing Enter to commit a candidate must
      // never be intercepted as a list-continuation gesture.
      if (controller.value.composing.isValid &&
          !controller.value.composing.isCollapsed) {
        return KeyEventResult.ignored;
      }
      if (applyEnterContinuation(controller)) {
        onApply?.call();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (controller.value.composing.isValid &&
          !controller.value.composing.isCollapsed) {
        return KeyEventResult.ignored;
      }
      final isShift =
          HardwareKeyboard.instance.isLogicalKeyPressed(
                LogicalKeyboardKey.shiftLeft,
              ) ||
              HardwareKeyboard.instance.isLogicalKeyPressed(
                LogicalKeyboardKey.shiftRight,
              );
      final (newText, newSel) = isShift
          ? applyOutdent(controller.text, controller.selection)
          : applyIndent(controller.text, controller.selection);
      final maxO = newText.length;
      final safeSel = TextSelection(
        baseOffset: newSel.baseOffset.clamp(0, maxO),
        extentOffset: newSel.extentOffset.clamp(0, maxO),
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

    final isCmd =
        HardwareKeyboard.instance.isLogicalKeyPressed(
              LogicalKeyboardKey.metaLeft,
            ) ||
            HardwareKeyboard.instance.isLogicalKeyPressed(
              LogicalKeyboardKey.metaRight,
            );
    if (!isCmd) return KeyEventResult.ignored;

    final isShift =
        HardwareKeyboard.instance.isLogicalKeyPressed(
              LogicalKeyboardKey.shiftLeft,
            ) ||
            HardwareKeyboard.instance.isLogicalKeyPressed(
              LogicalKeyboardKey.shiftRight,
            );

    final shortcut = switch (event.logicalKey) {
      LogicalKeyboardKey.keyB => toggleBold,
      LogicalKeyboardKey.keyL when !isShift => toggleUnorderedList,
      LogicalKeyboardKey.keyL when isShift => toggleOrderedList,
      _ => null,
    };
    if (shortcut == null) return KeyEventResult.ignored;

    applyShortcut(controller: controller, shortcut: shortcut);
    onApply?.call();
    return KeyEventResult.handled;
  }

  // ── Enter continuation ─────────────────────────────────────────────────────

  static final _continuationUnorderedRe =
      RegExp(r'^(\s*)([-*+])(\s+)(.*)$');
  static final _continuationOrderedRe =
      RegExp(r'^(\s*)(\d+)\.(\s+)(.*)$');
  static final _continuationQuoteRe = RegExp(r'^(\s*)(>+)(\s+)(.*)$');

  /// If the caret sits on a line that starts with a list bullet, numbered
  /// prefix, or `>` quote marker, replicates that prefix on the next line.
  /// Pressing Enter on an *empty* such line removes the prefix instead
  /// (terminating the list / quote), matching the convention of every
  /// modern markdown editor.
  ///
  /// Returns `true` if the controller was modified; `false` to defer to
  /// the platform's default Enter behaviour.
  ///
  /// Public for unit testing — production code should go through
  /// [handleKeyEvent].
  static bool applyEnterContinuation(TextEditingController controller) {
    final sel = controller.selection;
    if (!sel.isCollapsed) return false;

    final text = controller.text;
    final caret = sel.start;

    // Find the bounds of the current line.
    final lineStart = text.lastIndexOf('\n', caret - 1) + 1;
    int lineEnd = text.indexOf('\n', caret);
    if (lineEnd == -1) lineEnd = text.length;
    final line = text.substring(lineStart, lineEnd);

    // Match the line against the three continuation patterns.
    final ulMatch = _continuationUnorderedRe.firstMatch(line);
    final olMatch = _continuationOrderedRe.firstMatch(line);
    final qMatch = _continuationQuoteRe.firstMatch(line);
    final match = ulMatch ?? olMatch ?? qMatch;
    if (match == null) return false;

    final indent = match.group(1)!;
    final marker = match.group(2)!;
    final spacing = match.group(3)!;
    final content = match.group(4)!;

    // Empty content → terminate: replace the whole line with just its indent.
    if (content.isEmpty) {
      final newText =
          '${text.substring(0, lineStart)}$indent${text.substring(lineEnd)}';
      controller.value = controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart + indent.length),
      );
      return true;
    }

    // Non-empty content → continue: insert "\n<indent><nextMarker><spacing>".
    final String nextMarker;
    if (olMatch != null) {
      final n = int.tryParse(marker) ?? 1;
      nextMarker = '${n + 1}.';
    } else {
      nextMarker = marker;
    }
    final insertion = '\n$indent$nextMarker$spacing';
    final newText =
        '${text.substring(0, caret)}$insertion${text.substring(caret)}';
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: caret + insertion.length),
    );
    return true;
  }

  // ── Tab indent / Shift+Tab outdent (2 spaces) ─────────────────────────────

  static const String _indentStep = '  ';

  /// Indents every line in the current line range by adding two spaces at
  /// each line start (including the line of a collapsed caret).
  ///
  /// Public for unit testing — production code should go through
  /// [handleKeyEvent].
  static (String text, TextSelection selection) applyIndent(
    String text,
    TextSelection selection,
  ) {
    final (startLine, endLine) = _getLineRange(text, selection);

    final lines = text.split('\n');
    for (var i = startLine; i <= endLine; i++) {
      lines[i] = '$_indentStep${lines[i]}';
    }
    final newText = lines.join('\n');
    return (
      newText,
      TextSelection(
        baseOffset: _mapOffsetAfterBlockIndent(text, selection.baseOffset, startLine),
        extentOffset:
            _mapOffsetAfterBlockIndent(text, selection.extentOffset, startLine),
      ),
    );
  }

  /// Removes up to two leading spaces (or one tab) from each line in the
  /// current line range.
  ///
  /// Public for unit testing — production code should go through
  /// [handleKeyEvent].
  static (String text, TextSelection selection) applyOutdent(
    String text,
    TextSelection selection,
  ) {
    final (startLine, endLine) = _getLineRange(text, selection);
    final lines = text.split('\n');
    final removedPerLine = List<int>.filled(lines.length, 0);
    for (var i = startLine; i <= endLine; i++) {
      final (newLine, removed) = _outdentLinePrefix(lines[i]);
      lines[i] = newLine;
      removedPerLine[i] = removed;
    }
    final newText = lines.join('\n');
    return (
      newText,
      TextSelection(
        baseOffset: _mapOffsetAfterOutdent(
          text,
          selection.baseOffset,
          startLine,
          endLine,
          removedPerLine,
        ),
        extentOffset: _mapOffsetAfterOutdent(
          text,
          selection.extentOffset,
          startLine,
          endLine,
          removedPerLine,
        ),
      ),
    );
  }

  static int _lineIndexAtOffset(String text, int offset) {
    var line = 0;
    final n = offset.clamp(0, text.length);
    for (var i = 0; i < n; i++) {
      if (text[i] == '\n') line++;
    }
    return line;
  }

  static int _mapOffsetAfterBlockIndent(
    String oldText,
    int offset,
    int startLine,
  ) {
    final line = _lineIndexAtOffset(oldText, offset);
    if (line < startLine) return offset;
    return offset + _indentStep.length * (line - startLine + 1);
  }

  static (String line, int removedChars) _outdentLinePrefix(String line) {
    if (line.startsWith('\t')) {
      return (line.substring(1), 1);
    }
    var i = 0;
    while (i < line.length && i < 2 && line[i] == ' ') {
      i++;
    }
    return (line.substring(i), i);
  }

  static int _mapOffsetAfterOutdent(
    String oldText,
    int offset,
    int startLine,
    int endLine,
    List<int> removedPerLine,
  ) {
    final line = _lineIndexAtOffset(oldText, offset);
    final lineStart = _getOffsetForLine(oldText, line);
    final col = offset - lineStart;

    var deltaBefore = 0;
    for (var i = startLine; i <= endLine && i < line; i++) {
      deltaBefore -= removedPerLine[i];
    }

    if (line < startLine || line > endLine) {
      return offset + deltaBefore;
    }

    final removedHere = removedPerLine[line];
    final newCol = col <= removedHere ? 0 : col - removedHere;
    final newLineStart = lineStart + deltaBefore;
    return newLineStart + newCol;
  }

  /// Applies a Markdown [shortcut] transformation to [controller]'s
  /// current text and selection.
  static void applyShortcut({
    required TextEditingController controller,
    required (String, TextSelection) Function(String, TextSelection) shortcut,
  }) {
    final (newText, newSel) = shortcut(
      controller.text,
      controller.selection,
    );
    controller.value = controller.value.copyWith(
      text: newText,
      selection: newSel,
    );
  }

  /// Toggles bold formatting (`*...*`) around the current selection.
  ///
  /// - Cursor/selection completely inside an existing `*...*`: removes the markers.
  /// - Collapsed cursor outside bold: inserts `**` with cursor positioned between them.
  /// - Single-line selection: wraps with `*...*`.
  /// - Multi-line selection: wraps each line's selected portion with `*...*`.
  static (String text, TextSelection selection) toggleBold(
    String text,
    TextSelection selection,
  ) {
    // Handle collapsed cursor first
    if (selection.isCollapsed) {
      // Check if cursor is inside an existing *...* span or empty **
      final enclosing = _findEnclosingBold(text, selection.start, selection.end);
      if (enclosing != null) {
        final (openPos, closePos) = enclosing;
        final newText = text.substring(0, openPos) +
            text.substring(openPos + 1, closePos) +
            text.substring(closePos + 1);
        final newOffset = (selection.start - 1).clamp(0, newText.length);
        return (newText, TextSelection.collapsed(offset: newOffset));
      }
      // Insert ** at cursor; cursor lands between the two *
      final pos = selection.extentOffset;
      final newText = '${text.substring(0, pos)}**${text.substring(pos)}';
      return (newText, TextSelection.collapsed(offset: pos + 1));
    }

    // Check if selection spans multiple lines
    final selectedText = text.substring(selection.start, selection.end);
    final hasMultipleLines = selectedText.contains('\n');

    if (!hasMultipleLines) {
      // Single-line selection: check if inside existing bold, then wrap/remove
      final enclosing = _findEnclosingBold(text, selection.start, selection.end);
      if (enclosing != null) {
        final (openPos, closePos) = enclosing;
        final newText = text.substring(0, openPos) +
            text.substring(openPos + 1, closePos) +
            text.substring(closePos + 1);
        final newStart = (selection.start - 1).clamp(0, newText.length);
        final newEnd = (selection.end - 1).clamp(0, newText.length);
        return (
          newText,
          TextSelection(baseOffset: newStart, extentOffset: newEnd),
        );
      }
      // Wrap single-line selection with *...*
      final start = selection.start;
      final end = selection.end;
      final inner = text.substring(start, end);
      final newText = '${text.substring(0, start)}*$inner*${text.substring(end)}';
      return (
        newText,
        TextSelection(baseOffset: start + 1, extentOffset: end + 1),
      );
    }

    // Multi-line selection: wrap each line separately
    return _toggleBoldMultiline(text, selection);
  }

  /// Toggles bold for multi-line selections, wrapping each line's selected portion.
  static (String, TextSelection) _toggleBoldMultiline(
    String text,
    TextSelection selection,
  ) {
    final lines = text.split('\n');
    final (startLineIdx, startOffsetInLine) = _getLineAndOffset(text, selection.start);
    final (endLineIdx, endOffsetInLine) = _getLineAndOffset(text, selection.end);

    // Build new text with each line's selected portion wrapped
    final newLines = <String>[];
    var offsetAdjustment = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i < startLineIdx || i > endLineIdx) {
        // Line not in selection range
        newLines.add(line);
        continue;
      }

      // Calculate the portion of this line to wrap
      int lineStart = (i == startLineIdx) ? startOffsetInLine : 0;
      int lineEnd = (i == endLineIdx) ? endOffsetInLine : line.length;

      // Skip if nothing selected on this line
      if (lineStart >= lineEnd) {
        newLines.add(line);
        continue;
      }

      // Wrap the selected portion
      final before = line.substring(0, lineStart);
      final selected = line.substring(lineStart, lineEnd);
      final after = line.substring(lineEnd);
      newLines.add('$before*$selected*$after');

      // Track adjustment for selection (each wrapped line adds 2 characters)
      if (i == startLineIdx) {
        offsetAdjustment += 1; // opening * before selection start
      }
      // For end line, we'll add the closing * adjustment later
    }

    final newText = newLines.join('\n');

    // Calculate new selection: cover all the newly bolded content
    final newStart = selection.start + offsetAdjustment;
    final newEnd = selection.end + (endLineIdx - startLineIdx + 1) * 2 - offsetAdjustment;

    return (
      newText,
      TextSelection(baseOffset: newStart, extentOffset: newEnd.clamp(newStart, newText.length)),
    );
  }

  /// Returns the (lineIndex, offsetInLine) for a given absolute offset.
  static (int, int) _getLineAndOffset(String text, int offset) {
    var lineIdx = 0;
    var lineStart = 0;
    for (var i = 0; i < offset && i < text.length; i++) {
      if (text[i] == '\n') {
        lineIdx++;
        lineStart = i + 1;
      }
    }
    return (lineIdx, offset - lineStart);
  }

  /// Toggles unordered list formatting on selected lines.
  ///
  /// - All selected lines are unordered lists: removes `- ` prefix
  /// - Otherwise: adds `- ` prefix (removes ordered list prefix first)
  static (String text, TextSelection selection) toggleUnorderedList(
    String text,
    TextSelection selection,
  ) {
    return _toggleList(text, selection, ordered: false);
  }

  /// Toggles ordered list formatting on selected lines.
  ///
  /// - All selected lines are ordered lists: removes `N. ` prefix
  /// - Otherwise: adds numbered prefixes (removes unordered prefix first)
  static (String text, TextSelection selection) toggleOrderedList(
    String text,
    TextSelection selection,
  ) {
    return _toggleList(text, selection, ordered: true);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static final _boldRe = RegExp(r'\*([^*]+)\*');

  /// Returns the (openPos, closePos) of the `*...*` span whose inner content
  /// completely contains [selStart, selEnd], or null if no such span exists.
  /// [openPos] and [closePos] are the character positions of the `*` markers.
  ///
  /// Also handles the empty bold case `**` (cursor between two consecutive `*`).
  static (int, int)? _findEnclosingBold(String text, int selStart, int selEnd) {
    for (final match in _boldRe.allMatches(text)) {
      final innerStart = match.start + 1; // first content char (after opening *)
      final innerEnd = match.end - 1;     // position of closing *
      if (selStart >= innerStart && selEnd <= innerEnd) {
        return (match.start, match.end - 1);
      }
    }
    // Check for empty bold `**` with cursor between two consecutive `*`
    // This is the case where user pressed cmd+b once and got `**`, now pressing again should remove it.
    // We check: cursor position pos, text[pos-1] == '*' and text[pos] == '*'
    if (selStart == selEnd && selStart > 0 && selStart < text.length) {
      if (text[selStart - 1] == '*' && text[selStart] == '*') {
        // Cursor is between two consecutive `*`, return positions of both `*`
        return (selStart - 1, selStart);
      }
    }
    return null;
  }

  static final _unorderedPrefixRe = RegExp(r'^(\s*)[-*+]\s');
  static final _orderedPrefixRe = RegExp(r'^(\s*)(\d+)\.\s');

  static (String, TextSelection) _toggleList(
    String text,
    TextSelection selection,
    {required bool ordered}
  ) {
    // Get line range for selection
    final lines = text.split('\n');
    final (startLineIdx, endLineIdx) = _getLineRange(text, selection);
    
    // Collect all affected lines
    final affectedLines = lines.getRange(startLineIdx, endLineIdx + 1).toList();
    
    // Determine current state
    final allHaveTargetPrefix = affectedLines.every((line) {
      if (ordered) {
        return _orderedPrefixRe.hasMatch(line);
      } else {
        return _unorderedPrefixRe.hasMatch(line);
      }
    });

    List<String> newLines;
    if (allHaveTargetPrefix) {
      // Remove the target prefix
      newLines = affectedLines.map((line) => _removeListPrefix(line, ordered)).toList();
    } else {
      // Add target prefix (remove opposite prefix first if present)
      if (ordered) {
        newLines = _addOrderedPrefixes(affectedLines);
      } else {
        newLines = affectedLines.map((line) {
          final cleaned = _removeListPrefix(line, null); // remove any list prefix
          return _addUnorderedPrefix(cleaned);
        }).toList();
      }
    }

    // Rebuild text
    final newAllLines = [...lines];
    for (var i = 0; i < newLines.length; i++) {
      newAllLines[startLineIdx + i] = newLines[i];
    }
    final newText = newAllLines.join('\n');

    // Adjust selection to cover all affected lines
    final newStartOffset = _getOffsetForLine(newText, startLineIdx);
    final newEndOffset = _getOffsetForLineEnd(newText, endLineIdx);

    return (
      newText,
      TextSelection(baseOffset: newStartOffset, extentOffset: newEndOffset),
    );
  }

  /// Returns the (startLineIndex, endLineIndex) for the current selection.
  static (int, int) _getLineRange(String text, TextSelection selection) {
    final start = selection.start;
    final end = selection.end;

    int startLine = 0;
    int endLine = 0;
    int offset = 0;

    for (var i = 0; i < text.length; i++) {
      if (i == start) startLine = offset;
      if (i == end) endLine = offset;
      if (text[i] == '\n') offset++;
    }
    
    // Handle selection at end of text
    if (start == text.length) startLine = offset;
    if (end == text.length) endLine = offset;

    return (startLine, endLine);
  }

  /// Removes list prefix from a line.
  /// If [ordered] is true, removes ordered prefix; otherwise removes unordered.
  /// If [ordered] is null, removes any list prefix.
  static String _removeListPrefix(String line, bool? ordered) {
    if (ordered == true) {
      final match = _orderedPrefixRe.firstMatch(line);
      if (match != null) {
        return line.substring(0, match.start) + match.group(1)! + line.substring(match.end);
      }
      return line;
    } else if (ordered == false) {
      final match = _unorderedPrefixRe.firstMatch(line);
      if (match != null) {
        return line.substring(0, match.start) + match.group(1)! + line.substring(match.end);
      }
      return line;
    } else {
      // Remove any list prefix
      var result = line;
      var match = _unorderedPrefixRe.firstMatch(result);
      if (match != null) {
        result = result.substring(0, match.start) + match.group(1)! + result.substring(match.end);
      }
      match = _orderedPrefixRe.firstMatch(result);
      if (match != null) {
        result = result.substring(0, match.start) + match.group(1)! + result.substring(match.end);
      }
      return result;
    }
  }

  /// Adds unordered list prefix to a line.
  static String _addUnorderedPrefix(String line) {
    final match = _unorderedPrefixRe.firstMatch(line);
    if (match != null) return line; // already has prefix
    
    final indentMatch = RegExp(r'^(\s*)').firstMatch(line);
    final indent = indentMatch?.group(1) ?? '';
    final content = line.substring(indent.length);
    if (content.isEmpty) return line; // don't prefix empty lines
    return '$indent- $content';
  }

  /// Adds ordered list prefixes to lines (1., 2., 3.…).
  static List<String> _addOrderedPrefixes(List<String> lines) {
    var counter = 1;
    return lines.map((line) {
      // Remove any existing list prefix
      var cleaned = _removeListPrefix(line, null);
      
      final indentMatch = RegExp(r'^(\s*)').firstMatch(cleaned);
      final indent = indentMatch?.group(1) ?? '';
      final content = cleaned.substring(indent.length);
      
      if (content.isEmpty) return line; // don't prefix empty lines
      
      final result = '$indent$counter. $content';
      counter++;
      return result;
    }).toList();
  }

  /// Returns the character offset for the start of [lineIndex].
  static int _getOffsetForLine(String text, int lineIndex) {
    var offset = 0;
    var currentLine = 0;
    for (var i = 0; i < text.length && currentLine < lineIndex; i++) {
      if (text[i] == '\n') {
        currentLine++;
        offset = i + 1;
      }
    }
    return offset;
  }

  /// Returns the character offset for the end of [lineIndex] (inclusive of line content, exclusive of newline).
  static int _getOffsetForLineEnd(String text, int lineIndex) {
    var currentLine = 0;
    for (var i = 0; i < text.length; i++) {
      if (currentLine == lineIndex && text[i] == '\n') {
        return i;
      }
      if (text[i] == '\n') {
        currentLine++;
      }
    }
    return text.length;
  }
}