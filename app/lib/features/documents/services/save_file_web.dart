// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// This file is only ever compiled in when targeting web (see the
// conditional export in save_file.dart) — `dart:html` is exactly what's
// needed here, and there's no non-web build to accidentally pull it into.
import 'dart:html' as html;
import 'dart:typed_data';

void saveFile(Uint8List bytes, String filename, String contentType) {
  final blob = html.Blob([bytes], contentType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
