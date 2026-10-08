import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/text.dart';
import 'toy_surface.dart';

/// Shows short messages in a white sticker toast that slides up from the
/// bottom (440 ms) and hides after 2.8 s (spec §5, §6).
class StickerToastController extends ChangeNotifier {
  String? _message;
  int _serial = 0;

  String? get message => _message;
  int get serial => _serial;

  void show(String message) {
    _message = message;
    _serial++;
    notifyListeners();
  }
}

class StickerToast extends StatefulWidget {
  const StickerToast({super.key, required this.controller});

  final StickerToastController controller;

  @override
  State<StickerToast> createState() => _StickerToastState();
}

class _StickerToastState extends State<StickerToast> {
  bool _visible = false;
  String _text = '';
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onShow);
  }

  void _onShow() {
    _hide?.cancel();
    setState(() {
      _text = widget.controller.message ?? '';
      _visible = true;
    });
    _hide = Timer(YMotion.toastHold, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    widget.controller.removeListener(_onShow);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_visible,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 1.6),
        duration: YMotion.toast,
        curve: _visible ? YMotion.overshoot : Curves.easeIn,
        child: Semantics(
          liveRegion: true,
          child: ToySurface(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Text.rich(
              YText.mixed(_text, YText.text(17, bold: true)),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
