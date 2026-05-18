import 'dart:developer';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3_native;

Future<CommonDatabase> openNotesDb(String dbFileName) async {
  final support = await getApplicationSupportDirectory();
  final path = '${support.path}/$dbFileName';
  final db = sqlite3_native.sqlite3.open(path);
  db.execute('PRAGMA journal_mode=WAL;');
  log('NotesService: opened $dbFileName at ${support.path}');
  return db;
}
