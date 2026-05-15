/// All hard-coded pixel values live here.
/// Never scatter magic numbers across widget files.
abstract final class LayoutConstants {
  // Column widths
  static const double draftColumnWidth = 450;
  static const double timeColumnWidth = 392;
  static const double trashColumnWidth = 368;

  // Spacing
  static const double columnGap = 10;
  static const double pageHPad = 8;
  static const double pageVPad = 14;

  // Column header
  static const double columnHeaderHeight = 54;

  // Cards
  static const double cardPadding = 12;
  static const double cardBorderRadius = 14;
  static const double cardMarginBottom = 14;

  /// Number of permanent draft slots (always present, like tabs).
  static const int maxDraftNotes = 5;

  // Jump-to-today button: appears after scrolling past this offset
  static const double jumpButtonThreshold = draftColumnWidth + columnGap;

  /// Extra scroll extent below the last item so it can be scrolled to roughly
  /// the vertical center of the column body (non-draft columns).
  static double columnBottomReadingGap(double columnBodyHeight) =>
      columnBodyHeight * 0.5;
}
