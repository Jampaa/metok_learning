import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/curriculum.dart';
import '../../theme/colors.dart';
import '../../theme/motion.dart';
import '../../theme/text.dart';
import '../../widgets/motion_scope.dart';

/// A hanging thangka with live chapter text on its empty panel
/// (spec §5 Sky band). Designed at 200 × 300; [width] scales it.
///
/// Bump [swing] to play the hanging-cloth swing: −12° → 6° → −3.5° → 1°
/// → −1.5° over 900 ms, pivoting at the top center. It rests at −1.5°.
class ThangkaBanner extends StatefulWidget {
  const ThangkaBanner({
    super.key,
    required this.chapter,
    this.width = 200,
    this.swing = 0,
  });

  final Chapter chapter;
  final double width;
  final int swing;

  @override
  State<ThangkaBanner> createState() => _ThangkaBannerState();
}

class _ThangkaBannerState extends State<ThangkaBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swing = AnimationController(
    vsync: this,
    duration: YMotion.thangkaSwing,
    value: 1,
  );

  static final _angle = TweenSequence<double>([
    for (var i = 0; i < YMotion.thangkaKeyframes.length - 1; i++)
      TweenSequenceItem(
        tween: Tween(
          begin: YMotion.thangkaKeyframes[i],
          end: YMotion.thangkaKeyframes[i + 1],
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
  ]);

  @override
  void initState() {
    super.initState();
    if (widget.swing != 0) _play();
  }

  @override
  void didUpdateWidget(ThangkaBanner old) {
    super.didUpdateWidget(old);
    if (widget.swing != old.swing) _play();
  }

  void _play() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ReducedMotion.of(context)) {
        _swing.value = 1;
      } else {
        _swing.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _swing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chapter;
    // Panel inside the 200 × 300 frame: left 23, top 43, 122 × 180.
    final panel = Positioned(
      left: 23,
      top: 43,
      width: 122,
      height: 180,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(c.unitLabel,
              style: YText.text(13, color: YColors.thangkaCaption)),
          const SizedBox(height: 4),
          Text(c.title,
              textAlign: TextAlign.center,
              style: YText.heading(23, color: YColors.white)),
          const SizedBox(height: 6),
          Text(c.titleTibetan,
              textAlign: TextAlign.center,
              style: YText.tibetan(21, color: YColors.yellow)),
        ],
      ),
    );

    return Semantics(
      label: '${c.unitLabel}: ${c.title}',
      child: SizedBox(
        width: widget.width,
        height: widget.width * 1.5,
        child: FittedBox(
          child: AnimatedBuilder(
            animation: _swing,
            builder: (context, child) => Transform.rotate(
              alignment: Alignment.topCenter,
              angle: _angle.transform(_swing.value) * math.pi / 180,
              child: child,
            ),
            child: SizedBox(
              width: 200,
              height: 300,
              child: Stack(children: [
                Image.asset('assets/images/thangka-frame.webp',
                    width: 200, height: 300, excludeFromSemantics: true),
                panel,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
