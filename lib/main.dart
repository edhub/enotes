import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/notes/providers/notes_provider.dart';
import 'features/notes/services/migration_service.dart';
import 'features/notes/services/notes_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final service = NotesService();
  try {
    await service.init();
  } catch (e, st) {
    log('main: DB init failed: $e', error: e, stackTrace: st);
    runApp(_StartupErrorApp(error: e));
    return;
  }

  // One-time migration from legacy JSON file → SQLite.
  // No-op if DB already has data or no legacy file exists.
  await MigrationService(service).migrateIfNeeded();

  final initialNotes = await service.loadNotes();

  runApp(
    ProviderScope(
      overrides: [
        notesServiceProvider.overrideWithValue(service),
        initialNotesProvider.overrideWithValue(initialNotes),
      ],
      child: const App(),
    ),
  );
}

/// Last-resort fallback shown when the database cannot be opened. The user
/// gets a clear error and a copy-pastable message instead of a blank app
/// silently losing their writes.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eNotes — Startup Error',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'eNotes failed to start',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The notes database could not be opened. Your existing '
                  'notes are still on disk and have not been modified.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SelectableText(
                  '$error',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
