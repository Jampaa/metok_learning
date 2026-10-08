import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Debug override so reduced motion can be tested without changing OS
/// settings (toggle in the gallery).
class ReducedMotionOverride extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final reducedMotionOverrideProvider =
    NotifierProvider<ReducedMotionOverride, bool>(ReducedMotionOverride.new);

/// Single source of truth for reduced motion (spec §4): true when the OS
/// asks for it (MediaQuery.disableAnimations) or the debug override is on.
class ReducedMotion extends InheritedWidget {
  const ReducedMotion({super.key, required this.reduced, required super.child});

  final bool reduced;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReducedMotion>()?.reduced ??
      MediaQuery.maybeDisableAnimationsOf(context) ??
      false;

  @override
  bool updateShouldNotify(ReducedMotion old) => old.reduced != reduced;
}

/// Installs [ReducedMotion] at the app root.
class ReducedMotionScope extends ConsumerWidget {
  const ReducedMotionScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduced = ref.watch(reducedMotionOverrideProvider) ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return ReducedMotion(reduced: reduced, child: child);
  }
}

typedef LoopWidgetBuilder = Widget Function(
    BuildContext context, double t, Widget? child);

/// Every looping animation in the app goes through this widget, so reduced
/// motion stops all of them in one place. [t] runs 0 → 1 each [period]
/// (or 0 → 1 → 0 when [mirror] is true). When motion is reduced, the loop
/// stops and [t] rests at [restValue].
///
/// [phase] (0–1) offsets the start, e.g. so butter lamps flicker out of step.
class LoopBuilder extends StatefulWidget {
  const LoopBuilder({
    super.key,
    required this.period,
    required this.builder,
    this.mirror = false,
    this.phase = 0,
    this.restValue = 0,
    this.enabled = true,
    this.child,
  });

  final Duration period;
  final LoopWidgetBuilder builder;
  final bool mirror;
  final double phase;
  final double restValue;

  /// Lets callers pause a loop for their own reasons (e.g. not idle).
  final bool enabled;
  final Widget? child;

  @override
  State<LoopBuilder> createState() => _LoopBuilderState();
}

class _LoopBuilderState extends State<LoopBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle,
  );

  /// With [mirror], one full cycle is forward + reverse, so each half is
  /// half the period.
  Duration get _cycle => widget.mirror ? widget.period ~/ 2 : widget.period;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LoopBuilder old) {
    super.didUpdateWidget(old);
    if (old.period != widget.period || old.mirror != widget.mirror) {
      _controller.duration = _cycle;
      if (_controller.isAnimating) {
        _controller.stop();
        _start();
      }
    }
    _sync();
  }

  void _sync() {
    final run = widget.enabled && !ReducedMotion.of(context);
    if (run && !_controller.isAnimating) {
      _start();
    } else if (!run && _controller.isAnimating) {
      _controller.stop();
      _controller.value = widget.restValue;
    } else if (!run) {
      _controller.value = widget.restValue;
    }
  }

  void _start() {
    if (_controller.value == widget.restValue && widget.phase != 0) {
      _controller.value = widget.phase.clamp(0.0, 1.0);
    }
    _controller.repeat(reverse: widget.mirror);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) =>
          widget.builder(context, _controller.value, child),
    );
  }
}
