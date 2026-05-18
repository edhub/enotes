import 'dart:developer';

import 'package:sqlite3/common.dart';
import 'package:sqlite3/wasm.dart' as sqlite3_wasm;

Future<CommonDatabase> openNotesDb(String dbFileName) async {
  final wasmSqlite = await sqlite3_wasm.WasmSqlite3.loadFromUrl(
    Uri.parse('sqlite3.wasm'),
  );
  final vfs = await sqlite3_wasm.IndexedDbFileSystem.open(
    dbName: 'enotes_sqlite',
  );
  wasmSqlite.registerVirtualFileSystem(vfs, makeDefault: true);
  final db = wasmSqlite.open(dbFileName);
  log('NotesService (web): opened $dbFileName via IndexedDB');
  return db;
}
