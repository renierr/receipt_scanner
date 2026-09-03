import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_scanner/services/receipt_ocr.dart';

void main() {
  test('linesFromTsv groups words into lines with union bounds', () {
    const tsv =
        'level\tpage_num\tblock_num\tpar_num\t'
        'line_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n'
        '1\t1\t0\t0\t0\t0\t0\t0\t800\t200\t-1\t\n'
        '4\t1\t1\t1\t1\t0\t20\t22\t136\t18\t-1\t\n'
        '5\t1\t1\t1\t1\t1\t20\t22\t76\t17\t86.33\tAPPLE\n'
        '5\t1\t1\t1\t1\t2\t112\t22\t44\t18\t86.33\t2.50\n'
        '4\t1\t1\t1\t2\t0\t22\t82\t139\t18\t-1\t\n'
        '5\t1\t1\t1\t2\t1\t22\t82\t79\t17\t91.85\tBREAD\n'
        '5\t1\t1\t1\t2\t2\t119\t82\t42\t18\t92.05\t1.20\n';

    final lines = ReceiptOcr.linesFromTsv(tsv);

    expect(lines.map((line) => line.text), ['APPLE 2.50', 'BREAD 1.20']);
    expect(lines.first.bounds.left, 20);
    expect(lines.first.bounds.top, 22);
    expect(lines.first.bounds.right, 156);
    expect(lines.first.bounds.bottom, 40);
  });

  test('linesFromTsv ignores malformed rows and empty words', () {
    const tsv =
        'level\tpage_num\tblock_num\tpar_num\t'
        'line_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n'
        'broken row without tabs\n'
        '5\t1\t1\t1\t1\t1\tnot\tan\tint\there\t0\tWORD\n'
        '5\t1\t1\t1\t1\t1\t20\t22\t44\t18\t-1\t\n'
        '5\t1\t1\t1\t1\t1\t20\t22\t44\t18\t95.0\tKEPT\n';

    final lines = ReceiptOcr.linesFromTsv(tsv);

    expect(lines.map((line) => line.text), ['KEPT']);
  });
}
