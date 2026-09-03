import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:receipt_scanner/services/v4l2_camera.dart';

void main() {
  test('yuyvToImage converts a known pixel', () {
    // Y=255 with neutral chroma is white; Y=0 with neutral chroma is black.
    final bytes = Uint8List.fromList([255, 128, 0, 128]);
    final image = V4l2Camera.yuyvToImage(bytes, 2, 1);
    final left = image.getPixel(0, 0);
    final right = image.getPixel(1, 0);
    expect(left.r, 255);
    expect(left.g, 255);
    expect(left.b, 255);
    expect(right.r, 0);
    expect(right.g, 0);
    expect(right.b, 0);
  });

  test('grab a frame from the first camera', () async {
    final devices = V4l2Camera.findDevices();
    if (devices.isEmpty) {
      markTestSkipped('No /dev/video* device found');
      return;
    }
    final camera = V4l2Camera();
    try {
      camera.open(devices.first);
      camera.start();
      final frame = camera.grabJpeg(timeoutMs: 3000);
      expect(frame, isNotNull);
      expect(frame![0], 0xff);
      expect(frame[1], 0xd8);
      final decoded = img.decodeJpg(frame);
      expect(decoded, isNotNull);
      expect(decoded!.width, camera.width);
      expect(decoded.height, camera.height);
    } finally {
      camera.close();
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
}
