import 'package:flutter/material.dart';

/// App-wide theme definitions.
/// Uses Material 3 with a custom indigo seed. Supports light + dark modes.
abstract final class AppTheme {
  static const _seed = Color(0xFF6366F1); // indigo

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      extensions: const [NoteColors.light],
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: const Color(0x1F0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.white,
        foregroundColor: scheme.primary,
        elevation: 0,
        hoverElevation: 0,
        focusElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Color(0xFFFFFFFF)),
          foregroundColor: WidgetStatePropertyAll(scheme.onSurfaceVariant),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: Color(0xFFD9E2EF)),
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.pressed)) {
              return const Color(0x126366F1);
            }
            return null;
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(999),
        thickness: const WidgetStatePropertyAll(8),
        thumbVisibility: const WidgetStatePropertyAll(true),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return const Color(0x7A64748B);
          }
          if (states.contains(WidgetState.hovered)) {
            return const Color(0x6664748B);
          }
          return const Color(0x4464748B);
        }),
      ),
      dividerColor: const Color(0xFFE2E8F0),
      textTheme: _textTheme(Brightness.light),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0B0F18),
      extensions: const [NoteColors.dark],
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Color(0xFF151B29),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF151B29),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF151B29),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: const Color(0x73000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF111827),
        contentTextStyle: const TextStyle(
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFF171D2C),
        foregroundColor: const Color(0xFFC7D2FE),
        elevation: 0,
        hoverElevation: 0,
        focusElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Color(0xFF171D2C)),
          foregroundColor: WidgetStatePropertyAll(scheme.onSurfaceVariant),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: Color(0xFF2B3348)),
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.pressed)) {
              return const Color(0x14818CF8);
            }
            return null;
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(999),
        thickness: const WidgetStatePropertyAll(8),
        thumbVisibility: const WidgetStatePropertyAll(true),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return const Color(0x8894A3B8);
          }
          if (states.contains(WidgetState.hovered)) {
            return const Color(0x6E94A3B8);
          }
          return const Color(0x4C94A3B8);
        }),
      ),
      dividerColor: const Color(0xFF2B3348),
      textTheme: _textTheme(Brightness.dark),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final primary = isLight ? const Color(0xFF172033) : const Color(0xFFE2E8F0);
    final secondary =
        isLight ? const Color(0xFF66758D) : const Color(0xFF95A3BA);
    final tertiary =
        isLight ? const Color(0xFF8A96A8) : const Color(0xFF74839B);
    return TextTheme(
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.62,
        color: primary,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.55,
        color: primary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: tertiary,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
    );
  }
}

/// Semantic color tokens for note cards and columns.
/// Accessed via [Theme.of(context).extension<NoteColors>()].
@immutable
class NoteColors extends ThemeExtension<NoteColors> {
  const NoteColors({
    required this.cardBorder,
    required this.cardBorderHover,
    required this.cardBorderFocused,
    required this.columnHeader,
    required this.columnSurface,
    required this.columnBorder,
    required this.draftCardBackground,
    required this.badgeBackground,
    required this.badgeForeground,
    required this.dotActive,
    required this.dotInactive,
    required this.hoverTint,
    required this.editorText,
    required this.editorHint,
    required this.editorCursor,
    required this.searchBarFill,
    required this.searchBarBorder,
    required this.popoverShadow,
    required this.destructive,
    required this.destructiveSoft,
    required this.controlSurface,
    required this.controlSurfaceHover,
  });

  final Color cardBorder;
  final Color cardBorderHover;
  final Color cardBorderFocused;
  final Color columnHeader;
  final Color columnSurface;
  final Color columnBorder;
  final Color draftCardBackground;
  final Color badgeBackground;
  final Color badgeForeground;
  final Color dotActive;
  final Color dotInactive;
  final Color hoverTint;
  final Color editorText;
  final Color editorHint;
  final Color editorCursor;
  final Color searchBarFill;
  final Color searchBarBorder;
  final Color popoverShadow;
  final Color destructive;
  final Color destructiveSoft;
  final Color controlSurface;
  final Color controlSurfaceHover;

  static const light = NoteColors(
    cardBorder: Color(0xFFDDE4F0),
    cardBorderHover: Color(0xFFC5D0E2),
    cardBorderFocused: Color(0xFF6366F1),
    columnHeader: Color(0xFFF6F8FC),
    columnSurface: Color(0xFFF9FBFE),
    columnBorder: Color(0xFFE3E9F3),
    draftCardBackground: Color(0xFFFBFCFF),
    badgeBackground: Color(0xFFE9EEF9),
    badgeForeground: Color(0xFF516072),
    dotActive: Color(0xFF6366F1),
    dotInactive: Color(0xFFC7D2E4),
    hoverTint: Color(0x0F6366F1),
    editorText: Color(0xFF172033),
    editorHint: Color(0x5C66758D),
    editorCursor: Color(0xFF6366F1),
    searchBarFill: Color(0xFFFFFFFF),
    searchBarBorder: Color(0xFFD9E2EF),
    popoverShadow: Color(0x1F0F172A),
    destructive: Color(0xFFE11D48),
    destructiveSoft: Color(0x14E11D48),
    controlSurface: Color(0xFFFFFFFF),
    controlSurfaceHover: Color(0xFFF6F8FC),
  );

  static const dark = NoteColors(
    cardBorder: Color(0xFF30364C),
    cardBorderHover: Color(0xFF44506C),
    cardBorderFocused: Color(0xFF818CF8),
    columnHeader: Color(0xFF171C2B),
    columnSurface: Color(0xFF111623),
    columnBorder: Color(0xFF252C40),
    draftCardBackground: Color(0xFF151B2A),
    badgeBackground: Color(0xFF232C42),
    badgeForeground: Color(0xFFB7C4D7),
    dotActive: Color(0xFF818CF8),
    dotInactive: Color(0xFF334155),
    hoverTint: Color(0x14818CF8),
    editorText: Color(0xFFE2E8F0),
    editorHint: Color(0x6695A3BA),
    editorCursor: Color(0xFF8B9CFF),
    searchBarFill: Color(0xFF171D2C),
    searchBarBorder: Color(0xFF2B3348),
    popoverShadow: Color(0x73000000),
    destructive: Color(0xFFFB7185),
    destructiveSoft: Color(0x22FB7185),
    controlSurface: Color(0xFF171D2C),
    controlSurfaceHover: Color(0xFF1D2638),
  );

  @override
  NoteColors copyWith({
    Color? cardBorder,
    Color? cardBorderHover,
    Color? cardBorderFocused,
    Color? columnHeader,
    Color? columnSurface,
    Color? columnBorder,
    Color? draftCardBackground,
    Color? badgeBackground,
    Color? badgeForeground,
    Color? dotActive,
    Color? dotInactive,
    Color? hoverTint,
    Color? editorText,
    Color? editorHint,
    Color? editorCursor,
    Color? searchBarFill,
    Color? searchBarBorder,
    Color? popoverShadow,
    Color? destructive,
    Color? destructiveSoft,
    Color? controlSurface,
    Color? controlSurfaceHover,
  }) =>
      NoteColors(
        cardBorder: cardBorder ?? this.cardBorder,
        cardBorderHover: cardBorderHover ?? this.cardBorderHover,
        cardBorderFocused: cardBorderFocused ?? this.cardBorderFocused,
        columnHeader: columnHeader ?? this.columnHeader,
        columnSurface: columnSurface ?? this.columnSurface,
        columnBorder: columnBorder ?? this.columnBorder,
        draftCardBackground: draftCardBackground ?? this.draftCardBackground,
        badgeBackground: badgeBackground ?? this.badgeBackground,
        badgeForeground: badgeForeground ?? this.badgeForeground,
        dotActive: dotActive ?? this.dotActive,
        dotInactive: dotInactive ?? this.dotInactive,
        hoverTint: hoverTint ?? this.hoverTint,
        editorText: editorText ?? this.editorText,
        editorHint: editorHint ?? this.editorHint,
        editorCursor: editorCursor ?? this.editorCursor,
        searchBarFill: searchBarFill ?? this.searchBarFill,
        searchBarBorder: searchBarBorder ?? this.searchBarBorder,
        popoverShadow: popoverShadow ?? this.popoverShadow,
        destructive: destructive ?? this.destructive,
        destructiveSoft: destructiveSoft ?? this.destructiveSoft,
        controlSurface: controlSurface ?? this.controlSurface,
        controlSurfaceHover: controlSurfaceHover ?? this.controlSurfaceHover,
      );

  @override
  NoteColors lerp(NoteColors? other, double t) {
    if (other == null) return this;
    return NoteColors(
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardBorderHover: Color.lerp(cardBorderHover, other.cardBorderHover, t)!,
      cardBorderFocused:
          Color.lerp(cardBorderFocused, other.cardBorderFocused, t)!,
      columnHeader: Color.lerp(columnHeader, other.columnHeader, t)!,
      columnSurface: Color.lerp(columnSurface, other.columnSurface, t)!,
      columnBorder: Color.lerp(columnBorder, other.columnBorder, t)!,
      draftCardBackground:
          Color.lerp(draftCardBackground, other.draftCardBackground, t)!,
      badgeBackground: Color.lerp(badgeBackground, other.badgeBackground, t)!,
      badgeForeground: Color.lerp(badgeForeground, other.badgeForeground, t)!,
      dotActive: Color.lerp(dotActive, other.dotActive, t)!,
      dotInactive: Color.lerp(dotInactive, other.dotInactive, t)!,
      hoverTint: Color.lerp(hoverTint, other.hoverTint, t)!,
      editorText: Color.lerp(editorText, other.editorText, t)!,
      editorHint: Color.lerp(editorHint, other.editorHint, t)!,
      editorCursor: Color.lerp(editorCursor, other.editorCursor, t)!,
      searchBarFill: Color.lerp(searchBarFill, other.searchBarFill, t)!,
      searchBarBorder: Color.lerp(searchBarBorder, other.searchBarBorder, t)!,
      popoverShadow: Color.lerp(popoverShadow, other.popoverShadow, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      destructiveSoft: Color.lerp(destructiveSoft, other.destructiveSoft, t)!,
      controlSurface: Color.lerp(controlSurface, other.controlSurface, t)!,
      controlSurfaceHover:
          Color.lerp(controlSurfaceHover, other.controlSurfaceHover, t)!,
    );
  }
}
