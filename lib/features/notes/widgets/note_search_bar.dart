import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Shadow of the last seen [SearchState.focusRequest] value.
  int _lastFocusRequest = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode(onKeyEvent: _handleKey);
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
    ref.read(searchQueryProvider.notifier).set(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(searchQueryProvider);
    final hasQuery = state.query.isNotEmpty;

    // Detect Cmd+F focus request and grab focus.
    if (state.focusRequest > 0 && state.focusRequest != _lastFocusRequest) {
      _lastFocusRequest = state.focusRequest;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNode.requestFocus();
        // Select all existing text so the user can immediately replace it.
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      });
    }

    final fillColor = isDark
        ? const Color(0xFF1E2235)
        : const Color(0xFFEEF0F8);

    return SizedBox(
      height: NoteSearchBar.totalHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: 'Search notes…',
            hintStyle: TextStyle(
              fontSize: 13,
              color:
                  isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 18,
              color: hasQuery
                  ? scheme.primary
                  : (isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8)),
            ),
            suffixIcon: hasQuery
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
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
