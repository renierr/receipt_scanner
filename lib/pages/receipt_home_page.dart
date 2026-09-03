import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:saver_gallery/saver_gallery.dart';

import '../models/receipt.dart';
import '../services/receipt_ocr.dart';
import '../services/receipt_parser.dart';
import '../services/receipt_stitcher.dart';
import 'receipt_camera_page.dart';

class ReceiptHomePage extends StatefulWidget {
  const ReceiptHomePage({super.key});

  @override
  State<ReceiptHomePage> createState() => _ReceiptHomePageState();
}

class _ReceiptHomePageState extends State<ReceiptHomePage> {
  final _segments = <ReceiptSegment>[];
  final _ocr = ReceiptOcr();
  final _parser = ReceiptParser();
  final _stitcher = ReceiptStitcher();
  bool _isProcessing = false;
  bool _isSaving = false;

  List<ReceiptItem> get _items =>
      _parser.items(_parser.mergeSegments(_segments));

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
          ReceiptSegment(imagePath: path, lines: await _ocr.read(path)),
        );
        if (mounted) setState(() {});
      }
    } catch (error) {
      if (mounted) _message('Text extraction failed: $error');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveReceipt() async {
    if (_segments.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final bytes = await _stitcher.stitch(_segments);
      if (Platform.isAndroid) {
        final result = await SaverGallery.saveImage(
          bytes,
          fileName: 'receipt-${DateTime.now().millisecondsSinceEpoch}.jpg',
          albumPath: 'Receipt Scanner',
          skipIfExists: false,
        );
        if (!result.isSuccess) throw Exception(result.errorMessage);
        if (mounted) _message('Receipt image saved to the gallery.');
      } else {
        final location = await getSaveLocation(
          suggestedName: 'receipt-${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        final path = location?.path;
        if (path == null) return;
        await File(path).writeAsBytes(bytes);
        if (mounted) _message('Receipt image saved.');
      }
    } catch (_) {
      if (mounted) _message('Could not save the receipt image.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Receipt Scanner')),
    body: Column(
      children: [
        if (_isProcessing) const LinearProgressIndicator(),
        Expanded(
          child: _segments.isEmpty
              ? const _EmptyState()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
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
                            segment.lines.isEmpty
                                ? 'No text found'
                                : segment.lines
                                      .map((line) => line.text)
                                      .join('\n'),
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
                      'Shopping list',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (_items.isEmpty)
                      const Text(
                        'No products with prices could be detected yet.',
                      ),
                    for (final item in _items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(item.name)),
                            const SizedBox(width: 16),
                            Text(item.priceText),
                          ],
                        ),
                      ),
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
                if (Platform.isAndroid || Platform.isLinux)
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Text(
        'Scan or import overlapping photos of a receipt.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}
