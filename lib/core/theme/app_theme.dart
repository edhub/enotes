import 'package:flutter/material.dart';

part 'app_theme_data.part.dart';
part 'note_colors.part.dart';

/// App-wide theme definitions.
/// Uses Material 3 with a custom indigo seed. Supports light + dark modes.
abstract final class AppTheme {
  static const _seed = Color(0xFF6366F1); // indigo

  static ThemeData light() => _buildTheme(Brightness.light);

  static ThemeData dark() => _buildTheme(Brightness.dark);
}
