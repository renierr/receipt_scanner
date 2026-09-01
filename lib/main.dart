import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:saver_gallery/saver_gallery.dart';

void main() => runApp(const ReceiptScannerApp());

class ReceiptScannerApp extends StatelessWidget {
  const ReceiptScannerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Receipt Scanner',
    themeMode: ThemeMode.system,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: const ReceiptHomePage(),
  );
}

class ReceiptSegment {
  final String imagePath;
  final String text;

  const ReceiptSegment({required this.imagePath, required this.text});
}

class ReceiptHomePage extends StatefulWidget {
  const ReceiptHomePage({super.key});

  @override
  State<ReceiptHomePage> createState() => _ReceiptHomePageState();
}

class _ReceiptHomePageState extends State<ReceiptHomePage> {
  final List<ReceiptSegment> _segments = [];
  bool _isProcessing = false;
  bool _isSaving = false;

  String get _combinedText {
    final result = <String>[];
    for (final segment in _segments) {
      final next = segment.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      result.addAll(_removeOverlap(result, next));
    }
    return result.join('\n');
  }

  Future<void> _openCamera() async {
    final paths = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => const ReceiptCameraPage()),
    );
    if (paths != null) await _addImages(paths);
  }

  Future<void> _importImages() async {
    const images = XTypeGroup(
      label: 'Images',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    final files = await openFiles(acceptedTypeGroups: [images]);
    await _addImages(files.map((file) => file.path).toList());
  }

  Future<void> _addImages(List<String> paths) async {
    if (paths.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      for (final path in paths) {
        _segments.add(
          ReceiptSegment(imagePath: path, text: await _readText(path)),
        );
        if (mounted) setState(() {});
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Text extraction failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<String> _readText(String path) async {
    if (!Platform.isAndroid) return 'OCR is currently available on Android.';
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      return (await recognizer.processImage(InputImage.fromFilePath(path)))
          .text;
    } finally {
      recognizer.close();
    }
  }

  Future<void> _saveReceipt() async {
    if (_segments.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final bytes = await _stitchReceipt();
      final result = await SaverGallery.saveImage(
        bytes,
        fileName: 'receipt-${DateTime.now().millisecondsSinceEpoch}.jpg',
        albumPath: 'Receipt Scanner',
        skipIfExists: false,
      );
      if (!result.isSuccess) throw Exception(result.errorMessage);
      if (mounted) _showMessage('Receipt image saved to the gallery.');
    } catch (_) {
      if (mounted) _showMessage('Could not save the receipt image.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<Uint8List> _stitchReceipt() async {
    final images = <img.Image>[];
    for (final segment in _segments) {
      final image = img.decodeImage(
        await File(segment.imagePath).readAsBytes(),
      );
      if (image == null) {
        throw const FormatException('Unsupported image format');
      }
      images.add(img.bakeOrientation(image));
    }

    final width = images
        .map((image) => image.width)
        .reduce((a, b) => a > b ? a : b);
    final overlap = images.length > 1 ? images.first.height ~/ 12 : 0;
    final height =
        images.fold<int>(0, (total, image) => total + image.height) -
        overlap * (images.length - 1);
    final receipt = img.Image(width: width, height: height, numChannels: 3);
    var y = 0;
    for (var index = 0; index < images.length; index++) {
      final source = images[index];
      final destinationHeight = source.height - (index == 0 ? 0 : overlap);
      img.compositeImage(
        receipt,
        source,
        dstX: (width - source.width) ~/ 2,
        dstY: y,
        srcY: index == 0 ? 0 : overlap,
        srcH: destinationHeight,
        dstH: destinationHeight,
      );
      y += destinationHeight;
    }
    return Uint8List.fromList(img.encodeJpg(receipt, quality: 92));
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  List<String> _removeOverlap(List<String> previous, List<String> next) {
    final maximum = previous.length < next.length
        ? previous.length
        : next.length;
    for (var count = maximum; count > 0; count--) {
      var matches = true;
      for (var index = 0; index < count; index++) {
        if (_normalized(previous[previous.length - count + index]) !=
            _normalized(next[index])) {
          matches = false;
          break;
        }
      }
      if (matches) return next.sublist(count);
    }
    return next;
  }

  String _normalized(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  Widget build(BuildContext context) {
    final android = Platform.isAndroid;
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Scanner')),
      body: Column(
        children: [
          if (_isProcessing) const LinearProgressIndicator(),
          Expanded(
            child: _segments.isEmpty
                ? _EmptyState(showCamera: android)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Scan from top to bottom. Keep the yellow line in the next photo.',
                      ),
                      const SizedBox(height: 16),
                      for (final (index, segment) in _segments.indexed)
                        Card(
                          child: ListTile(
                            leading: Image.file(
                              File(segment.imagePath),
                              width: 48,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                            title: Text('Section ${index + 1}'),
                            subtitle: Text(
                              segment.text.isEmpty
                                  ? 'No text found'
                                  : segment.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  setState(() => _segments.removeAt(index)),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'Extracted text',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      SelectableText(_combinedText),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (android)
                    FilledButton.icon(
                      onPressed: _isProcessing ? null : _openCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Scan receipt'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _importImages,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Import photos'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isProcessing || _isSaving || _segments.isEmpty
                        ? null
                        : _saveReceipt,
                    icon: _isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt),
                    label: const Text('Save receipt image'),
                  ),
                  if (_segments.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => setState(_segments.clear),
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool showCamera;

  const _EmptyState({required this.showCamera});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 80),
          const SizedBox(height: 20),
          Text(
            'Scan a long receipt',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'The Android camera remains open while you capture each overlapping section.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            showCamera
                ? 'Use the buttons below to start.'
                : 'Import photos to begin.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class ReceiptCameraPage extends StatefulWidget {
  const ReceiptCameraPage({super.key});

  @override
  State<ReceiptCameraPage> createState() => _ReceiptCameraPageState();
}

class _ReceiptCameraPageState extends State<ReceiptCameraPage> {
  CameraController? _controller;
  final List<String> _captures = [];
  bool _capturing = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      await controller.initialize();
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);
      if (mounted) setState(() => _controller = controller);
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      _captures.add((await controller.takePicture()).path);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null) return;
    _torchOn = !_torchOn;
    await controller.setFlashMode(_torchOn ? FlashMode.torch : FlashMode.off);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(controller),
          const Center(child: _ReceiptFrame()),
          Positioned(
            top: 48,
            right: 16,
            child: IconButton.filledTonal(
              onPressed: _toggleTorch,
              icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 128,
            child: Text(
              'Move the receipt up. Keep the yellow line in the next photo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                shadows: [Shadow(blurRadius: 4)],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(_captures),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                    child: const Text('Done'),
                  ),
                ),
                const SizedBox(width: 24),
                IconButton.filled(
                  onPressed: _capturing ? null : _capture,
                  iconSize: 36,
                  style: IconButton.styleFrom(minimumSize: const Size(72, 72)),
                  icon: _capturing
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.camera_alt),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    '${_captures.length} captured',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptFrame extends StatelessWidget {
  const _ReceiptFrame();

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: 0.62,
    heightFactor: 0.78,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Align(
        alignment: Alignment(0, 0.55),
        child: ColoredBox(
          color: Colors.amber,
          child: SizedBox(height: 3, width: double.infinity),
        ),
      ),
    ),
  );
}
