import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'package:markdown_field/markdown_field.dart';
import '../providers/search_provider.dart';

/// Compact search bar placed at the top of the Draft column.
///
/// Writes directly to [searchQueryProvider]. An ESC key press or tapping the
/// clear (×) button resets the query and removes focus.
class NoteSearchBar extends ConsumerStatefulWidget {
  const NoteSearchBar({super.key, this.focusRequestToken});

  /// Total height including vertical padding — used by [DraftColumn] to
  /// adjust the available height for the draft card.
  static const double totalHeight = 46.0;

  final int? focusRequestToken;

  @override
  ConsumerState<NoteSearchBar> createState() => _NoteSearchBarState();
}

class _NoteSearchBarState extends ConsumerState<NoteSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _hovered = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode(onKeyEvent: _handleKey)
      ..addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(NoteSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusRequestToken != null &&
        widget.focusRequestToken != oldWidget.focusRequestToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNode.requestFocus();
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _clear();
      node.unfocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _clear() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).clear();
  }

  void _onChanged(String value) {
    // 中文/日文等 IME 输入时，composing 范围有效且非折叠，
    // 此时内容尚未上屏，不应触发搜索（避免用拼音字母搜索）。
    if (_controller.hasActiveComposing) return;
    ref.read(searchQueryProvider.notifier).set(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasQuery = ref.watch(
      searchQueryProvider.select((s) => s.query.isNotEmpty),
    );

    final nc = Theme.of(context).extension<NoteColors>();
    final textPrimary = Theme.of(context).textTheme.bodyMedium?.color;
    final textSecondary = Theme.of(context).textTheme.labelSmall?.color;
    final fillColor = _focused || _hovered
        ? (nc?.controlSurfaceHover ?? nc?.searchBarFill)
        : nc?.searchBarFill;
    final borderColor = _focused
        ? scheme.primary
        : (nc?.searchBarBorder ?? Colors.transparent);
    final shadowColor = (_focused || _hovered)
        ? Colors.black.withValues(alpha: 0.035)
        : Colors.transparent;

    return SizedBox(
      height: NoteSearchBar.totalHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onChanged,
              style: TextStyle(fontSize: 13, color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Search notes…',
                hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: hasQuery || _focused
                        ? scheme.primary
                        : textSecondary,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 34,
                  minHeight: 34,
                ),
                suffixIcon: hasQuery
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        color: textSecondary,
                        tooltip: 'Clear search (ESC)',
                        onPressed: () {
                          _clear();
                          _focusNode.unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: fillColor,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: scheme.primary, width: 1.4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
