/// All hard-coded pixel values live here.
/// Never scatter magic numbers across widget files.
abstract final class LayoutConstants {
  // Column widths
  static const double draftColumnWidth = 600;
  static const double timeColumnWidth = 500;

  // Spacing
  static const double columnGap = 20;
  static const double pageHPad = 24;
  static const double pageVPad = 16;

  // Column header
  static const double columnHeaderHeight = 56;

  // Cards
  static const double cardPadding = 16;
  static const double cardBorderRadius = 12;
  static const double cardMarginBottom = 12;

  // Draft
  /// Maximum number of simultaneous draft notes.
  static const int maxDraftNotes = 3;

  // Jump-to-today button: appears after scrolling past this offset
  static const double jumpButtonThreshold = draftColumnWidth + columnGap;
}
