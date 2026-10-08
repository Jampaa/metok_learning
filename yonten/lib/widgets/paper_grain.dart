import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Debug switch for the paper texture (spec §4).
class PaperGrainEnabled extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final paperGrainEnabledProvider =
    NotifierProvider<PaperGrainEnabled, bool>(PaperGrainEnabled.new);

/// Tiles `paper-grain.png` over [child] as an 8% multiply overlay.
///
/// Drawn as a foreground paint, so it never receives pointer input.
/// Painting the grain at 8% alpha with BlendMode.multiply gives
/// dst × (0.92 + 0.08 × grain), which is exactly an 8% multiply layer.
class PaperGrain extends ConsumerStatefulWidget {
  const PaperGrain({super.key, required this.child});

  final Widget child;

  static const asset = 'assets/images/paper-grain.png';
  static const opacity = 0.08;

  @override
  ConsumerState<PaperGrain> createState() => _PaperGrainState();
}

class _PaperGrainState extends ConsumerState<PaperGrain> {
  ui.Image? _grain;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await rootBundle.load(PaperGrain.asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _grain = frame.image);
    } catch (_) {
      // Texture is decorative; the app is fine without it.
    }
  }

  @override
  void dispose() {
    _grain?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(paperGrainEnabledProvider);
    final grain = _grain;
    if (!enabled || grain == null) return widget.child;
    return CustomPaint(
      foregroundPainter: _GrainPainter(grain),
      child: widget.child,
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.grain);

  final ui.Image grain;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..blendMode = BlendMode.multiply
      ..color = Color.fromRGBO(0, 0, 0, PaperGrain.opacity)
      ..shader = ImageShader(
        grain,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.grain != grain;
}
