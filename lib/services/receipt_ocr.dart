import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/receipt.dart';

class ReceiptOcr {
  Future<List<ReceiptLine>> read(String path) async {
    if (Platform.isAndroid) {
      return _readWithMlKit(path);
    }
    return _readWithTesseract(path);
  }

  Future<List<ReceiptLine>> _readWithMlKit(String path) async {
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

  Future<List<ReceiptLine>> _readWithTesseract(String path) async {
    late final ProcessResult result;
    try {
      result = await Process.run('tesseract', [
        path,
        'stdout',
        '--psm',
        '6',
        'tsv',
      ]);
    } on ProcessException {
      throw Exception(
        'Tesseract OCR is not installed. Install tesseract to enable text extraction.',
      );
    }
    if (result.exitCode != 0) {
      throw Exception('Tesseract OCR failed: ${result.stderr}');
    }
    return linesFromTsv(result.stdout as String);
  }

  @visibleForTesting
  static List<ReceiptLine> linesFromTsv(String tsv) {
    final wordsByLine = <String, List<_TsvWord>>{};
    for (final row in tsv.split('\n').skip(1)) {
      if (row.trim().isEmpty) continue;
      final columns = row.split('\t');
      if (columns.length < 12 || int.tryParse(columns[0]) != 5) continue;
      final bounds = columns.sublist(6, 10).map(int.tryParse).toList();
      if (bounds.any((value) => value == null)) continue;
      final text = columns.skip(11).join('\t').trim();
      if (text.isEmpty) continue;
      final key = '${columns[2]}_${columns[3]}_${columns[4]}';
      (wordsByLine[key] ??= []).add(
        _TsvWord(
          text: text,
          left: bounds[0]!,
          top: bounds[1]!,
          width: bounds[2]!,
          height: bounds[3]!,
        ),
      );
    }
    return [
      for (final words in wordsByLine.values)
        ReceiptLine(
          text: words.map((word) => word.text).join(' '),
          bounds: Rect.fromLTRB(
            words.map((word) => word.left).reduce(_min).toDouble(),
            words.map((word) => word.top).reduce(_min).toDouble(),
            words.map((word) => word.left + word.width).reduce(_max).toDouble(),
            words.map((word) => word.top + word.height).reduce(_max).toDouble(),
          ),
        ),
    ]..sort((a, b) => a.bounds.top.compareTo(b.bounds.top));
  }
}

int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;

class _TsvWord {
  final String text;
  final int left;
  final int top;
  final int width;
  final int height;

  const _TsvWord({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}
