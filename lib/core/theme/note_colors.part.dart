part of 'app_theme.dart';

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
  }) => NoteColors(
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
      cardBorderFocused: Color.lerp(
        cardBorderFocused,
        other.cardBorderFocused,
        t,
      )!,
      columnHeader: Color.lerp(columnHeader, other.columnHeader, t)!,
      columnSurface: Color.lerp(columnSurface, other.columnSurface, t)!,
      columnBorder: Color.lerp(columnBorder, other.columnBorder, t)!,
      draftCardBackground: Color.lerp(
        draftCardBackground,
        other.draftCardBackground,
        t,
      )!,
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
      controlSurfaceHover: Color.lerp(
        controlSurfaceHover,
        other.controlSurfaceHover,
        t,
      )!,
    );
  }
}
