part of 'markdown_shortcuts.dart';

class _MarkdownLists {
  static final _unorderedPrefixRe = RegExp(r'^(\s*)[-*+]\s');
  static final _orderedPrefixRe = RegExp(r'^(\s*)(\d+)\.\s');

  static (String text, TextSelection selection) toggleUnordered(
    String text,
    TextSelection selection,
  ) {
    return _toggle(text, selection, ordered: false);
  }

  static (String text, TextSelection selection) toggleOrdered(
    String text,
    TextSelection selection,
  ) {
    return _toggle(text, selection, ordered: true);
  }

  static (String, TextSelection) _toggle(
    String text,
    TextSelection selection, {
    required bool ordered,
  }) {
    final lines = text.split('\n');
    final (startLineIdx, endLineIdx) = _MarkdownIndentation._getLineRange(
      text,
      selection,
    );
    final affectedLines = lines.getRange(startLineIdx, endLineIdx + 1).toList();

    final allHaveTargetPrefix = affectedLines.every((line) {
      return ordered
          ? _orderedPrefixRe.hasMatch(line)
          : _unorderedPrefixRe.hasMatch(line);
    });

    final newLines = allHaveTargetPrefix
        ? affectedLines.map((line) => _removeListPrefix(line, ordered)).toList()
        : ordered
        ? _addOrderedPrefixes(affectedLines)
        : affectedLines.map((line) {
            final cleaned = _removeListPrefix(line, null);
            return _addUnorderedPrefix(cleaned);
          }).toList();

    final newAllLines = [...lines];
    for (var i = 0; i < newLines.length; i++) {
      newAllLines[startLineIdx + i] = newLines[i];
    }
    final newText = newAllLines.join('\n');

    return (
      newText,
      TextSelection(
        baseOffset: _MarkdownOffsets.offsetForLine(newText, startLineIdx),
        extentOffset: _MarkdownOffsets.offsetForLineEnd(newText, endLineIdx),
      ),
    );
  }

  static String _removeListPrefix(String line, bool? ordered) {
    if (ordered == true) {
      final match = _orderedPrefixRe.firstMatch(line);
      if (match == null) return line;
      return line.substring(0, match.start) +
          match.group(1)! +
          line.substring(match.end);
    }
    if (ordered == false) {
      final match = _unorderedPrefixRe.firstMatch(line);
      if (match == null) return line;
      return line.substring(0, match.start) +
          match.group(1)! +
          line.substring(match.end);
    }

    var result = line;
    var match = _unorderedPrefixRe.firstMatch(result);
    if (match != null) {
      result =
          result.substring(0, match.start) +
          match.group(1)! +
          result.substring(match.end);
    }
    match = _orderedPrefixRe.firstMatch(result);
    if (match != null) {
      result =
          result.substring(0, match.start) +
          match.group(1)! +
          result.substring(match.end);
    }
    return result;
  }

  static String _addUnorderedPrefix(String line) {
    if (_unorderedPrefixRe.hasMatch(line)) return line;
    final indentMatch = RegExp(r'^(\s*)').firstMatch(line);
    final indent = indentMatch?.group(1) ?? '';
    final content = line.substring(indent.length);
    if (content.isEmpty) return line;
    return '$indent- $content';
  }

  static List<String> _addOrderedPrefixes(List<String> lines) {
    var counter = 1;
    return lines.map((line) {
      final cleaned = _removeListPrefix(line, null);
      final indentMatch = RegExp(r'^(\s*)').firstMatch(cleaned);
      final indent = indentMatch?.group(1) ?? '';
      final content = cleaned.substring(indent.length);
      if (content.isEmpty) return line;
      final result = '$indent$counter. $content';
      counter++;
      return result;
    }).toList();
  }
}
