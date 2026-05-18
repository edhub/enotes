import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web implementation: triggers a browser download of the text content.
Future<bool?> saveTextFile({
  required String content,
  required String suggestedName,
  required String typeLabel,
  required String extension,
}) async {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: 'text/plain'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = suggestedName;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
