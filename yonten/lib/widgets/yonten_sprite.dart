import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/motion.dart';
import 'motion_scope.dart';

/// Every Yonten frame from the image pack (spec §3).
enum YontenPose {
  idle('idle'),
  blink('blink'),
  waveA('wave-a'),
  waveB('wave-b'),
  explore('explore'),
  exploreBlink('explore-blink'),
  crouch('crouch'),
  cheerJump('cheer-jump'),
  cheerLand('cheer-land'),
  think('think'),
  avatar('avatar'),
  avatarBlink('avatar-blink');

  const YontenPose(this.file);

  final String file;

  String get asset => 'assets/images/yonten-$file.webp';

  bool get isAvatar => this == avatar || this == avatarBlink;

  /// The frame shown during a blink, if this pose has one.
  YontenPose? get blinkFrame => switch (this) {
        idle => blink,
        explore => exploreBlink,
        avatar => avatarBlink,
        _ => null,
      };

  static const body = [
    idle, blink, waveA, waveB, explore, exploreBlink,
    crouch, cheerJump, cheerLand, think,
  ];
  static const avatars = [avatar, avatarBlink];
}

/// Decodes every frame up front so pose swaps never flash (spec §3).
Future<void> precacheYonten(BuildContext context) {
  return Future.wait([
    for (final pose in YontenPose.values)
      precacheImage(AssetImage(pose.asset), context),
  ]);
}

/// Whole-image motion layered on top of the frame (spec §6).
enum YontenMotion {
  none,

  /// Idle on the map: scaleY 1 → 1.025, anchored at the bottom, 3 s.
  breathe,

  /// Scanner `looking`: rotate ±3° around (50%, 95%), 2.6 s.
  explore,

  /// Scanner `retry`: head tilts ±3°, 2 s.
  think,
}

/// App-wide blink clock: every 3.5–6 s at random, all Yontens on screen
/// (including the profile avatar) blink together for 140 ms. Stops under
/// reduced motion.
class BlinkClock extends StatefulWidget {
  const BlinkClock({super.key, required this.child});

  final Widget child;

  static bool isBlinking(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_BlinkScope>()
          ?.notifier
          ?.value ??
      false;

  @override
  State<BlinkClock> createState() => _BlinkClockState();
}

class _BlinkClockState extends State<BlinkClock> {
  final _blinking = ValueNotifier(false);
  final _random = math.Random();
  Timer? _timer;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = ReducedMotion.of(context);
    if (reduced == _reduced && (_timer != null || reduced)) return;
    _reduced = reduced;
    _timer?.cancel();
    _blinking.value = false;
    if (!reduced) _scheduleNext();
  }

  void _scheduleNext() {
    final min = YMotion.blinkMin.inMilliseconds;
    final max = YMotion.blinkMax.inMilliseconds;
    final wait = Duration(milliseconds: min + _random.nextInt(max - min));
    _timer = Timer(wait, () {
      _blinking.value = true;
      _timer = Timer(YMotion.blinkHold, () {
        _blinking.value = false;
        _scheduleNext();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _blinking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _BlinkScope(notifier: _blinking, child: widget.child);
}

class _BlinkScope extends InheritedNotifier<ValueNotifier<bool>> {
  const _BlinkScope({required super.notifier, required super.child});
}

/// Plays frame sequences on a [YontenSprite] (wave now, celebrate later).
class YontenController extends ChangeNotifier {
  _Sequence? _pending;

  /// Frames a, b, a, b, a (190 ms each) after 250 ms, then back to the
  /// base pose (spec §6).
  void wave() => play(
        const [
          YontenPose.waveA, YontenPose.waveB, YontenPose.waveA,
          YontenPose.waveB, YontenPose.waveA,
        ],
        frame: YMotion.waveFrame,
        delay: YMotion.waveDelay,
      );

  /// Shows [frames] in order, [frame] apart, then returns to the base pose
  /// unless [holdLast] is true.
  void play(
    List<YontenPose> frames, {
    required Duration frame,
    Duration delay = Duration.zero,
    bool holdLast = false,
  }) {
    _pending = _Sequence(frames, frame, delay, holdLast);
    notifyListeners();
  }

  /// Drops any running sequence and returns to the base pose.
  void reset() {
    _pending = const _Sequence([], Duration.zero, Duration.zero, false);
    notifyListeners();
  }

  _Sequence? _take() {
    final s = _pending;
    _pending = null;
    return s;
  }
}

class _Sequence {
  const _Sequence(this.frames, this.frame, this.delay, this.holdLast);

  final List<YontenPose> frames;
  final Duration frame;
  final Duration delay;
  final bool holdLast;
}

/// Yonten, with every frame of the current set stacked and only one shown,
/// so frames are preloaded and swaps never flicker (spec §6).
class YontenSprite extends StatefulWidget {
  const YontenSprite({
    super.key,
    this.pose = YontenPose.idle,
    this.size = 124,
    this.motion = YontenMotion.none,
    this.controller,
    this.waveOnMount = false,
  });

  /// Base pose shown when no sequence is playing.
  final YontenPose pose;
  final double size;
  final YontenMotion motion;
  final YontenController? controller;
  final bool waveOnMount;

  @override
  State<YontenSprite> createState() => _YontenSpriteState();
}

class _YontenSpriteState extends State<YontenSprite> {
  YontenController? _ownController;
  YontenPose? _override;
  final _timers = <Timer>[];

  YontenController get _controller =>
      widget.controller ?? (_ownController ??= YontenController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onRequest);
    if (widget.waveOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !ReducedMotion.of(context)) _controller.wave();
      });
    }
  }

  @override
  void didUpdateWidget(YontenSprite old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _ownController)?.removeListener(_onRequest);
      _controller.addListener(_onRequest);
    }
  }

  void _onRequest() {
    final seq = _controller._take();
    if (seq == null) return;
    _cancelTimers();
    setState(() => _override = null);
    if (seq.frames.isEmpty) return;

    // Under reduced motion, skip straight to where the sequence ends.
    if (ReducedMotion.of(context)) {
      if (seq.holdLast) setState(() => _override = seq.frames.last);
      return;
    }
    for (var i = 0; i < seq.frames.length; i++) {
      _timers.add(Timer(seq.delay + seq.frame * i, () {
        if (mounted) setState(() => _override = seq.frames[i]);
      }));
    }
    if (!seq.holdLast) {
      _timers.add(Timer(seq.delay + seq.frame * seq.frames.length, () {
        if (mounted) setState(() => _override = null);
      }));
    }
  }

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  @override
  void dispose() {
    _cancelTimers();
    _controller.removeListener(_onRequest);
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = _override ?? widget.pose;
    final blinking = BlinkClock.isBlinking(context);
    final shown = blinking ? (base.blinkFrame ?? base) : base;
    final frames = base.isAvatar ? YontenPose.avatars : YontenPose.body;

    final stack = SizedBox.square(
      dimension: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final pose in frames)
            Offstage(
              offstage: pose != shown,
              child: Image.asset(
                pose.asset,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                excludeFromSemantics: true,
              ),
            ),
        ],
      ),
    );

    // Sequences (wave, celebrate) replace the idle motion while they play.
    final motion = _override == null ? widget.motion : YontenMotion.none;
    return switch (motion) {
      YontenMotion.none => stack,
      YontenMotion.breathe => LoopBuilder(
          period: YMotion.breathe,
          mirror: true,
          child: stack,
          builder: (context, t, child) => Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(
              1,
              1 + (YMotion.breatheScaleY - 1) * Curves.easeInOut.transform(t),
              1,
            ),
            child: child,
          ),
        ),
      YontenMotion.explore => _Sway(
          period: YMotion.explore,
          degrees: YMotion.exploreDegrees,
          origin: const Alignment(0, 0.9),
          child: stack,
        ),
      YontenMotion.think => _Sway(
          period: YMotion.think,
          degrees: YMotion.thinkDegrees,
          origin: const Alignment(0, 0.2), // (50%, 60%): around the neck
          child: stack,
        ),
    };
  }
}

/// Rotates ±[degrees] around [origin] on a sine loop.
class _Sway extends StatelessWidget {
  const _Sway({
    required this.period,
    required this.degrees,
    required this.origin,
    required this.child,
  });

  final Duration period;
  final double degrees;
  final Alignment origin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LoopBuilder(
      period: period,
      child: child,
      builder: (context, t, child) => Transform.rotate(
        alignment: origin,
        angle: degrees * math.pi / 180 * math.sin(2 * math.pi * t),
        child: child,
      ),
    );
  }
}
