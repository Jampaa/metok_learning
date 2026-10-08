import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'toy_surface.dart';

/// Static toy card: same outline as ToyButton, plus an optional
/// hand-placed tilt (spec §4 allows −3° to +2°).
class ToyCard extends StatelessWidget {
  const ToyCard({
    super.key,
    required this.child,
    this.color = YColors.white,
    this.tiltDegrees = 0,
    this.radius = 16,
    this.padding = const EdgeInsets.all(16),
  }) : assert(tiltDegrees >= -3 && tiltDegrees <= 2);

  final Widget child;
  final Color color;
  final double tiltDegrees;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final card = ToySurface(
      color: color,
      radius: radius,
      padding: padding,
      child: child,
    );
    if (tiltDegrees == 0) return card;
    return Transform.rotate(angle: tiltDegrees * math.pi / 180, child: card);
  }
}
