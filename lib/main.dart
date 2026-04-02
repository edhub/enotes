import 'package:flutter/material.dart';

import 'app.dart';
import 'features/notes/services/migration_service.dart';
import 'features/notes/services/notes_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final service = NotesService();
  await service.init();

  // One-time migration from legacy JSON file → SQLite.
  // No-op if DB already has data or no legacy file exists.
  await MigrationService(service).migrateIfNeeded();

  final initialNotes = await service.loadNotes();
  runApp(App(service: service, initialNotes: initialNotes));
}
