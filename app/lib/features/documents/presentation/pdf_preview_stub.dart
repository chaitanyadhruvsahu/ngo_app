import 'dart:typed_data';
import 'package:flutter/material.dart';

class PdfPreview extends StatelessWidget {
  const PdfPreview({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'Use Download to open this PDF in your device’s document viewer.')));
}
