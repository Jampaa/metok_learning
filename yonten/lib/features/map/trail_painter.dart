import 'package:flutter/rendering.dart';

import '../../theme/colors.dart';

/// The dirt path (spec §5 Trail): a 40 px ink stroke, then a 35 px cream
/// stroke on top, leaving a thin ink edge on both sides. Golden footsteps
/// (#D1A507 dots, 9 px, every 19 px) mark the part already walked.
class TrailPainter extends CustomPainter {
  TrailPainter({required this.path, required this.walked});

  final Path path;
  final Path walked;

  static const inkWidth = 40.0;
  static const creamWidth = 35.0;
  static const stepSize = 9.0;
  static const stepEvery = 19.0;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(
        path,
        stroke
          ..color = YColors.ink
          ..strokeWidth = inkWidth);
    canvas.drawPath(
        path,
        stroke
          ..color = YColors.path
          ..strokeWidth = creamWidth);

    final dot = Paint()..color = YColors.yellowDark;
    for (final metric in walked.computeMetrics()) {
      for (var d = stepEvery / 2; d < metric.length; d += stepEvery) {
        final pos = metric.getTangentForOffset(d)?.position;
        if (pos != null) canvas.drawCircle(pos, stepSize / 2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(TrailPainter old) =>
      old.path != path || old.walked != walked;
}
