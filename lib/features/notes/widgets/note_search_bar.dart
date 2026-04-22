import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/search_provider.dart';

/// Compact search bar placed at the top of the Draft column.
///
/// Writes directly to [searchQueryProvider]. An ESC key press or tapping the
/// clear (×) button resets the query and removes focus.
class NoteSearchBar extends ConsumerStatefulWidget {
  const NoteSearchBar({super.key});

  /// Total height including vertical padding — used by [DraftColumn] to
  /// adjust the available height for the draft card.
  static const double totalHeight = 52.0;

  @override
  ConsumerState<NoteSearchBar> createState() => _NoteSearchBarState();
}

class _NoteSearchBarState extends ConsumerState<NoteSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode(onKeyEvent: _handleKey);

    // React to Cmd+F focus requests via an event listener.
    ref.listenManual<int>(
      searchQueryProvider.select((s) => s.focusRequest),
      (prev, next) {
        if (prev == null || next == prev) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _focusNode.requestFocus();
          // Select all existing text so the user can immediately replace it.
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
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
    final composing = _controller.value.composing;
    if (composing.isValid && !composing.isCollapsed) return;
    ref.read(searchQueryProvider.notifier).set(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasQuery =
        ref.watch(searchQueryProvider.select((s) => s.query.isNotEmpty));

    final nc = Theme.of(context).extension<NoteColors>();
    final textPrimary = Theme.of(context).textTheme.bodyMedium?.color;
    final textSecondary = Theme.of(context).textTheme.labelSmall?.color;
    final fillColor = nc?.searchBarFill;

    return SizedBox(
      height: NoteSearchBar.totalHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          style: TextStyle(fontSize: 13, color: textPrimary),
          decoration: InputDecoration(
            hintText: 'Search notes…',
            hintStyle: TextStyle(fontSize: 13, color: textSecondary),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 18,
              color: hasQuery ? scheme.primary : textSecondary,
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
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: scheme.primary, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}
