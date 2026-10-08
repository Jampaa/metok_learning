import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/motion.dart';

/// Quest progress bar (spec §5 Quests): 18 px tall, ink outline, sky-blue
/// fill, a tick mark at every step.
class SegmentedProgress extends StatelessWidget {
  const SegmentedProgress({
    super.key,
    required this.value,
    required this.target,
    this.height = 18,
  }) : assert(target > 0);

  final int value;
  final int target;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fraction = (value / target).clamp(0.0, 1.0);
    return Semantics(
      label: '$value of $target',
      child: SizedBox(
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: fraction),
          duration: YMotion.stickerPop,
          curve: YMotion.gentle,
          builder: (context, t, _) => CustomPaint(
            painter: _SegmentPainter(fraction: t, steps: _visibleSteps),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }

  /// Large targets (e.g. 30 XP) would draw unreadable ticks; cap at 10.
  int get _visibleSteps => target <= 10 ? target : 10;
}

class _SegmentPainter extends CustomPainter {
  _SegmentPainter({required this.fraction, required this.steps});

  final double fraction;
  final int steps;

  static const _stroke = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final outer = RRect.fromRectAndRadius(Offset.zero & size, radius);
    final inner = outer.deflate(_stroke / 2);

    canvas.drawRRect(inner, Paint()..color = YColors.white);

    canvas.save();
    canvas.clipRRect(inner);
    if (fraction > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width * fraction, size.height),
        Paint()..color = YColors.sky,
      );
    }
    final tick = Paint()
      ..color = YColors.ink
      ..strokeWidth = 1.5;
    for (var i = 1; i < steps; i++) {
      final x = size.width * i / steps;
      canvas.drawLine(Offset(x, size.height * 0.25),
          Offset(x, size.height * 0.75), tick);
    }
    canvas.restore();

    canvas.drawRRect(
      inner,
      Paint()
        ..color = YColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke,
    );
  }

  @override
  bool shouldRepaint(_SegmentPainter old) =>
      old.fraction != fraction || old.steps != steps;
}
