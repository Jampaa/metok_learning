import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../data/curriculum_providers.dart';
import '../../data/models/curriculum.dart';
import '../../services/capture_service.dart';
import '../../services/image_shrink.dart';
import '../../services/providers.dart';
import '../../services/scan_flow.dart';
import '../../services/vision_service.dart';
import '../../theme/colors.dart';
import '../../theme/motion.dart';
import '../../theme/text.dart';
import '../../widgets/confetti.dart';
import '../../widgets/ink_icons.dart';
import '../../widgets/motion_scope.dart';
import '../../widgets/toy_button.dart';
import '../../widgets/yonten_sprite.dart';
import 'result_card.dart';
import 'viewfinder.dart';

enum ScanState { looking, thinking, found, retry, queued }

/// Magic Eye (spec §5 Scanner). Opened from the nav's Scan button, or from
/// the map's active node with [lessonId], in which case a find completes
/// that lesson.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key, this.lessonId});

  final String? lessonId;

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

/// Celebrate steps (spec §6): pose, scale (x, y), lift, start time.
const _celebrate = [
  (YontenPose.crouch, 1.06, 0.90, 0.0, Duration.zero),
  (YontenPose.cheerJump, 0.96, 1.06, -30.0, Duration(milliseconds: 150)),
  (YontenPose.cheerLand, 1.08, 0.92, 0.0, Duration(milliseconds: 520)),
  (YontenPose.cheerLand, 1.0, 1.0, 0.0, Duration(milliseconds: 700)),
];

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  late final CaptureSource _camera = ref.read(captureSourceFactoryProvider)();
  ScanState _state = ScanState.looking;
  ScanResult? _result;
  int _step = -1;
  int _confetti = 0;
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    _camera.addListener(_onCamera);
    _camera.init();
  }

  void _onCamera() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cancelTimers();
    _camera.removeListener(_onCamera);
    _camera.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void _after(Duration d, VoidCallback f) =>
      _timers.add(Timer(d, () => mounted ? f() : null));

  void _reset() {
    _cancelTimers();
    setState(() {
      _state = ScanState.looking;
      _result = null;
      _step = -1;
    });
  }

  Future<void> _onShutter() async {
    switch (_state) {
      case ScanState.thinking:
        return;
      case ScanState.found:
      case ScanState.queued:
      case ScanState.retry:
        _reset();
        return;
      case ScanState.looking:
        break;
    }
    final Uint8List? raw;
    try {
      raw = await _camera.capture();
    } catch (_) {
      _show(ScanState.retry);
      return;
    }
    if (raw == null || !mounted) return;
    setState(() => _state = ScanState.thinking);
    await WidgetsBinding.instance.endOfFrame;
    final jpeg = shrinkJpeg(raw);

    final chapters = await ref.read(curriculumProvider.future);
    final ordered = lessonsInOrder(chapters);
    final lesson = widget.lessonId == null
        ? null
        : ordered.where((l) => l.id == widget.lessonId).firstOrNull;
    final result = await ref
        .read(scanFlowProvider)
        .scan(jpeg, lesson: _isOpen(lesson) ? lesson : null, ordered: ordered);
    if (!mounted) return;
    _result = result;
    switch (result.outcome) {
      case ScanFound():
        _show(ScanState.found);
      case ScanRetry():
        _show(ScanState.retry);
      case ScanQueued():
        _show(ScanState.queued);
    }
  }

  /// Only the map's current lesson can be completed by a scan.
  bool _isOpen(Lesson? lesson) =>
      lesson != null && !ref.read(progressProvider).isDone(lesson.id);

  void _show(ScanState s) {
    _cancelTimers();
    setState(() => _state = s);
    switch (s) {
      case ScanState.found:
        if (ReducedMotion.of(context)) {
          setState(() => _step = _celebrate.length - 1);
        } else {
          for (var i = 0; i < _celebrate.length; i++) {
            _after(_celebrate[i].$5, () {
              setState(() {
                _step = i;
                if (i == 1) _confetti++;
              });
            });
          }
        }
      case ScanState.retry:
        _after(YMotion.retryReturn, _reset);
      case ScanState.queued:
        _after(const Duration(milliseconds: 2600), _reset);
      case ScanState.looking:
      case ScanState.thinking:
        break;
    }
  }

  String get _speech => switch (_state) {
    ScanState.looking => "Let's look!",
    ScanState.thinking => 'Let me see…',
    ScanState.found => 'ཡག་པོ་རེད། Great find!',
    ScanState.retry => "Hmm, let's try again!",
    ScanState.queued => "I'll check it later!",
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              _header(context),
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: _viewfinder(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _controls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final flash = _camera.hasFlash;
    return Row(
      children: [
        _roundButton(
          label: 'Close',
          onTap: () =>
              context.canPop() ? context.pop() : context.go(Routes.map),
          child: const InkIcon(InkGlyph.close, size: 28),
        ),
        Expanded(
          child: Column(
            children: [
              Text('Magic Eye', style: YText.heading(26)),
              Text(
                'མིག་འཕྲུལ།',
                style: YText.tibetan(18, color: YColors.maroon),
              ),
            ],
          ),
        ),
        _roundButton(
          label: flash
              ? (_camera.flashOn ? 'Flash on' : 'Flash off')
              : 'Flash is not available here',
          color: _camera.flashOn ? YColors.yellow : YColors.white,
          muted: !flash,
          onTap: () => _camera.setFlash(!_camera.flashOn),
          child: Image.asset(
            'assets/images/icon-flash.webp',
            width: 30,
            height: 30,
            excludeFromSemantics: true,
          ),
        ),
      ],
    );
  }

  Widget _viewfinder() {
    final result = _result;
    final found =
        _state == ScanState.found &&
        result != null &&
        result.outcome is ScanFound;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Viewfinder(
            preview:
                _camera.preview() ??
                (_state == ScanState.looking
                    ? const NoCameraHint()
                    : const SizedBox.shrink()),
            scanning:
                _state == ScanState.looking || _state == ScanState.thinking,
            fast: _state == ScanState.thinking,
            overlay: [
              if (_state == ScanState.looking)
                const Positioned(
                  top: 28,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ViewfinderSticker(text: "What's in your kitchen?"),
                  ),
                ),
              if (_state == ScanState.queued)
                const Positioned(
                  left: 24,
                  right: 24,
                  bottom: 40,
                  child: Center(
                    child: ViewfinderSticker(
                      text: 'Yonten will check this when we’re back online',
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (found)
          Positioned(
            left: 10,
            right: 10,
            bottom: 18,
            child: ResultCard(
              word: (result.outcome as ScanFound).word,
              photo: result.photo,
              onPlay: () {
                final w = (result.outcome as ScanFound).word;
                ref.read(audioServiceProvider).playWord(w.id, url: w.audioUrl);
              },
            ),
          ),
      ],
    );
  }

  Widget _controls() {
    return SizedBox(
      height: 168,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _yonten()),
          _shutter(),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _roundButton(
                  label: 'Switch camera',
                  muted: !_camera.canSwitch,
                  onTap: _camera.switchCamera,
                  child: const InkIcon(InkGlyph.switchCamera, size: 30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _yonten() {
    final celebrating = _state == ScanState.found && _step >= 0;
    final step = celebrating ? _celebrate[_step] : null;
    final pose =
        step?.$1 ??
        switch (_state) {
          ScanState.retry => YontenPose.think,
          ScanState.queued => YontenPose.idle,
          ScanState.found => YontenPose.crouch,
          _ => YontenPose.explore,
        };
    final motion = switch (_state) {
      ScanState.looking || ScanState.thinking => YontenMotion.explore,
      ScanState.retry => YontenMotion.think,
      _ => YontenMotion.none,
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // The bubble shrinks to fit rather than pushing Yonten off the row.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Semantics(
              liveRegion: true,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: YColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: YColors.ink, width: 2),
                ),
                child: Text.rich(
                  YText.mixed(_speech, YText.label(14)),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            TweenAnimationBuilder<_Pose>(
              tween: _PoseTween(
                end: _Pose(step?.$2 ?? 1, step?.$3 ?? 1, step?.$4 ?? 0),
              ),
              duration: YMotion.celebrateTransition,
              builder: (context, p, child) => Transform.translate(
                offset: Offset(0, p.lift),
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.diagonal3Values(p.sx, p.sy, 1),
                  child: child,
                ),
              ),
              child: YontenSprite(pose: pose, motion: motion, size: 112),
            ),
            Positioned(
              top: 20,
              child: ConfettiBurst(trigger: _confetti, width: 140),
            ),
          ],
        ),
      ],
    );
  }

  Widget _shutter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 6, right: 6),
      child: SizedBox(
        width: 76,
        height: 72,
        child: ToyButton(
          semanticLabel: _state == ScanState.looking
              ? 'Take a photo'
              : 'Scan again',
          color: YColors.white,
          circle: true,
          border: 3,
          padding: EdgeInsets.zero,
          onPressed: _state == ScanState.thinking ? null : _onShutter,
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: YColors.sky,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundButton({
    required String label,
    required VoidCallback onTap,
    required Widget child,
    Color color = YColors.white,
    bool muted = false,
  }) => SizedBox.square(
    dimension: 52,
    child: ToyButton(
      semanticLabel: label,
      color: color,
      circle: true,
      muted: muted,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: child,
    ),
  );
}

class _Pose {
  const _Pose(this.sx, this.sy, this.lift);

  final double sx;
  final double sy;
  final double lift;
}

class _PoseTween extends Tween<_Pose> {
  _PoseTween({required super.end}) : super(begin: end);

  @override
  _Pose lerp(double t) {
    final a = begin ?? end!, b = end!;
    double l(double x, double y) => x + (y - x) * t;
    return _Pose(l(a.sx, b.sx), l(a.sy, b.sy), l(a.lift, b.lift));
  }
}
