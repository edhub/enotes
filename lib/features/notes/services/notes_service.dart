import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../../core/env/app_env.dart';
import '../models/note.dart';

/// SQLite-backed note storage.
///
/// **Must call [init] once before any other method** (in [main]).
///
/// Database location (macOS Application Support container):
///   Release        → `enotes.db`
///   Debug/Profile  → `enotes_dev.db`
///
/// WAL mode is enabled for better write performance and crash safety.
///
/// Mutations ([saveNotes], [upsertNotes], [deleteNotesByIds]) **rethrow**
/// on failure after logging — callers (typically [NotesNotifier]) catch
/// the error and surface it via [saveErrorProvider]. Read-only [loadNotes]
/// returns `[]` on failure (no caller can usefully react beyond logging).
///
/// Each mutation yields the event loop with `Future(() ...)` so a
/// long-running write (rare, but possible on first sync after large imports)
/// does not block the next frame.
class NotesService {
  Database? _db;

  /// Opens (or creates) the SQLite database and ensures the schema exists.
  ///
  /// Throws on failure — `main()` should catch this and present a startup
  /// error screen rather than launching the app with no persistence.
  Future<void> init() async {
    final support = await getApplicationSupportDirectory();
    if (!Directory(support.path).existsSync()) {
      Directory(support.path).createSync(recursive: true);
    }
    final path = '${support.path}/${AppEnv.dbFileName}';
    _db = sqlite3.open(path);
    _db!.execute('PRAGMA journal_mode=WAL;');
    _createSchema();
    log('NotesService: opened ${AppEnv.dbFileName} at ${support.path}');
  }

  void _createSchema() {
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id         TEXT    PRIMARY KEY,
        content    TEXT    NOT NULL,
        created_at TEXT    NOT NULL,
        updated_at TEXT    NOT NULL,
        is_draft   INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT
      )
    ''');
  }

  /// Loads all notes from the database. Returns an empty list on any error
  /// (no caller can recover beyond what's logged).
  Future<List<Note>> loadNotes() async {
    try {
      return _db!.select('SELECT * FROM notes').map(_rowToNote).toList();
    } catch (e, st) {
      log('NotesService.loadNotes failed: $e', error: e, stackTrace: st);
      return [];
    }
  }

  /// Atomically replaces all notes with [notes] inside a single transaction.
  ///
  /// Uses DELETE + INSERT rather than UPSERT so that permanently deleted notes
  /// are also removed from the DB when the provider removes them from its list.
  ///
  /// Only used for full imports. For incremental saves, prefer
  /// [upsertNotes] + [deleteNotesByIds].
  Future<void> saveNotes(List<Note> notes) {
    return Future(() {
      final db = _requireDb();
      try {
        db.execute('BEGIN');
        db.execute('DELETE FROM notes');
        final stmt = db.prepare(_insertSql);
        try {
          for (final n in notes) {
            stmt.execute(_noteParams(n));
          }
        } finally {
          stmt.dispose();
        }
        db.execute('COMMIT');
      } catch (e, st) {
        _safeRollback(db);
        log('NotesService.saveNotes failed: $e', error: e, stackTrace: st);
        rethrow;
      }
    });
  }

  /// Incrementally inserts or updates [notes] without touching other rows.
  ///
  /// Uses `INSERT OR REPLACE` so both new and modified notes are handled
  /// in a single statement. Wrapped in a transaction for atomicity.
  Future<void> upsertNotes(List<Note> notes) {
    if (notes.isEmpty) return Future.value();
    return Future(() {
      final db = _requireDb();
      try {
        db.execute('BEGIN');
        final stmt = db.prepare(_insertOrReplaceSql);
        try {
          for (final n in notes) {
            stmt.execute(_noteParams(n));
          }
        } finally {
          stmt.dispose();
        }
        db.execute('COMMIT');
      } catch (e, st) {
        _safeRollback(db);
        log('NotesService.upsertNotes failed: $e', error: e, stackTrace: st);
        rethrow;
      }
    });
  }

  /// Permanently removes notes with the given [ids] from the database.
  Future<void> deleteNotesByIds(Set<String> ids) {
    if (ids.isEmpty) return Future.value();
    return Future(() {
      final db = _requireDb();
      try {
        db.execute('BEGIN');
        final stmt = db.prepare('DELETE FROM notes WHERE id = ?');
        try {
          for (final id in ids) {
            stmt.execute([id]);
          }
        } finally {
          stmt.dispose();
        }
        db.execute('COMMIT');
      } catch (e, st) {
        _safeRollback(db);
        log(
          'NotesService.deleteNotesByIds failed: $e',
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
    });
  }

  /// Closes the database connection. Safe to call multiple times.
  void dispose() {
    _db?.dispose();
    _db = null;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Database _requireDb() {
    final db = _db;
    if (db == null) {
      throw StateError(
        'NotesService used before init() — call init() in main().',
      );
    }
    return db;
  }

  /// ROLLBACK can itself throw if the DB is in an unusable state; never let
  /// that mask the original error.
  void _safeRollback(Database db) {
    try {
      db.execute('ROLLBACK');
    } catch (_) {/* ignore */}
  }

  static const _insertSql =
      'INSERT INTO notes (id, content, created_at, updated_at, is_draft, deleted_at) '
      'VALUES (?, ?, ?, ?, ?, ?)';

  static const _insertOrReplaceSql =
      'INSERT OR REPLACE INTO notes (id, content, created_at, updated_at, is_draft, deleted_at) '
      'VALUES (?, ?, ?, ?, ?, ?)';

  List<Object?> _noteParams(Note n) => [
        n.id,
        n.content,
        n.createdAt.toIso8601String(),
        n.updatedAt.toIso8601String(),
        n.isDraft ? 1 : 0,
        n.deletedAt?.toIso8601String(),
      ];

  Note _rowToNote(Row row) => Note(
        id: row['id'] as String,
        content: row['content'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        isDraft: (row['is_draft'] as int) == 1,
        deletedAt: row['deleted_at'] != null
            ? DateTime.parse(row['deleted_at'] as String)
            : null,
      );
}
