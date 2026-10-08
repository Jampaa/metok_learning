import 'package:flutter/material.dart';

import '../theme/motion.dart';
import 'motion_scope.dart';

/// One-shot pop: scales [from] → 1 with a little overshoot after [delay].
/// Replays when [trigger] changes. Under reduced motion it just appears.
class PopIn extends StatefulWidget {
  const PopIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = YMotion.stickerPop,
    this.from = 0.0,
    this.trigger = 0,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double from;
  final int trigger;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _play();
    }
  }

  @override
  void didUpdateWidget(PopIn old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _play();
  }

  Future<void> _play() async {
    if (ReducedMotion.of(context)) {
      _c.value = 1;
      return;
    }
    _c.value = 0;
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
      if (!mounted) return;
    }
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = YMotion.overshoot.transform(_c.value);
        return Opacity(
          opacity: _c.value.clamp(0.0, 1.0),
          child: Transform.scale(scale: widget.from + (1 - widget.from) * t, child: child),
        );
      },
    );
  }
}
