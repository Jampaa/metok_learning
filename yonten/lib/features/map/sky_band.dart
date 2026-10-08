import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/curriculum.dart';
import '../../theme/colors.dart';
import '../../theme/motion.dart';
import '../../widgets/ink_icons.dart';
import '../../widgets/motion_scope.dart';
import '../../widgets/toy_button.dart';
import 'map_layout.dart';
import 'thangka_banner.dart';

/// The 340 px sky band at the top of the map (spec §5), back to front:
/// cloud-2, mountains (parallax), hills, cloud-1, chapter 1's thangka,
/// guidebook button. Everything is in reference px.
class SkyBand extends StatelessWidget {
  const SkyBand({
    super.key,
    required this.chapter,
    required this.scrollOffset,
    required this.swing,
    required this.onGuidebook,
  });

  final Chapter? chapter;

  /// Map scroll offset in reference px, for the mountain parallax.
  final ValueGetter<double> scrollOffset;
  final int swing;
  final VoidCallback onGuidebook;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      height: MapLayout.skyHeight,
      child: ClipRect(
        child: ColoredBox(
          color: YColors.skyTint,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 236,
                top: 124,
                child: _Drift(
                  period: YMotion.cloudB,
                  direction: -1,
                  child: _img('cloud-2', 90, 56),
                ),
              ),
              Positioned(
                left: 0,
                bottom: 46,
                child: _Parallax(
                  offset: scrollOffset,
                  child: _img('map-mountains', 400, 135),
                ),
              ),
              Positioned(left: 0, bottom: 0, child: _img('map-hills', 400, 67)),
              Positioned(
                right: 16,
                top: 62,
                child: _Drift(
                  period: YMotion.cloudA,
                  direction: 1,
                  child: _img('cloud-1', 130, 78),
                ),
              ),
              if (chapter != null)
                Positioned(
                  left: 16,
                  top: 12,
                  child: ThangkaBanner(chapter: chapter!, swing: swing),
                ),
              Positioned(
                right: 18,
                top: 232,
                child: SizedBox.square(
                  dimension: 52,
                  child: ToyButton(
                    semanticLabel: 'Guidebook',
                    color: YColors.white,
                    padding: EdgeInsets.zero,
                    onPressed: onGuidebook,
                    child: const InkIcon(InkGlyph.guidebook, size: 32),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _img(String name, double w, double h) => Image.asset(
        'assets/images/$name.webp',
        width: w,
        height: h,
        fit: BoxFit.fill,
        excludeFromSemantics: true,
      );
}

/// Clouds drift 20 px sideways and back.
class _Drift extends StatelessWidget {
  const _Drift({
    required this.period,
    required this.direction,
    required this.child,
  });

  final Duration period;
  final double direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LoopBuilder(
      period: period,
      mirror: true,
      child: child,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(
            direction * YMotion.cloudDrift * Curves.easeInOut.transform(t), 0),
        child: child,
      ),
    );
  }
}

/// Mountains move at 35% of the scroll speed, capped at 340 px.
class _Parallax extends StatelessWidget {
  const _Parallax({required this.offset, required this.child});

  final ValueGetter<double> offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return child;
    return AnimatedBuilder(
      animation: scrollable.position,
      child: child,
      builder: (context, child) {
        final dy = math.min(
            math.max(offset(), 0) * YMotion.parallaxFactor,
            YMotion.parallaxCap);
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
    );
  }
}
