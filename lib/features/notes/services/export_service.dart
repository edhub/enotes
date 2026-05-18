import 'dart:convert';
import 'dart:developer';

import 'package:file_selector/file_selector.dart';

import '../models/note.dart';
import '_export_helper_stub.dart'
    if (dart.library.io) '_export_helper_io.dart'
    if (dart.library.js_interop) '_export_helper_web.dart';

/// File-based import / export of notes.
///
/// Return conventions:
///   `null`  — user cancelled the file picker (no UI feedback needed).
///   `true`  — operation completed successfully.
///   `false` — operation failed (error already logged).
///
/// [importJson] returns `List<Note>?`:
///   non-null — success.
///   `null`   — cancelled or parse error (already logged).
class ExportService {
  const ExportService();

  // ── Export ─────────────────────────────────────────────────────────────────

  /// Saves a versioned JSON backup of [notes] (includes drafts & deleted).
  Future<bool?> exportJson(List<Note> notes) async {
    try {
      final payload = const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'notes': notes.map((n) => n.toJson()).toList(),
      });
      return await saveTextFile(
        content: payload,
        suggestedName: 'enotes_backup_${_stamp()}.json',
        typeLabel: 'JSON',
        extension: 'json',
      );
    } catch (e, st) {
      log('ExportService.exportJson failed: $e', error: e, stackTrace: st);
      return false;
    }
  }

  /// Saves active (non-draft, non-deleted) notes as plain text separated by
  /// `---`, sorted newest-first.
  Future<bool?> exportMarkdown(List<Note> notes) async {
    try {
      final active = notes.where((n) => !n.isDraft && !n.isDeleted).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final buf = StringBuffer();
      for (var i = 0; i < active.length; i++) {
        buf.write(active[i].content);
        if (i < active.length - 1) buf.write('\n\n---\n\n');
      }
      return await saveTextFile(
        content: buf.toString(),
        suggestedName: 'enotes_export_${_stamp()}.md',
        typeLabel: 'Markdown',
        extension: 'md',
      );
    } catch (e, st) {
      log('ExportService.exportMarkdown failed: $e', error: e, stackTrace: st);
      return false;
    }
  }

  // ── Import ─────────────────────────────────────────────────────────────────

  /// Opens a file picker and parses the selected JSON backup.
  ///
  /// Accepts both the versioned format (`{ "version": 1, "notes": […] }`)
  /// and the legacy plain-array format (`[…]`).
  ///
  /// Return conventions:
  ///   `null`  — parse / IO error (already logged).
  ///   `[]`    — user cancelled the file picker (no feedback needed).
  ///   `[…]`   — parsed notes (success).
  Future<List<Note>?> importJson() async {
    const typeGroup = XTypeGroup(label: 'JSON', extensions: ['json']);
    final files = await openFiles(acceptedTypeGroups: [typeGroup]);
    if (files.isEmpty) return const []; // user cancelled

    try {
      final raw = await files.first.readAsString();
      final decoded = jsonDecode(raw);

      final List<dynamic> list;
      if (decoded is Map && decoded.containsKey('notes')) {
        list = decoded['notes'] as List<dynamic>;
      } else if (decoded is List) {
        list = decoded;
      } else {
        log('ExportService.importJson: unrecognized format');
        return null;
      }

      return list.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e, st) {
      log('ExportService.importJson failed: $e', error: e, stackTrace: st);
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _stamp() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }
}
