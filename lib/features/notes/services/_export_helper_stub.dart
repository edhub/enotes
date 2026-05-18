/// Stub for platforms where neither dart:io nor dart:js_interop is available.
Future<bool?> saveTextFile({
  required String content,
  required String suggestedName,
  required String typeLabel,
  required String extension,
}) {
  throw UnsupportedError('saveTextFile not implemented on this platform');
}
