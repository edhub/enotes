import 'package:flutter/foundation.dart';

/// Application environment — derived from build mode.
///
/// Debug / Profile → [isDev] = true  → uses `enotes_dev.db`
/// Release         → [isDev] = false → uses `enotes.db`
///
/// This ensures development work never touches production data.
class AppEnv {
  const AppEnv._();

  static bool get isDev => !kReleaseMode;
  static String get dbFileName => isDev ? 'enotes_dev.db' : 'enotes.db';
}
