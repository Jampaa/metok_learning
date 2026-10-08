import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/motion.dart';
import 'motion_scope.dart';

/// One-shot burst of 7 outlined paper bits that fall 130 px and spin
/// (~1.4 s, spec §6). Bump [trigger] to fire again. Does nothing under
/// reduced motion. Never takes pointer input.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, required this.trigger, this.width = 120});

  /// Fires whenever this changes to a new non-zero value.
  final int trigger;

  /// Horizontal spread of the bits.
  final double width;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: YMotion.confetti);
  final _random = math.Random();
  List<_Bit> _bits = const [];

  static const _colors = [
    YColors.sky, YColors.maroon, YColors.yellow, YColors.white,
    YColors.sky, YColors.yellow, YColors.maroon,
  ];

  @override
  void didUpdateWidget(ConfettiBurst old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger != 0) _fire();
  }

  void _fire() {
    if (ReducedMotion.of(context)) return;
    _bits = [
      for (var i = 0; i < YMotion.confettiPieces; i++)
        _Bit(
          x: (i / (YMotion.confettiPieces - 1) - 0.5) * widget.width +
              (_random.nextDouble() - 0.5) * 14,
          rise: 18 + _random.nextDouble() * 22,
          spin: (_random.nextBool() ? 1 : -1) * (1.5 + _random.nextDouble() * 2),
          color: _colors[i % _colors.length],
          delay: _random.nextDouble() * 0.12,
        ),
    ];
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (!_controller.isAnimating) return const SizedBox.shrink();
          return CustomPaint(
            painter: _ConfettiPainter(_bits, _controller.value),
            size: Size.zero,
          );
        },
      ),
    );
  }
}

class _Bit {
  const _Bit({
    required this.x,
    required this.rise,
    required this.spin,
    required this.color,
    required this.delay,
  });

  final double x;
  final double rise;
  final double spin;
  final Color color;
  final double delay;
}

/// Paints relative to its own origin: bits pop up a little, then fall.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits, this.t);

  final List<_Bit> bits;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = YColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final b in bits) {
      final p = ((t - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
      if (p <= 0) continue;
      // Up by `rise` in the first 25%, then down to +130.
      final y = p < 0.25
          ? -b.rise * Curves.easeOut.transform(p / 0.25)
          : -b.rise +
              (YMotion.confettiFall + b.rise) *
                  Curves.easeIn.transform((p - 0.25) / 0.75);
      final opacity = p > 0.8 ? (1 - p) / 0.2 : 1.0;
      canvas.save();
      canvas.translate(b.x * (0.4 + 0.6 * p), y);
      canvas.rotate(b.spin * p * math.pi);
      final rect = Rect.fromCenter(center: Offset.zero, width: 10, height: 6);
      canvas.drawRect(rect, Paint()..color = b.color.withValues(alpha: opacity));
      canvas.drawRect(
          rect, outline..color = YColors.ink.withValues(alpha: opacity));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
