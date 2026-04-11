import 'package:flutter/material.dart';

/// App-wide theme definitions.
/// Uses Material 3 with a custom indigo seed. Supports light + dark modes.
abstract final class AppTheme {
  static const _seed = Color(0xFF6366F1); // indigo

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F2F7),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        textTheme: _textTheme(Brightness.light),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Color(0xFF1E2235),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        textTheme: _textTheme(Brightness.dark),
      );

  static TextTheme _textTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final primary = isLight ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final secondary =
        isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    return TextTheme(
      // Note content
      bodyMedium: TextStyle(fontSize: 14, height: 1.6, color: primary),
      // Timestamps, labels
      labelSmall: TextStyle(fontSize: 11, color: secondary),
      // Column headers
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      // Note count badge
      labelMedium: TextStyle(fontSize: 12, color: secondary),
    );
  }
}

/// Semantic color tokens for note cards and columns.
/// Accessed via [Theme.of(context).extension<NoteColors>()].
@immutable
class NoteColors extends ThemeExtension<NoteColors> {
  const NoteColors({
    required this.cardBorder,
    required this.cardBorderPinned,
    required this.columnHeader,
    required this.draftCardBackground,
    required this.dotActive,
    required this.dotInactive,
    required this.editorText,
    required this.editorHint,
    required this.editorCursor,
    required this.searchBarFill,
  });

  final Color cardBorder;
  final Color cardBorderPinned;
  final Color columnHeader;
  final Color draftCardBackground;
  final Color dotActive;
  final Color dotInactive;
  final Color editorText;
  final Color editorHint;
  final Color editorCursor;
  final Color searchBarFill;

  static const light = NoteColors(
    cardBorder: Color(0xFFE2E8F0),
    cardBorderPinned: Color(0xFF6366F1),
    columnHeader: Color(0xFFEEF0F8),
    draftCardBackground: Color(0xFFF8F9FC),
    dotActive: Color(0xFF6366F1),
    dotInactive: Color(0xFFCBD5E1),
    editorText: Color(0xFF1F2328),
    editorHint: Color(0x42000000), // Colors.black26
    editorCursor: Color(0xFF6366F1), // matches seed
    searchBarFill: Color(0xFFEEF0F8),
  );

  static const dark = NoteColors(
    cardBorder: Color(0xFF2D3148),
    cardBorderPinned: Color(0xFF6366F1),
    columnHeader: Color(0xFF181B2E),
    draftCardBackground: Color(0xFF161929),
    dotActive: Color(0xFF6366F1),
    dotInactive: Color(0xFF334155),
    editorText: Color(0xFFABB2BF),
    editorHint: Color(0x3DFFFFFF), // Colors.white24
    editorCursor: Color(0xFF528BFF),
    searchBarFill: Color(0xFF1E2235),
  );

  @override
  NoteColors copyWith({
    Color? cardBorder,
    Color? cardBorderPinned,
    Color? columnHeader,
    Color? draftCardBackground,
    Color? dotActive,
    Color? dotInactive,
    Color? editorText,
    Color? editorHint,
    Color? editorCursor,
    Color? searchBarFill,
  }) =>
      NoteColors(
        cardBorder: cardBorder ?? this.cardBorder,
        cardBorderPinned: cardBorderPinned ?? this.cardBorderPinned,
        columnHeader: columnHeader ?? this.columnHeader,
        draftCardBackground: draftCardBackground ?? this.draftCardBackground,
        dotActive: dotActive ?? this.dotActive,
        dotInactive: dotInactive ?? this.dotInactive,
        editorText: editorText ?? this.editorText,
        editorHint: editorHint ?? this.editorHint,
        editorCursor: editorCursor ?? this.editorCursor,
        searchBarFill: searchBarFill ?? this.searchBarFill,
      );

  @override
  NoteColors lerp(NoteColors? other, double t) {
    if (other == null) return this;
    return NoteColors(
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardBorderPinned:
          Color.lerp(cardBorderPinned, other.cardBorderPinned, t)!,
      columnHeader: Color.lerp(columnHeader, other.columnHeader, t)!,
      draftCardBackground:
          Color.lerp(draftCardBackground, other.draftCardBackground, t)!,
      dotActive: Color.lerp(dotActive, other.dotActive, t)!,
      dotInactive: Color.lerp(dotInactive, other.dotInactive, t)!,
      editorText: Color.lerp(editorText, other.editorText, t)!,
      editorHint: Color.lerp(editorHint, other.editorHint, t)!,
      editorCursor: Color.lerp(editorCursor, other.editorCursor, t)!,
      searchBarFill: Color.lerp(searchBarFill, other.searchBarFill, t)!,
    );
  }
}
