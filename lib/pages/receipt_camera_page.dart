import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class ReceiptCameraPage extends StatefulWidget {
  const ReceiptCameraPage({super.key});

  @override
  State<ReceiptCameraPage> createState() => _ReceiptCameraPageState();
}

class _ReceiptCameraPageState extends State<ReceiptCameraPage> {
  CameraController? _controller;
  final _captures = <String>[];
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
