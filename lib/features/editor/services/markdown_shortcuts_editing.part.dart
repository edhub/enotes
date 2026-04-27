part of 'markdown_shortcuts.dart';

class _MarkdownContinuation {
  static final _unorderedRe = RegExp(r'^(\s*)([-*+])(\s+)(.*)$');
  static final _orderedRe = RegExp(r'^(\s*)(\d+)\.(\s+)(.*)$');
  static final _quoteRe = RegExp(r'^(\s*)(>+)(\s+)(.*)$');

  static bool apply(TextEditingController controller) {
    final sel = controller.selection;
    if (!sel.isCollapsed) return false;

    final text = controller.text;
    final caret = sel.start;
    final lineStart = text.lastIndexOf('\n', caret - 1) + 1;
    int lineEnd = text.indexOf('\n', caret);
    if (lineEnd == -1) lineEnd = text.length;
    final line = text.substring(lineStart, lineEnd);

    final ulMatch = _unorderedRe.firstMatch(line);
    final olMatch = _orderedRe.firstMatch(line);
    final qMatch = _quoteRe.firstMatch(line);
    final match = ulMatch ?? olMatch ?? qMatch;
    if (match == null) return false;

    final indent = match.group(1)!;
    final marker = match.group(2)!;
    final spacing = match.group(3)!;
    final content = match.group(4)!;

    if (content.isEmpty) {
      final newText =
          '${text.substring(0, lineStart)}$indent${text.substring(lineEnd)}';
      controller.value = controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart + indent.length),
      );
      return true;
    }

    final nextMarker = olMatch != null
        ? '${(int.tryParse(marker) ?? 1) + 1}.'
        : marker;
    final insertion = '\n$indent$nextMarker$spacing';
    final newText =
        '${text.substring(0, caret)}$insertion${text.substring(caret)}';
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: caret + insertion.length),
    );
    return true;
  }
}

class _MarkdownIndentation {
  static const String indentStep = '  ';

  static (String text, TextSelection selection) applyIndent(
    String text,
    TextSelection selection,
  ) {
    final (startLine, endLine) = _getLineRange(text, selection);
    final lines = text.split('\n');
    for (var i = startLine; i <= endLine; i++) {
      lines[i] = '$indentStep${lines[i]}';
    }
    final newText = lines.join('\n');
    return (
      newText,
      TextSelection(
        baseOffset: _mapOffsetAfterBlockIndent(
          text,
          selection.baseOffset,
          startLine,
        ),
        extentOffset: _mapOffsetAfterBlockIndent(
          text,
          selection.extentOffset,
          startLine,
        ),
      ),
    );
  }

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
    return offset + indentStep.length * (line - startLine + 1);
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
    final lineStart = _MarkdownOffsets.offsetForLine(oldText, line);
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

    if (start == text.length) startLine = offset;
    if (end == text.length) endLine = offset;

    return (startLine, endLine);
  }
}

class _MarkdownBolding {
  static final _boldRe = RegExp(r'\*([^*]+)\*');

  static (String text, TextSelection selection) toggle(
    String text,
    TextSelection selection,
  ) {
    if (selection.isCollapsed) {
      final enclosing = _findEnclosingBold(
        text,
        selection.start,
        selection.end,
      );
      if (enclosing != null) {
        final (openPos, closePos) = enclosing;
        final newText =
            text.substring(0, openPos) +
            text.substring(openPos + 1, closePos) +
            text.substring(closePos + 1);
        final newOffset = (selection.start - 1).clamp(0, newText.length);
        return (newText, TextSelection.collapsed(offset: newOffset));
      }
      final pos = selection.extentOffset;
      final newText = '${text.substring(0, pos)}**${text.substring(pos)}';
      return (newText, TextSelection.collapsed(offset: pos + 1));
    }

    final selectedText = text.substring(selection.start, selection.end);
    if (!selectedText.contains('\n')) {
      final enclosing = _findEnclosingBold(
        text,
        selection.start,
        selection.end,
      );
      if (enclosing != null) {
        final (openPos, closePos) = enclosing;
        final newText =
            text.substring(0, openPos) +
            text.substring(openPos + 1, closePos) +
            text.substring(closePos + 1);
        final newStart = (selection.start - 1).clamp(0, newText.length);
        final newEnd = (selection.end - 1).clamp(0, newText.length);
        return (
          newText,
          TextSelection(baseOffset: newStart, extentOffset: newEnd),
        );
      }
      final start = selection.start;
      final end = selection.end;
      final inner = text.substring(start, end);
      final newText =
          '${text.substring(0, start)}*$inner*${text.substring(end)}';
      return (
        newText,
        TextSelection(baseOffset: start + 1, extentOffset: end + 1),
      );
    }

    return _toggleMultiline(text, selection);
  }

  static (String, TextSelection) _toggleMultiline(
    String text,
    TextSelection selection,
  ) {
    final lines = text.split('\n');
    final (startLineIdx, startOffsetInLine) = _getLineAndOffset(
      text,
      selection.start,
    );
    final (endLineIdx, endOffsetInLine) = _getLineAndOffset(
      text,
      selection.end,
    );

    final newLines = <String>[];
    var offsetAdjustment = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i < startLineIdx || i > endLineIdx) {
        newLines.add(line);
        continue;
      }

      final lineStart = i == startLineIdx ? startOffsetInLine : 0;
      final lineEnd = i == endLineIdx ? endOffsetInLine : line.length;
      if (lineStart >= lineEnd) {
        newLines.add(line);
        continue;
      }

      final before = line.substring(0, lineStart);
      final selected = line.substring(lineStart, lineEnd);
      final after = line.substring(lineEnd);
      newLines.add('$before*$selected*$after');

      if (i == startLineIdx) {
        offsetAdjustment += 1;
      }
    }

    final newText = newLines.join('\n');
    final newStart = selection.start + offsetAdjustment;
    final newEnd =
        selection.end + (endLineIdx - startLineIdx + 1) * 2 - offsetAdjustment;

    return (
      newText,
      TextSelection(
        baseOffset: newStart,
        extentOffset: newEnd.clamp(newStart, newText.length),
      ),
    );
  }

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

  static (int, int)? _findEnclosingBold(String text, int selStart, int selEnd) {
    for (final match in _boldRe.allMatches(text)) {
      final innerStart = match.start + 1;
      final innerEnd = match.end - 1;
      if (selStart >= innerStart && selEnd <= innerEnd) {
        return (match.start, match.end - 1);
      }
    }
    if (selStart == selEnd && selStart > 0 && selStart < text.length) {
      if (text[selStart - 1] == '*' && text[selStart] == '*') {
        return (selStart - 1, selStart);
      }
    }
    return null;
  }
}

class _MarkdownOffsets {
  static int offsetForLine(String text, int lineIndex) {
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

  static int offsetForLineEnd(String text, int lineIndex) {
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
