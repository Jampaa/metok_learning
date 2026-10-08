import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/motion.dart';
import '../../theme/text.dart';
import '../../widgets/motion_scope.dart';

/// The Magic Eye viewfinder (spec §5 Scanner): #2D3142, radius 24, the live
/// camera preview, four 46 px sky-blue corner brackets (7 px, radius 18),
/// and a scan line sweeping 260 px while looking or thinking.
class Viewfinder extends StatelessWidget {
  const Viewfinder({
    super.key,
    required this.preview,
    required this.scanning,
    required this.fast,
    this.overlay = const [],
  });

  /// Live camera, or a hint when there isn't one.
  final Widget preview;
  final bool scanning;

  /// Thinking: the line speeds up (1.2 s instead of 2.8 s).
  final bool fast;
  final List<Widget> overlay;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: YColors.ink,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            ClipRect(child: preview),
            const IgnorePointer(
              child: CustomPaint(painter: _BracketsPainter()),
            ),
            if (scanning)
              IgnorePointer(
                child: LoopBuilder(
                  period: fast ? YMotion.scanLineThinking : YMotion.scanLine,
                  mirror: true,
                  restValue: 0.5,
                  builder: (context, t, child) => Align(
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        (Curves.easeInOut.transform(t) - 0.5) *
                            YMotion.scanLineTravel,
                      ),
                      child: child,
                    ),
                  ),
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 26),
                    decoration: BoxDecoration(
                      color: YColors.sky,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: YColors.ink, width: 1.5),
                    ),
                  ),
                ),
              ),
            ...overlay,
          ],
        ),
      ),
    );
  }
}

/// Shown in the viewfinder when there's no live camera (picker mode).
class NoCameraHint extends StatelessWidget {
  const NoCameraHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Tap the big button to take a photo!',
          textAlign: TextAlign.center,
          style: YText.label(20, color: YColors.white),
        ),
      ),
    );
  }
}

class _BracketsPainter extends CustomPainter {
  const _BracketsPainter();

  static const arm = 46.0;
  static const thick = 7.0;
  static const radius = 18.0;
  static const inset = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = YColors.sky
      ..style = PaintingStyle.stroke
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.round;
    final l = inset + thick / 2, t = inset + thick / 2;
    final r = size.width - l, b = size.height - t;
    // Each corner: an L with a rounded bend, drawn as one path.
    for (final (x, y, sx, sy) in [
      (l, t, 1.0, 1.0),
      (r, t, -1.0, 1.0),
      (l, b, 1.0, -1.0),
      (r, b, -1.0, -1.0),
    ]) {
      final path = Path()
        ..moveTo(x, y + sy * arm)
        ..lineTo(x, y + sy * radius)
        ..arcToPoint(
          Offset(x + sx * radius, y),
          radius: const Radius.circular(radius),
          clockwise: sx * sy > 0,
        )
        ..lineTo(x + sx * arm, y);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_BracketsPainter old) => false;
}

/// A tilted white sticker with a short message, used inside the viewfinder.
class ViewfinderSticker extends StatelessWidget {
  const ViewfinderSticker({
    super.key,
    required this.text,
    this.tiltDegrees = -2,
  });

  final String text;
  final double tiltDegrees;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tiltDegrees * math.pi / 180,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: YColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: YColors.ink, width: 2),
        ),
        child: Text(text, textAlign: TextAlign.center, style: YText.label(17)),
      ),
    );
  }
}
