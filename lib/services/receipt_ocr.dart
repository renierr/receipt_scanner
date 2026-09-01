import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/receipt.dart';

class ReceiptOcr {
  Future<List<ReceiptLine>> read(String path) async {
    if (!Platform.isAndroid) return const [];
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final text = await recognizer.processImage(InputImage.fromFilePath(path));
      return [
        for (final block in text.blocks)
          for (final line in block.lines)
            ReceiptLine(text: line.text, bounds: line.boundingBox),
      ]..sort((a, b) => a.bounds.top.compareTo(b.bounds.top));
    } finally {
      recognizer.close();
    }
  }
}
