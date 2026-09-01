import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_scanner/models/receipt.dart';
import 'package:receipt_scanner/services/receipt_parser.dart';

void main() {
  final parser = ReceiptParser();

  List<ReceiptLine> lines(List<String> texts) => [
    for (final (index, text) in texts.indexed)
      ReceiptLine(text: text, bounds: Rect.fromLTWH(0, index * 40, 200, 32)),
  ];

  group('items', () {
    test('extracts items followed by a VAT-rate letter', () {
      final items = parser.items(
        lines(['Milch 1,29 A', 'Butter 2,49 B', 'Brot 3,99']),
      );

      expect(items.map((item) => item.name), ['Milch', 'Butter', 'Brot']);
      expect(items.map((item) => item.priceText), ['1,29', '2,49', '3,99']);
      expect(items.map((item) => item.cents), [129, 249, 399]);
    });

    test('extracts items followed by a discount asterisk', () {
      final items = parser.items(lines(['Reis 2,99*']));

      expect(items.single.name, 'Reis');
      expect(items.single.priceText, '2,99');
    });

    test('keeps a currency code out of the item name', () {
      final items = parser.items(lines(['Cola 1,99 EUR']));

      expect(items.single.name, 'Cola');
      expect(items.single.priceText, '1,99 EUR');
    });

    test('drops a total line matching the running sum', () {
      final items = parser.items(
        lines(['Milch 1,29 A', 'Butter 2,49 B', 'SUMME 3,78 EUR']),
      );

      expect(items.map((item) => item.name), ['Milch', 'Butter']);
    });
  });
}
