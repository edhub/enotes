import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/note.dart';

/// Handles reading and writing notes to a local JSON file.
///
/// File location: {appDocumentsDir}/enotes/notes.json
class NotesService {
  static const _dirName = 'enotes';
  static const _fileName = 'notes.json';

  Future<File> _resolveFile() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_dirName');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/$_fileName');
  }

  /// Loads all notes from disk. Returns an empty list on any error.
  Future<List<Note>> loadNotes() async {
    try {
      final file = await _resolveFile();
      if (!file.existsSync()) return [];
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Note.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      log('NotesService.loadNotes failed: $e', error: e, stackTrace: st);
      return [];
    }
  }

  /// Persists all notes to disk. Logs errors without throwing.
  Future<void> saveNotes(List<Note> notes) async {
    try {
      final file = await _resolveFile();
      final encoded = jsonEncode(notes.map((n) => n.toJson()).toList());
      await file.writeAsString(encoded);
    } catch (e, st) {
      log('NotesService.saveNotes failed: $e', error: e, stackTrace: st);
    }
  }
}
