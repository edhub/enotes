import 'package:flutter/material.dart';

/// Handles Bear-style markdown shortcuts for a text editor.
///
/// Supported shortcuts:
/// - `Cmd+B`: Toggle bold (`*`) around selection
/// - `Cmd+L`: Toggle unordered list (`- `) on selected lines
/// - `Shift+Cmd+L`: Toggle ordered list (`1. `, `2. `…) on selected lines
///
/// Unordered and ordered lists are mutually exclusive.
class MarkdownShortcuts {
  MarkdownShortcuts._();

  /// Toggles bold formatting (`*...*`) around the current selection.
  ///
  /// - Cursor/selection completely inside an existing `*...*`: removes the markers.
  /// - Collapsed cursor outside bold: inserts `**` with cursor positioned between them.
  /// - Selection outside bold: wraps with `*...*`; selection shifts to inner content.
  static (String text, TextSelection selection) toggleBold(
    String text,
    TextSelection selection,
  ) {
    // If cursor or selection is completely inside an existing *...* span, remove it.
    final enclosing = _findEnclosingBold(text, selection.start, selection.end);
    if (enclosing != null) {
      final (openPos, closePos) = enclosing;
      // Remove higher-index marker first to preserve the lower-index position.
      final newText = text.substring(0, openPos) +
          text.substring(openPos + 1, closePos) +
          text.substring(closePos + 1);
      // Shift selection left by 1 (the removed opening *).
      final newStart = (selection.start - 1).clamp(0, newText.length);
      final newEnd = (selection.end - 1).clamp(0, newText.length);
      return (
        newText,
        selection.isCollapsed
            ? TextSelection.collapsed(offset: newStart)
            : TextSelection(baseOffset: newStart, extentOffset: newEnd),
      );
    }

    if (selection.isCollapsed) {
      // No selection: insert ** at cursor; cursor lands between the two *.
      final pos = selection.extentOffset;
      final newText = '${text.substring(0, pos)}**${text.substring(pos)}';
      return (newText, TextSelection.collapsed(offset: pos + 1));
    }

    // Wrap selection with *...*.
    final start = selection.start;
    final end = selection.end;
    final inner = text.substring(start, end);
    final newText = '${text.substring(0, start)}*$inner*${text.substring(end)}';
    // Selection covers the inner content (between the markers).
    return (
      newText,
      TextSelection(baseOffset: start + 1, extentOffset: end + 1),
    );
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
  static (int, int)? _findEnclosingBold(String text, int selStart, int selEnd) {
    for (final match in _boldRe.allMatches(text)) {
      final innerStart = match.start + 1; // first content char (after opening *)
      final innerEnd = match.end - 1;     // position of closing *
      if (selStart >= innerStart && selEnd <= innerEnd) {
        return (match.start, match.end - 1);
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