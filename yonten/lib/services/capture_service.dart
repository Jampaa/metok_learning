import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

/// Where photos come from: a live camera when there is one, otherwise the
/// system picker (spec §2: camera, with image_picker as a fallback).
abstract class CaptureSource extends ChangeNotifier {
  Future<void> init();

  /// True when there's a live preview to show.
  bool get live;
  bool get canSwitch;
  bool get hasFlash;
  bool get flashOn;

  /// Live preview, or null when there isn't one (picker mode).
  Widget? preview();

  /// Returns JPEG bytes, or null if the child cancelled.
  Future<Uint8List?> capture();
  Future<void> switchCamera();
  Future<void> setFlash(bool on);
}

/// Live camera via the `camera` plugin; drops to the picker if no camera
/// is available or the child (or browser) denies permission.
class CameraCapture extends CaptureSource {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _index = 0;
  bool _flash = false;
  final _picker = PickerCapture();

  @override
  bool get live => _controller?.value.isInitialized ?? false;

  @override
  bool get canSwitch => _cameras.length > 1;

  // Browsers don't expose the torch.
  @override
  bool get hasFlash => live && !kIsWeb;

  @override
  bool get flashOn => _flash;

  @override
  Future<void> init() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      _index = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_index < 0) _index = 0;
      await _open();
    } catch (e) {
      debugPrint('Yonten: camera unavailable, using the picker ($e)');
      _controller = null;
    }
    notifyListeners();
  }

  Future<void> _open() async {
    final old = _controller;
    _controller = null;
    notifyListeners();
    await old?.dispose();
    final c = CameraController(
      _cameras[_index],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await c.initialize();
    _controller = c;
    _flash = false;
  }

  @override
  Widget? preview() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return null;
    return CameraPreview(c);
  }

  @override
  Future<Uint8List?> capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return _picker.capture();
    final file = await c.takePicture();
    return file.readAsBytes();
  }

  @override
  Future<void> switchCamera() async {
    if (!canSwitch) return;
    _index = (_index + 1) % _cameras.length;
    try {
      await _open();
    } catch (_) {}
    notifyListeners();
  }

  @override
  Future<void> setFlash(bool on) async {
    final c = _controller;
    if (c == null || !hasFlash) return;
    try {
      await c.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      _flash = on;
    } catch (_) {
      _flash = false;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

/// No live preview: the shutter opens the system camera or photo picker.
class PickerCapture extends CaptureSource {
  final _picker = ImagePicker();

  @override
  Future<void> init() async {}

  @override
  bool get live => false;
  @override
  bool get canSwitch => false;
  @override
  bool get hasFlash => false;
  @override
  bool get flashOn => false;

  @override
  Widget? preview() => null;

  @override
  Future<Uint8List?> capture() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 82,
    );
    return file?.readAsBytes();
  }

  @override
  Future<void> switchCamera() async {}
  @override
  Future<void> setFlash(bool on) async {}
}
