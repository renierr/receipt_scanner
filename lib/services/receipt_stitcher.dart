import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/receipt.dart';

class ReceiptStitcher {
  Future<Uint8List> stitch(List<ReceiptSegment> segments) async {
    final images = <img.Image>[];
    for (final segment in segments) {
      final image = img.decodeImage(
        await File(segment.imagePath).readAsBytes(),
      );
      if (image == null) {
        throw const FormatException('Unsupported image format');
      }
      images.add(img.bakeOrientation(image));
    }
    final contentWidth = images
        .map((image) => image.width)
        .reduce((a, b) => a < b ? a : b)
        .clamp(800, 1600);
    for (var index = 0; index < images.length; index++) {
      images[index] = img.copyResize(images[index], width: contentWidth);
    }
    final joins = <_ReceiptJoin>[];
    for (var index = 1; index < images.length; index++) {
      joins.add(_findJoin(images[index - 1], images[index]));
    }
    final offsets = <int>[0];
    for (final join in joins) {
      offsets.add(offsets.last + join.horizontalOffset);
    }
    final minimumOffset = offsets.reduce((a, b) => a < b ? a : b);
    final maximumOffset = offsets.reduce((a, b) => a > b ? a : b);
    final height =
        images.first.height +
        List.generate(
          images.length - 1,
          (index) => images[index + 1].height - joins[index].overlap,
        ).fold<int>(0, (total, value) => total + value);
    final receipt = img.Image(
      width: contentWidth + maximumOffset - minimumOffset,
      height: height,
      numChannels: 3,
    );
    var y = 0;
    for (var index = 0; index < images.length; index++) {
      final join = index == 0 ? const _ReceiptJoin() : joins[index - 1];
      final source = images[index];
      final visibleHeight = source.height - join.overlap;
      img.compositeImage(
        receipt,
        source,
        dstX: offsets[index] - minimumOffset,
        dstY: y,
        srcY: join.overlap,
        srcH: visibleHeight,
        dstH: visibleHeight,
      );
      y += visibleHeight;
    }
    return Uint8List.fromList(img.encodeJpg(receipt, quality: 92));
  }

  _ReceiptJoin _findJoin(img.Image previous, img.Image next) {
    final maximumOverlap =
        (previous.height < next.height ? previous.height : next.height) *
        3 ~/
        5;
    var best = const _ReceiptJoin();
    var bestScore = double.infinity;
    for (var overlap = 80; overlap <= maximumOverlap; overlap += 8) {
      for (var shift = -48; shift <= 48; shift += 4) {
        final score = _overlapScore(previous, next, overlap, shift);
        if (score < bestScore) {
          bestScore = score;
          best = _ReceiptJoin(overlap: overlap, horizontalOffset: shift);
        }
      }
    }
    return bestScore < 42 ? best : const _ReceiptJoin();
  }

  double _overlapScore(
    img.Image previous,
    img.Image next,
    int overlap,
    int horizontalOffset,
  ) {
    var total = 0;
    var samples = 0;
    for (var y = 8; y < overlap - 8; y += 8) {
      for (var x = 8; x < previous.width - 8; x += 8) {
        final nextX = x - horizontalOffset;
        if (nextX < 1 || nextX >= next.width - 1) continue;
        final previousInk = _ink(previous, x, previous.height - overlap + y);
        final nextInk = _ink(next, nextX, y);
        if (previousInk < 12 && nextInk < 12) continue;
        total += (previousInk - nextInk).abs();
        samples++;
      }
    }
    return samples < 24 ? double.infinity : total / samples;
  }

  int _ink(img.Image image, int x, int y) {
    final pixel = image.getPixel(x, y);
    return 255 - (pixel.r * 299 + pixel.g * 587 + pixel.b * 114) ~/ 1000;
  }
}

class _ReceiptJoin {
  final int overlap;
  final int horizontalOffset;

  const _ReceiptJoin({this.overlap = 0, this.horizontalOffset = 0});
}
