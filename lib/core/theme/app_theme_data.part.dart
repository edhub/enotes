part of 'app_theme.dart';

ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppTheme._seed,
    brightness: brightness,
  );
  final isLight = brightness == Brightness.light;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: isLight
        ? const Color(0xFFF5F7FB)
        : const Color(0xFF0B0F18),
    extensions: [isLight ? NoteColors.light : NoteColors.dark],
    cardTheme: _cardTheme(isLight),
    dialogTheme: _dialogTheme(isLight),
    popupMenuTheme: _popupMenuTheme(isLight),
    snackBarTheme: _snackBarTheme(isLight),
    floatingActionButtonTheme: _fabTheme(scheme, isLight),
    iconButtonTheme: _iconButtonTheme(scheme, isLight),
    textButtonTheme: _textButtonTheme(),
    scrollbarTheme: _scrollbarTheme(isLight),
    dividerColor: isLight ? const Color(0xFFE2E8F0) : const Color(0xFF2B3348),
    textTheme: _textTheme(brightness),
  );
}

CardThemeData _cardTheme(bool isLight) => CardThemeData(
  elevation: 0,
  margin: EdgeInsets.zero,
  color: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF151B29),
  surfaceTintColor: Colors.transparent,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
  ),
);

DialogThemeData _dialogTheme(bool isLight) => DialogThemeData(
  backgroundColor: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF151B29),
  surfaceTintColor: Colors.transparent,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  ),
);

PopupMenuThemeData _popupMenuTheme(bool isLight) => PopupMenuThemeData(
  color: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF151B29),
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  shadowColor: isLight ? const Color(0x1F0F172A) : const Color(0x73000000),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);

SnackBarThemeData _snackBarTheme(bool isLight) => SnackBarThemeData(
  behavior: SnackBarBehavior.floating,
  backgroundColor: isLight ? const Color(0xFF0F172A) : const Color(0xFF111827),
  contentTextStyle: const TextStyle(
    fontSize: 13,
    color: Colors.white,
    fontWeight: FontWeight.w500,
  ),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);

FloatingActionButtonThemeData _fabTheme(ColorScheme scheme, bool isLight) =>
    FloatingActionButtonThemeData(
      backgroundColor: isLight ? Colors.white : const Color(0xFF171D2C),
      foregroundColor: isLight ? scheme.primary : const Color(0xFFC7D2FE),
      elevation: 0,
      hoverElevation: 0,
      focusElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

IconButtonThemeData _iconButtonTheme(ColorScheme scheme, bool isLight) =>
    IconButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(
          isLight ? const Color(0xFFFFFFFF) : const Color(0xFF171D2C),
        ),
        foregroundColor: WidgetStatePropertyAll(scheme.onSurfaceVariant),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        side: WidgetStatePropertyAll(
          BorderSide(
            color: isLight ? const Color(0xFFD9E2EF) : const Color(0xFF2B3348),
          ),
        ),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused) ||
              states.contains(WidgetState.pressed)) {
            return isLight ? const Color(0x126366F1) : const Color(0x14818CF8);
          }
          return null;
        }),
      ),
    );

TextButtonThemeData _textButtonTheme() => TextButtonThemeData(
  style: ButtonStyle(
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
);

ScrollbarThemeData _scrollbarTheme(bool isLight) => ScrollbarThemeData(
  radius: const Radius.circular(999),
  thickness: const WidgetStatePropertyAll(8),
  thumbVisibility: const WidgetStatePropertyAll(true),
  thumbColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.dragged)) {
      return isLight ? const Color(0x7A64748B) : const Color(0x8894A3B8);
    }
    if (states.contains(WidgetState.hovered)) {
      return isLight ? const Color(0x6664748B) : const Color(0x6E94A3B8);
    }
    return isLight ? const Color(0x4464748B) : const Color(0x4C94A3B8);
  }),
);

TextTheme _textTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;
  final primary = isLight ? const Color(0xFF172033) : const Color(0xFFE2E8F0);
  final secondary = isLight ? const Color(0xFF66758D) : const Color(0xFF95A3BA);
  final tertiary = isLight ? const Color(0xFF8A96A8) : const Color(0xFF74839B);

  return TextTheme(
    bodyMedium: TextStyle(fontSize: 14, height: 1.62, color: primary),
    bodySmall: TextStyle(fontSize: 13, height: 1.55, color: primary),
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
