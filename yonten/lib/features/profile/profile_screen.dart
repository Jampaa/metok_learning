import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/tab_visits.dart';
import '../../data/curriculum_providers.dart';
import '../../data/day_providers.dart';
import '../../data/models/user_profile.dart';
import '../../data/rules.dart';
import '../../theme/colors.dart';
import '../../theme/motion.dart';
import '../../theme/text.dart';
import '../../widgets/ink_icons.dart';
import '../../widgets/motion_scope.dart';
import '../../widgets/toy_card.dart';
import '../../widgets/toy_surface.dart';
import '../../widgets/yonten_sprite.dart';

/// Me (spec §5): avatar, name and level, four stats, this week's butter
/// lamps, and the hold-to-unlock Parent Settings button.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider).value ?? const UserProfile();
    final today = ref.watch(todayProvider);
    final visit = ref.watch(tabVisitProvider(3));
    final streak = GameRules.visibleStreak(p.streak, DateTime.now());

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          const Center(child: _Avatar()),
          const SizedBox(height: 10),
          Center(child: Text(p.displayName, style: YText.heading(32))),
          const SizedBox(height: 8),
          Center(child: _LevelRibbon(level: p.level)),
          const SizedBox(height: 20),
          _StatsGrid(p: p, streak: streak),
          const SizedBox(height: 20),
          _ThisWeek(
            activeDates: p.activeDates,
            today: today,
            streak: streak,
            visit: visit,
          ),
          const SizedBox(height: 22),
          HoldToUnlock(
            label: 'Parent Settings (Hold to unlock)',
            onUnlocked: () => context.push(Routes.parents),
          ),
        ],
      ),
    );
  }
}

/// 132 px yellow ring, sky-tint inner circle, Yonten's avatar (blinking
/// with every other Yonten on screen).
class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 132,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: YColors.yellow,
        shape: BoxShape.circle,
        border: Border.all(color: YColors.ink, width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: YColors.skyTint,
          shape: BoxShape.circle,
          border: Border.all(color: YColors.ink, width: 2),
        ),
        child: ClipOval(
          child: Semantics(
            label: 'Yonten',
            child: const YontenSprite(pose: YontenPose.avatar, size: 112),
          ),
        ),
      ),
    );
  }
}

/// Notched maroon ribbon: a yellow star and "Level N Explorer".
class _LevelRibbon extends StatelessWidget {
  const _LevelRibbon({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _RibbonPainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 8, 30, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const InkIcon(InkGlyph.star, size: 24),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Level $level Explorer',
                  style: YText.label(18, color: YColors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const notch = 14.0;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w - notch, h / 2)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(notch, h / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = YColors.maroon);
    canvas.drawPath(
      path,
      Paint()
        ..color = YColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => false;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.p, required this.streak});

  final UserProfile p;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Stat(
        'Total Words',
        p.stats.words,
        YColors.skyTint,
        const InkIcon(InkGlyph.book, size: 32),
      ),
      _Stat(
        'Current Streak',
        streak,
        YColors.yellowTint,
        Image.asset(
          'assets/images/icon-flame.webp',
          width: 32,
          height: 32,
          excludeFromSemantics: true,
        ),
      ),
      _Stat(
        'Scavenger Hunts',
        p.stats.hunts,
        YColors.maroonTint,
        const InkIcon(InkGlyph.magnifier, size: 32),
      ),
      _Stat(
        'Lessons Done',
        p.stats.lessons,
        YColors.slateTint,
        const InkIcon(InkGlyph.pecha, size: 32),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 14.0;
        final w = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final t in tiles) SizedBox(width: w, height: 112, child: t),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color, this.icon);

  final String label;
  final int value;
  final Color color;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: ToySurface(
        color: color,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                icon,
                const Spacer(),
                Text('$value', style: YText.heading(30)),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: YText.text(15, bold: true, color: YColors.mutedStrong),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "This week": seven butter lamps, Monday to Sunday (spec §5).
class _ThisWeek extends StatelessWidget {
  const _ThisWeek({
    required this.activeDates,
    required this.today,
    required this.streak,
    required this.visit,
  });

  final List<String> activeDates;
  final String today;
  final int streak;
  final int visit;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.parse(today);
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final active = activeDates.toSet();
    return ToyCard(
      tiltDegrees: -0.8,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('This week', style: YText.heading(20))),
              Text(
                streak == 1 ? '1-day streak!' : '$streak-day streak!',
                style: YText.label(18, color: YColors.maroon),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                Builder(
                  builder: (context) {
                    final day = dateKey(
                      DateTime(monday.year, monday.month, monday.day + i),
                    );
                    final isToday = day == today;
                    final lit = active.contains(day);
                    return Semantics(
                      container: true,
                      label:
                          '${_letters[i]}: ${lit
                              ? 'played'
                              : isToday
                              ? 'not yet today'
                              : 'no lamp'}',
                      excludeSemantics: true,
                      child: Column(
                        children: [
                          ButterLamp(
                            lit: lit,
                            phase: i / 7,
                            lightUp: isToday && lit ? visit + 1 : 0,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _letters[i],
                            style: YText.label(
                              14,
                              color: isToday
                                  ? YColors.maroon
                                  : YColors.inactiveLabel,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A 34 × 60 butter lamp. Lit: base plus a flickering flame (scale and
/// rotate around (50%, 32%), 1.5 s, each lamp at its own [phase]). Unlit:
/// base only, grayscale at 35% opacity. A non-zero [lightUp] plays today's
/// "lights up" pop (0 → 1.25 → 1, 520 ms after 450 ms) once per value.
class ButterLamp extends StatefulWidget {
  const ButterLamp({
    super.key,
    required this.lit,
    this.phase = 0,
    this.lightUp = 0,
  });

  final bool lit;
  final double phase;
  final int lightUp;

  @override
  State<ButterLamp> createState() => _ButterLampState();
}

class _ButterLampState extends State<ButterLamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _light = AnimationController(
    vsync: this,
    duration: YMotion.lampLight,
    value: 1,
  );

  static final _pop = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.25,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 65,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.25,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 35,
    ),
  ]);

  static const _greyscale = ColorFilter.matrix([
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  // Flame base: 50% across, 32% down.
  static const _flameOrigin = Alignment(0, -0.36);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.lightUp != 0 &&
        _light.value == 1 &&
        _light.status != AnimationStatus.forward) {
      _play();
    }
  }

  @override
  void didUpdateWidget(ButterLamp old) {
    super.didUpdateWidget(old);
    if (widget.lightUp != old.lightUp && widget.lightUp != 0) _play();
  }

  Future<void> _play() async {
    if (ReducedMotion.of(context)) return;
    _light.value = 0;
    await Future<void>.delayed(YMotion.lampLightDelay);
    if (mounted) _light.forward(from: 0);
  }

  @override
  void dispose() {
    _light.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const base = Image(
      image: AssetImage('assets/images/lamp-base.webp'),
      width: 34,
      height: 60,
      fit: BoxFit.contain,
    );
    if (!widget.lit) {
      return const Opacity(
        opacity: 0.35,
        child: ColorFiltered(colorFilter: _greyscale, child: base),
      );
    }
    final flame = Image.asset(
      'assets/images/lamp-flame.webp',
      width: 34,
      height: 60,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
    return SizedBox(
      width: 34,
      height: 60,
      child: Stack(
        children: [
          base,
          AnimatedBuilder(
            animation: _light,
            child: LoopBuilder(
              period: YMotion.lampFlicker,
              phase: widget.phase,
              child: flame,
              builder: (context, t, child) {
                final a = 2 * math.pi * t;
                return Transform(
                  alignment: _flameOrigin,
                  transform: Matrix4.identity()
                    ..rotateZ(3 * math.pi / 180 * math.sin(a))
                    ..scaleByDouble(
                      1 + 0.04 * math.sin(a * 2),
                      1 + 0.08 * math.sin(a * 1.5),
                      1,
                      1,
                    ),
                  child: child,
                );
              },
            ),
            builder: (context, child) => Transform.scale(
              alignment: _flameOrigin,
              scale: _pop.transform(_light.value),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gray button that unlocks only after being held for 1.5 s (spec §5).
/// A gray fill grows across it while held; letting go early cancels.
class HoldToUnlock extends StatefulWidget {
  const HoldToUnlock({
    super.key,
    required this.label,
    required this.onUnlocked,
  });

  final String label;
  final VoidCallback onUnlocked;

  @override
  State<HoldToUnlock> createState() => _HoldToUnlockState();
}

class _HoldToUnlockState extends State<HoldToUnlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: YMotion.parentHold)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) {
            _hold.value = 0;
            widget.onUnlocked();
          }
        });

  Offset _start = Offset.zero;

  void _down() => _hold.forward(from: 0);
  void _cancel() {
    if (_hold.status != AnimationStatus.completed) _hold.reverse();
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: '${widget.label}. Press and hold.',
      // Screen readers get a long-press action instead of a timed hold.
      onLongPress: widget.onUnlocked,
      excludeSemantics: true,
      // Raw pointer events: gesture recognizers would hand a long hold to
      // the long-press recognizer at 0.5 s and cancel the tap.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          _start = e.position;
          _down();
        },
        onPointerMove: (e) {
          // Moving the finger (e.g. to scroll) cancels the hold.
          if ((e.position - _start).distance > kTouchSlop) _cancel();
        },
        onPointerUp: (_) => _cancel(),
        onPointerCancel: (_) => _cancel(),
        child: ToySurface(
          color: YColors.disabledFill,
          edgeColor: YColors.disabledBorder,
          child: SizedBox(
            height: 52,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _hold,
                    builder: (context, _) => FractionallySizedBox(
                      widthFactor: _hold.value,
                      heightFactor: 1,
                      child: const ColoredBox(color: YColors.disabledBorder),
                    ),
                  ),
                  Center(
                    child: Text(
                      widget.label,
                      style: YText.label(16, color: YColors.mutedStrong),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
