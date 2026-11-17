// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';

class PdfPreview extends StatefulWidget {
  const PdfPreview({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<PdfPreview> {
  late final String _url = html.Url.createObjectUrlFromBlob(
      html.Blob([widget.bytes], 'application/pdf'));
  @override
  void dispose() {
    html.Url.revokeObjectUrl(_url);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (element) {
        final frame = element as html.IFrameElement;
        frame.src = _url;
        frame.title = 'Document preview';
        frame.style.border = '0';
        frame.style.width = '100%';
        frame.style.height = '100%';
      });
}
