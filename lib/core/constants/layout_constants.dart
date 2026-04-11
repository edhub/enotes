/// All hard-coded pixel values live here.
/// Never scatter magic numbers across widget files.
abstract final class LayoutConstants {
  // Column widths
  static const double draftColumnWidth = 450;
  static const double timeColumnWidth = 380;
  static const double trashColumnWidth = 380;

  // Spacing
  static const double columnGap = 8;
  static const double pageHPad = 4;
  static const double pageVPad = 16;

  // Column header
  static const double columnHeaderHeight = 56;

  // Cards
  static const double cardPadding = 12;
  static const double cardBorderRadius = 12;
  static const double cardMarginBottom = 16;

  /// Number of permanent draft slots (always present, like tabs).
  static const int maxDraftNotes = 5;

  // Jump-to-today button: appears after scrolling past this offset
  static const double jumpButtonThreshold = draftColumnWidth + columnGap;
}
