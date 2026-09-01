import 'dart:ui';

class ReceiptSegment {
  final String imagePath;
  final List<ReceiptLine> lines;

  const ReceiptSegment({required this.imagePath, required this.lines});
}

class ReceiptLine {
  final String text;
  final Rect bounds;

  const ReceiptLine({required this.text, required this.bounds});
}

class ReceiptItem {
  final String name;
  final int cents;
  final String priceText;

  const ReceiptItem({
    required this.name,
    required this.cents,
    required this.priceText,
  });
}
