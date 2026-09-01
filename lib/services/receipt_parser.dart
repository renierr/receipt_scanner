import '../models/receipt.dart';

class ReceiptParser {
  List<ReceiptLine> mergeSegments(List<ReceiptSegment> segments) {
    final result = <ReceiptLine>[];
    for (final segment in segments) {
      final next = segment.lines
          .where((line) => line.text.trim().isNotEmpty)
          .toList();
      result.addAll(_removeOverlap(result, next));
    }
    return result;
  }

  List<ReceiptItem> items(List<ReceiptLine> lines) {
    final candidates = <ReceiptItem>[];
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].text.replaceAll(RegExp(r'\s+'), ' ').trim();
      // Trailing tag covers VAT-rate letters/markers many receipts print after
      // the price (e.g. "1,29 A", "2,99*"); it is not part of the price itself.
      final price = RegExp(
        r'(\d{1,3}(?:[ .]\d{3})*[,\.]\d{2}\s*(?:\p{Sc}|[A-Z]{3})?)[\sA-Za-z*]{0,4}$',
        unicode: true,
      ).firstMatch(line);
      if (line.isEmpty || price == null) continue;
      var name = line.substring(0, price.start).trim();
      if (name.isEmpty &&
          index > 0 &&
          lines[index].bounds.top - lines[index - 1].bounds.bottom < 48) {
        name = lines[index - 1].text.trim();
      }
      name = name.replaceFirst(RegExp(r'^\d+(?:[.,]\d+)?\s*[xX*]\s*'), '');
      if (name.length < 2 || RegExp(r'^\d+(?:[ .,/:-]\d+)*$').hasMatch(name)) {
        continue;
      }
      candidates.add(
        ReceiptItem(
          name: name,
          cents: _parseCents(price.group(1)!),
          priceText: price.group(1)!.trim(),
        ),
      );
    }
    return _withoutTotals(candidates);
  }

  List<ReceiptLine> _removeOverlap(
    List<ReceiptLine> previous,
    List<ReceiptLine> next,
  ) {
    final maximum = previous.length < next.length
        ? previous.length
        : next.length;
    // Preserve a repeated article; only a matching multi-line photo boundary is duplicate OCR.
    for (var count = maximum; count >= 2; count--) {
      var matches = true;
      for (var index = 0; index < count; index++) {
        if (_normalized(previous[previous.length - count + index].text) !=
            _normalized(next[index].text)) {
          matches = false;
          break;
        }
      }
      if (matches) return next.sublist(count);
    }
    return next;
  }

  int _parseCents(String value) {
    final number = value.replaceAll(RegExp(r'[^0-9,.]'), '');
    final separator = number.lastIndexOf(RegExp(r'[,\.]'));
    final whole = number
        .substring(0, separator)
        .replaceAll(RegExp(r'[^0-9]'), '');
    return int.parse(whole) * 100 +
        int.parse(
          number.substring(separator + 1).padRight(2, '0').substring(0, 2),
        );
  }

  List<ReceiptItem> _withoutTotals(List<ReceiptItem> candidates) {
    final result = <ReceiptItem>[];
    var runningTotal = 0;
    for (final item in candidates) {
      if (result.length >= 2 && item.cents == runningTotal) continue;
      result.add(item);
      runningTotal += item.cents;
    }
    return result;
  }

  String _normalized(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}
