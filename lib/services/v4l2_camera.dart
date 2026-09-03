import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Direct V4L2 camera access through libc. Needs nothing beyond the Linux
/// kernel and libc: no GStreamer, no extra system packages, no plugins.
///
/// Offsets below were measured against /usr/include/linux/videodev2.h on
/// x86_64 (see the ioctl size fields, which encode the struct sizes).
class V4l2Camera {
  static const int _oRdwr = 2;
  static const int _protReadWrite = 3;
  static const int _mapShared = 1;

  static const int _bufTypeCapture = 1;
  static const int _memoryMmap = 1;
  static const int _fieldAny = 0;

  static const int _pixMjpeg = 0x47504a4d;
  static const int _pixYuyv = 0x56595559;

  static const int _capVideoCapture = 0x00000001;

  // v4l2_buffer field offsets on 64-bit Linux.
  static const int _bufIndex = 0;
  static const int _bufType = 4;
  static const int _bufBytesUsed = 8;
  static const int _bufMemory = 60;
  static const int _bufMOffset = 64;
  static const int _bufLength = 72;

  static const int _queryCap = 0x80685600;
  static const int _sFmt = 0xc0d05605;
  static const int _reqBufs = 0xc0145608;
  static const int _queryBuf = 0xc0585609;
  static const int _qBuf = 0xc058560f;
  static const int _dqBuf = 0xc0585611;
  static const int _streamOn = 0x40045612;
  static const int _streamOff = 0x40045613;

  static const int _pollIn = 0x0001;

  final _LibC _libc = _LibC();

  int _fd = -1;
  int _width = 0;
  int _height = 0;
  int _pixelFormat = 0;
  final List<_MappedBuffer> _buffers = [];
  bool _streaming = false;

  int get width => _width;
  int get height => _height;
  bool get isStreaming => _streaming;

  /// Device nodes that look like cameras, e.g. /dev/video0.
  static List<String> findDevices() =>
      [for (var index = 0; index < 16; index++) '/dev/video$index']
          .where((path) => File(path).existsSync())
          .toList();

  /// Opens [path] and checks it can capture video.
  void open(String path) {
    final nativePath = _toNativeString(path);
    try {
      _fd = _libc.cOpen(nativePath, _oRdwr);
    } finally {
      _libc.free(nativePath);
    }
    if (_fd < 0) {
      throw V4l2Exception('Cannot open $path: ${_libc.errorText()}');
    }
    final caps = _libc.allocate(104);
    try {
      if (_libc.cIoctl(_fd, _queryCap, caps) != 0) {
        throw V4l2Exception('Not a V4L2 device: $path');
      }
      final capabilities = caps.readU32(84);
      final deviceCaps = caps.readU32(88);
      if (capabilities & _capVideoCapture == 0 &&
          deviceCaps & _capVideoCapture == 0) {
        throw V4l2Exception('Device cannot capture video: $path');
      }
    } finally {
      _libc.free(caps);
    }
  }

  /// Starts streaming with the first working format from the ladder.
  void start() {
    const ladder = [
      (_pixMjpeg, 1920, 1080),
      (_pixMjpeg, 1280, 720),
      (_pixMjpeg, 640, 480),
      (_pixYuyv, 1280, 720),
      (_pixYuyv, 640, 480),
    ];
    for (final (format, width, height) in ladder) {
      if (_tryFormat(format, width, height)) return;
    }
    throw V4l2Exception('Camera supports no usable format');
  }

  bool _tryFormat(int format, int width, int height) {
    final fmt = _libc.allocate(208);
    try {
      fmt.writeU32(0, _bufTypeCapture);
      fmt.writeU32(4, width);
      fmt.writeU32(8, height);
      fmt.writeU32(12, format);
      fmt.writeU32(16, _fieldAny);
      if (_libc.cIoctl(_fd, _sFmt, fmt) != 0) return false;
      _width = fmt.readU32(4);
      _height = fmt.readU32(8);
      _pixelFormat = fmt.readU32(12);
    } finally {
      _libc.free(fmt);
    }
    if (_pixelFormat != _pixMjpeg && _pixelFormat != _pixYuyv) return false;
    try {
      _requestBuffers(4);
    } catch (_) {
      return false;
    }
    return true;
  }

  void _requestBuffers(int count) {
    final req = _libc.allocate(20);
    try {
      req.writeU32(0, count);
      req.writeU32(4, _bufTypeCapture);
      req.writeU32(8, _memoryMmap);
      if (_libc.cIoctl(_fd, _reqBufs, req) != 0) {
        throw V4l2Exception('Cannot request buffers: ${_libc.errorText()}');
      }
      final granted = req.readU32(0);
      if (granted < 2) throw V4l2Exception('Driver granted no buffers');
      for (var index = 0; index < granted; index++) {
        _buffers.add(_mapBuffer(index));
      }
      for (var index = 0; index < _buffers.length; index++) {
        _queueBuffer(index);
      }
      final type = _libc.allocate(4);
      try {
        type.writeU32(0, _bufTypeCapture);
        if (_libc.cIoctl(_fd, _streamOn, type) != 0) {
          throw V4l2Exception('Cannot start stream: ${_libc.errorText()}');
        }
      } finally {
        _libc.free(type);
      }
      _streaming = true;
    } catch (_) {
      _unmapBuffers();
      rethrow;
    } finally {
      _libc.free(req);
    }
  }

  _MappedBuffer _mapBuffer(int index) {
    final buf = _libc.allocate(88);
    try {
      buf.writeU32(_bufIndex, index);
      buf.writeU32(_bufType, _bufTypeCapture);
      buf.writeU32(_bufMemory, _memoryMmap);
      if (_libc.cIoctl(_fd, _queryBuf, buf) != 0) {
        throw V4l2Exception('Cannot query buffer: ${_libc.errorText()}');
      }
      final offset = buf.readU32(_bufMOffset);
      final length = buf.readU32(_bufLength);
      final mapping = _libc.map(length, offset, _fd);
      if (mapping.address == 0xffffffffffffffff) {
        throw V4l2Exception('Cannot map buffer: ${_libc.errorText()}');
      }
      return _MappedBuffer(mapping, length);
    } finally {
      _libc.free(buf);
    }
  }

  void _queueBuffer(int index) {
    final buf = _libc.allocate(88);
    try {
      buf.writeU32(_bufIndex, index);
      buf.writeU32(_bufType, _bufTypeCapture);
      buf.writeU32(_bufMemory, _memoryMmap);
      if (_libc.cIoctl(_fd, _qBuf, buf) != 0) {
        throw V4l2Exception('Cannot queue buffer: ${_libc.errorText()}');
      }
    } finally {
      _libc.free(buf);
    }
  }

  /// Returns one JPEG frame, or null when no frame is ready within
  /// [timeoutMs].
  Uint8List? grabJpeg({int timeoutMs = 1000}) {
    if (!_streaming) return null;
    if (!_libc.waitReadable(_fd, timeoutMs)) return null;
    final buf = _libc.allocate(88);
    try {
      buf.writeU32(_bufIndex, 0);
      buf.writeU32(_bufType, _bufTypeCapture);
      buf.writeU32(_bufMemory, _memoryMmap);
      if (_libc.cIoctl(_fd, _dqBuf, buf) != 0) return null;
      final index = buf.readU32(_bufIndex);
      final used = buf.readU32(_bufBytesUsed);
      if (index >= _buffers.length || used == 0) return null;
      final bytes = Uint8List.fromList(
        _buffers[index].mapping.asTypedList(used),
      );
      _queueBuffer(index);
      if (_pixelFormat == _pixMjpeg) return bytes;
      return _encodeYuyv(bytes, _width, _height);
    } finally {
      _libc.free(buf);
    }
  }

  void close() {
    if (_fd >= 0 && _streaming) {
      final type = _libc.allocate(4);
      try {
        type.writeU32(0, _bufTypeCapture);
        _libc.cIoctl(_fd, _streamOff, type);
      } finally {
        _libc.free(type);
      }
      _streaming = false;
    }
    _unmapBuffers();
    if (_fd >= 0) {
      _libc.cClose(_fd);
      _fd = -1;
    }
  }

  void _unmapBuffers() {
    for (final buffer in _buffers) {
      _libc.unmap(buffer.mapping, buffer.length);
    }
    _buffers.clear();
  }

  Pointer<Uint8> _toNativeString(String text) {
    final units = Uint8List(text.length + 1);
    units.setAll(0, text.codeUnits);
    final native = _libc.allocate(units.length);
    native.asTypedList(units.length).setAll(0, units);
    return native;
  }

  /// Converts packed YUYV bytes to an RGB image. Pure and unit tested.
  static img.Image yuyvToImage(Uint8List bytes, int width, int height) {
    final image = img.Image(width: width, height: height, numChannels: 3);
    var source = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x += 2) {
        final y0 = bytes[source];
        final u = bytes[source + 1] - 128;
        final y1 = bytes[source + 2];
        final v = bytes[source + 3] - 128;
        source += 4;
        _putPixel(image, x, y, y0, u, v);
        _putPixel(image, x + 1, y, y1, u, v);
      }
    }
    return image;
  }

  static void _putPixel(img.Image image, int x, int y, int luma, int u, int v) {
    image.setPixelRgb(
      x,
      y,
      (luma + 1.402 * v).round().clamp(0, 255),
      (luma - 0.344136 * u - 0.714136 * v).round().clamp(0, 255),
      (luma + 1.772 * u).round().clamp(0, 255),
    );
  }

  static Uint8List _encodeYuyv(Uint8List bytes, int width, int height) {
    if (bytes.length < width * height * 2) {
      throw V4l2Exception('Truncated YUYV frame');
    }
    return Uint8List.fromList(
      img.encodeJpg(yuyvToImage(bytes, width, height), quality: 92),
    );
  }
}

class V4l2Exception implements Exception {
  final String message;
  const V4l2Exception(this.message);

  @override
  String toString() => message;
}

class _MappedBuffer {
  final Pointer<Uint8> mapping;
  final int length;

  const _MappedBuffer(this.mapping, this.length);
}

extension on Pointer<Uint8> {
  int readU32(int offset) => (cast<Uint32>() + offset ~/ 4).value;
  void writeU32(int offset, int value) {
    (cast<Uint32>() + offset ~/ 4).value = value;
  }
}

/// Minimal libc bindings: open, ioctl, mmap, poll, close and allocation.
class _LibC {
  late final DynamicLibrary _lib = DynamicLibrary.open('libc.so.6');
  late final int Function(Pointer<Uint8>, int) cOpen = _lib
      .lookupFunction<
        Int32 Function(Pointer<Uint8>, Int32),
        int Function(Pointer<Uint8>, int)
      >('open');
  late final int Function(int, int, Pointer<Uint8>) cIoctl = _lib
      .lookupFunction<
        Int32 Function(Int32, Uint64, Pointer<Uint8>),
        int Function(int, int, Pointer<Uint8>)
      >('ioctl');
  late final Pointer<Void> Function(Pointer<Void>, int, int, int, int, int)
  cMmap = _lib
      .lookupFunction<
        Pointer<Void> Function(
          Pointer<Void>,
          Uint64,
          Int32,
          Int32,
          Int32,
          Int64,
        ),
        Pointer<Void> Function(Pointer<Void>, int, int, int, int, int)
      >('mmap');
  late final int Function(Pointer<Void>, int) cMunmap = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>, Uint64),
        int Function(Pointer<Void>, int)
      >('munmap');
  late final int Function(int) cClose = _lib
      .lookupFunction<Int32 Function(Int32), int Function(int)>('close');
  late final int Function(Pointer<Void>, int, int) cPoll = _lib
      .lookupFunction<
        Int32 Function(Pointer<Void>, Uint64, Int32),
        int Function(Pointer<Void>, int, int)
      >('poll');
  late final Pointer<Void> Function(int) cMalloc = _lib
      .lookupFunction<
        Pointer<Void> Function(Uint64),
        Pointer<Void> Function(int)
      >('malloc');
  late final void Function(Pointer<Uint8>) cFree = _lib
      .lookupFunction<
        Void Function(Pointer<Uint8>),
        void Function(Pointer<Uint8>)
      >('free');
  late final Pointer<Int32> Function() cErrno = _lib
      .lookupFunction<Pointer<Int32> Function(), Pointer<Int32> Function()>(
        '__errno_location',
      );

  Pointer<Uint8> allocate(int size) {
    final pointer = cMalloc(size).cast<Uint8>();
    pointer.asTypedList(size).fillRange(0, size, 0);
    return pointer;
  }

  void free(Pointer<Uint8> pointer) => cFree(pointer);

  String errorText() {
    const messages = {
      1: 'operation not permitted',
      2: 'no such device',
      6: 'no such device',
      13: 'permission denied',
      16: 'device busy',
      22: 'invalid argument',
    };
    final errno = cErrno().value;
    return messages[errno] ?? 'error $errno';
  }

  Pointer<Uint8> map(int length, int offset, int fd) => cMmap(
    nullptr,
    length,
    V4l2Camera._protReadWrite,
    V4l2Camera._mapShared,
    fd,
    offset,
  ).cast<Uint8>();

  void unmap(Pointer<Uint8> mapping, int length) =>
      cMunmap(mapping.cast<Void>(), length);

  bool waitReadable(int fd, int timeoutMs) {
    final set = allocate(8);
    try {
      set.writeU32(0, fd);
      (set.cast<Uint16>() + 2).value = V4l2Camera._pollIn;
      return cPoll(set.cast<Void>(), 1, timeoutMs) > 0;
    } finally {
      free(set);
    }
  }
}
