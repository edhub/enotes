import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/note.dart';
import 'notes_service.dart';

/// One-time migration from the legacy JSON file to SQLite.
///
/// Safe to call on every startup:
/// - SQLite DB already has data → no-op (migration already done).
/// - No legacy JSON file found  → no-op (fresh install).
/// - Both conditions clear      → bulk-insert JSON data into SQLite,
///   then rename `notes.json` → `notes.json.migrated` as an emergency backup.
class MigrationService {
  const MigrationService(this._service);

  final NotesService _service;

  Future<void> migrateIfNeeded() async {
    // Guard: skip if SQLite already has data.
    final existing = await _service.loadNotes();
    if (existing.isNotEmpty) return;

    final jsonFile = await _findLegacyFile();
    if (jsonFile == null) return;

    log('MigrationService: found legacy JSON at ${jsonFile.path}, migrating…');
    try {
      final raw = await jsonFile.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      final notes = list
          .map((e) => Note.fromJson(e as Map<String, dynamic>))
          .toList();

      await _service.saveNotes(notes);

      // Rename instead of delete — preserve as emergency backup.
      await jsonFile.rename('${jsonFile.path}.migrated');
      log(
        'MigrationService: ✓ ${notes.length} notes migrated, '
        'JSON renamed to .migrated',
      );
    } catch (e, st) {
      // Do not propagate: a failed migration must never block app startup.
      // The legacy JSON file is preserved (we never delete it on failure),
      // so the user can re-attempt by relaunching after a fix.
      log('MigrationService: failed: $e', error: e, stackTrace: st);
    }
  }

  /// The legacy service stored notes at `{Documents}/enotes/notes.json`.
  Future<File?> _findLegacyFile() async {
    final docs = await getApplicationDocumentsDirectory();
    final f = File('${docs.path}/enotes/notes.json');
    return f.existsSync() ? f : null;
  }
}
