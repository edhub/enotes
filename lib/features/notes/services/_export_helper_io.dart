import 'dart:io';

import 'package:file_selector/file_selector.dart';

/// Desktop implementation: opens a save dialog and writes the file.
Future<bool?> saveTextFile({
  required String content,
  required String suggestedName,
  required String typeLabel,
  required String extension,
}) async {
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: [
      XTypeGroup(label: typeLabel, extensions: [extension]),
    ],
  );
  if (location == null) return null; // user cancelled
  await File(location.path).writeAsString(content);
  return true;
}
