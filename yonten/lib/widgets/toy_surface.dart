import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/motion.dart';

/// The tactile "toy" look shared by ToyButton and ToyCard (spec §4):
/// a 2 px outline with a 4 px bottom edge.
///
/// When [pressed], the face moves down 2 px and the bottom edge shrinks to
/// 2 px. The top padding grows by the same 2 px, so the total height stays
/// constant and nothing around the widget moves.
class ToySurface extends StatelessWidget {
  const ToySurface({
    super.key,
    required this.child,
    this.color = YColors.white,
    this.edgeColor = YColors.ink,
    this.radius = 16,
    this.circle = false,
    this.pressed = false,
    this.border = 2,
    this.bottomEdge = 4,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final Color color;
  final Color edgeColor;
  final double radius;

  /// Oval shape (level nodes, shutter, avatars). Fills its box.
  final bool circle;
  final bool pressed;
  final double border;
  final double bottomEdge;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final drop = bottomEdge - border;
    final edge = pressed ? border : bottomEdge;
    final innerRadius = (radius - border).clamp(0.0, double.infinity);

    return AnimatedPadding(
      duration: YMotion.press,
      curve: Curves.easeOut,
      padding: EdgeInsets.only(top: pressed ? drop : 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: edgeColor,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(radius),
        ),
        child: AnimatedPadding(
          duration: YMotion.press,
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(border, border, border, edge),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: circle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius:
                  circle ? null : BorderRadius.circular(innerRadius),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
