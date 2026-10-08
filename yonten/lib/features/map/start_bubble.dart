import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/motion.dart';
import '../../theme/text.dart';
import '../../widgets/motion_scope.dart';

/// Speech bubble beside the active node, floating 4 px up and down
/// (2.4 s). Its tail points at the node: left by default, right when
/// [tailRight] is true.
class StartBubble extends StatelessWidget {
  const StartBubble({super.key, this.text = 'Start!', this.tailRight = false});

  final String text;
  final bool tailRight;

  static const size = Size(80, 42);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LoopBuilder(
        period: YMotion.startBubble,
        mirror: true,
        builder: (context, t, child) => Transform.translate(
          offset: Offset(
              0, -YMotion.startBubbleFloat * Curves.easeInOut.transform(t)),
          child: child,
        ),
        child: CustomPaint(
          painter: _BubblePainter(tailRight: tailRight),
          child: SizedBox.fromSize(
            size: size,
            child: Padding(
              padding: EdgeInsets.only(
                  left: tailRight ? 0 : 10, right: tailRight ? 10 : 0),
              child: Center(child: Text(text, style: YText.label(16))),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.tailRight});

  final bool tailRight;

  @override
  void paint(Canvas canvas, Size size) {
    const tail = 10.0;
    final body = RRect.fromLTRBR(
      tailRight ? 0 : tail,
      0,
      tailRight ? size.width - tail : size.width,
      size.height,
      const Radius.circular(14),
    );
    final mid = size.height * 0.55;
    final tip = tailRight
        ? (Path()
          ..moveTo(size.width - tail - 1, mid - 8)
          ..lineTo(size.width, mid + 4)
          ..lineTo(size.width - tail - 1, mid + 6))
        : (Path()
          ..moveTo(tail + 1, mid - 8)
          ..lineTo(0, mid + 4)
          ..lineTo(tail + 1, mid + 6));
    final shape = Path.combine(
        PathOperation.union, Path()..addRRect(body), tip..close());
    canvas.drawPath(shape, Paint()..color = YColors.white);
    canvas.drawPath(
      shape,
      Paint()
        ..color = YColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.tailRight != tailRight;
}
