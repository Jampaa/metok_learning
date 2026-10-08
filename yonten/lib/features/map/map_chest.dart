import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/motion.dart';
import '../../widgets/confetti.dart';
import '../../widgets/motion_scope.dart';
import '../../widgets/squishable.dart';

/// Milestone chest (spec §5 Trail): a closed 86 × 71 chest that wiggles,
/// or an open 98 × 110 chest, both bottom-aligned in a 96 × 84 tap area.
/// Opening pops (scale .6 → 1.12 → 1) with confetti.
class MapChest extends StatefulWidget {
  const MapChest({
    super.key,
    required this.opened,
    required this.onTap,
    this.celebrate = 0,
  });

  final bool opened;
  final VoidCallback onTap;

  /// Bump to play the pop and confetti (when this chest was just opened).
  final int celebrate;

  static const tapArea = Size(96, 84);

  @override
  State<MapChest> createState() => _MapChestState();
}

class _MapChestState extends State<MapChest>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );

  static final _popScale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60),
    TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40),
  ]);

  @override
  void didUpdateWidget(MapChest old) {
    super.didUpdateWidget(old);
    if (widget.celebrate != old.celebrate && widget.celebrate != 0) {
      if (ReducedMotion.of(context)) {
        _pop.value = 1;
      } else {
        _pop.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.opened
        ? AnimatedBuilder(
            animation: _pop,
            builder: (context, child) => Transform.scale(
              alignment: Alignment.bottomCenter,
              scale: _popScale.transform(_pop.value),
              child: child,
            ),
            child: Image.asset('assets/images/chest-open.webp',
                width: 98, height: 110, excludeFromSemantics: true),
          )
        : LoopBuilder(
            period: YMotion.chestLoop,
            builder: (context, t, child) {
              // Still for 86% of the loop, then a quick fading wiggle.
              final tail = 1 - YMotion.chestWiggleTail;
              final angle = t < tail
                  ? 0.0
                  : YMotion.chestWiggleDegrees *
                      math.sin((t - tail) / YMotion.chestWiggleTail * 4 * math.pi) *
                      (1 - (t - tail) / YMotion.chestWiggleTail);
              return Transform.rotate(
                alignment: Alignment.bottomCenter,
                angle: angle * math.pi / 180,
                child: child,
              );
            },
            child: Image.asset('assets/images/chest-closed.webp',
                width: 86, height: 71, excludeFromSemantics: true),
          );

    return SizedBox.fromSize(
      size: MapChest.tapArea,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: Squishable(
              semanticLabel: widget.opened
                  ? 'Treasure chest, opened'
                  : 'Treasure chest. Tap to open',
              onTap: widget.onTap,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: OverflowBox(
                  alignment: Alignment.bottomCenter,
                  maxHeight: 120,
                  child: image,
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: MapChest.tapArea.width / 2,
            child: ConfettiBurst(trigger: widget.celebrate, width: 150),
          ),
        ],
      ),
    );
  }
}
