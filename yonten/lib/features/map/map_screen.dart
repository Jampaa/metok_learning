import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../data/curriculum_providers.dart';
import '../../data/models/curriculum.dart';
import '../../services/audio_service.dart';
import '../../theme/colors.dart';
import '../../theme/motion.dart';
import '../../widgets/level_node.dart';
import '../../widgets/motion_scope.dart';
import '../../widgets/squishable.dart';
import '../../widgets/sticker_toast.dart';
import '../../widgets/yonten_sprite.dart';
import 'map_chest.dart';
import 'map_layout.dart';
import 'sky_band.dart';
import 'start_bubble.dart';
import 'thangka_banner.dart';
import 'trail_painter.dart';

/// Bumped by the shell whenever the child switches to the Map tab, so the
/// map can replay its "opened" moments (Yonten waves, thangka swings).
class MapVisits extends Notifier<int> {
  @override
  int build() => 0;

  void visited() => state++;
}

final mapVisitsProvider = NotifierProvider<MapVisits, int>(MapVisits.new);

/// The Treasure Hunt Map (spec §5): a scrolling, winding trail built from
/// the curriculum and the child's forward-only progress.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _scroll = ScrollController();
  final _yonten = YontenController();
  final _toast = StickerToastController();
  int _swing = 1;
  int _celebrate = 0;
  String? _celebratingChestId;
  bool _initialScrollDone = false;
  double _scale = 1;

  @override
  void dispose() {
    _scroll.dispose();
    _yonten.dispose();
    _toast.dispose();
    super.dispose();
  }

  List<Lesson> get _ordered =>
      lessonsInOrder(ref.read(curriculumProvider).value ?? const []);

  void _onVisit() {
    if (ReducedMotion.of(context)) return;
    _yonten.wave();
    setState(() => _swing++);
  }

  void _onNodeTap(MapNode node, MapNode? active) {
    final lesson = node.lesson;
    switch (node.state) {
      case NodeState.active:
        context.push(Routes.scan);
      case NodeState.completed:
        _toast.show("Let's practice ${lesson.label} again!");
        ref.read(audioServiceProvider).playWord(lesson.wordId);
      case NodeState.locked:
        final after = active != null && !active.lesson.isChest
            ? 'opens after ${active.lesson.label}'
            : 'opens soon';
        _toast.show('Keep going! This one $after.');
    }
  }

  void _onChestTap(MapNode node) {
    if (node.state == NodeState.completed) {
      _toast.show('This chest is open! Your sticker is in your Backpack.');
      return;
    }
    _openChest(node);
  }

  /// Opens a chest: marks it done (forward only), grants its sticker,
  /// and celebrates.
  void _openChest(MapNode node) {
    final lesson = node.lesson;
    ref.read(progressProvider.notifier).complete(lesson.id, _ordered);
    final sticker = lesson.rewardStickerId;
    if (sticker != null) {
      ref.read(stickersProvider.notifier).earn(sticker, fromLessonId: lesson.id);
    }
    setState(() {
      _celebratingChestId = lesson.id;
      _celebrate++;
    });
    _toast.show('Chest opened! A new sticker is in your Backpack.');
    _yonten.play(
      const [YontenPose.crouch, YontenPose.cheerJump, YontenPose.cheerLand],
      frame: const Duration(milliseconds: 240),
    );
  }

  void _scrollToActive(MapLayout layout, double viewport) {
    if (_initialScrollDone || !_scroll.hasClients) return;
    _initialScrollDone = true;
    final active = layout.activeNode;
    if (active == null) return;
    // Keep the sky band in view, scrolling only enough to show the active
    // node with a little room below it.
    final bottom = (MapLayout.skyHeight + active.center.dy + 60) * _scale;
    final target = math.min(
        math.max(0.0, bottom - viewport), _scroll.position.maxScrollExtent);
    _scroll.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mapVisitsProvider, (_, _) => _onVisit());
    final curriculum = ref.watch(curriculumProvider);
    final progress = ref.watch(progressProvider);
    final chapters = curriculum.value ?? const <Chapter>[];
    final layout = MapLayout.build(chapters, progress);

    // Reaching a chest opens it (spec §5 gameplay table).
    final active = layout.activeNode;
    if (active != null && active.lesson.isChest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(progressProvider).currentLessonId == active.lesson.id) {
          _openChest(active);
        }
      });
    }

    return LayoutBuilder(builder: (context, constraints) {
      _scale = constraints.maxWidth / 400;
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToActive(layout, constraints.maxHeight));

      final scene = SizedBox(
        width: 400,
        height: layout.totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: SkyBand(
                chapter: chapters.isEmpty ? null : chapters.first,
                swing: _swing,
                scrollOffset: () =>
                    _scroll.hasClients ? _scroll.offset / _scale : 0,
                onGuidebook: () => _showGuide(chapters),
              ),
            ),
            Positioned(
              left: 0,
              top: MapLayout.skyHeight,
              width: 400,
              height: layout.trailHeight,
              child: _Trail(
                layout: layout,
                yonten: _yonten,
                celebrate: _celebrate,
                celebratingChestId: _celebratingChestId,
                onNodeTap: (n) => _onNodeTap(n, active),
                onChestTap: _onChestTap,
              ),
            ),
          ],
        ),
      );

      return Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: YColors.background,
              child: SingleChildScrollView(
                controller: _scroll,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: layout.totalHeight * _scale,
                  child: FittedBox(
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topLeft,
                    child: scene,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Center(child: StickerToast(controller: _toast)),
          ),
        ],
      );
    });
  }

  void _showGuide(List<Chapter> chapters) {
    if (chapters.isEmpty) return;
    final c = chapters.first;
    final pages = c.workbookPages.length == 2
        ? 'pages ${c.workbookPages[0]}–${c.workbookPages[1]}'
        : 'chapter ${c.workbookChapter}';
    _toast.show('${c.unitLabel} matches your workbook, $pages.');
  }
}

/// The trail and everything on it, in reference px.
class _Trail extends StatelessWidget {
  const _Trail({
    required this.layout,
    required this.yonten,
    required this.celebrate,
    required this.celebratingChestId,
    required this.onNodeTap,
    required this.onChestTap,
  });

  final MapLayout layout;
  final YontenController yonten;
  final int celebrate;
  final String? celebratingChestId;
  final ValueChanged<MapNode> onNodeTap;
  final ValueChanged<MapNode> onChestTap;

  static const _yontenSize = 124.0;

  @override
  Widget build(BuildContext context) {
    final active = layout.activeNode;
    final anchor = active ??
        (layout.nodes.isEmpty ? null : layout.nodes.last);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: TrailPainter(path: layout.path, walked: layout.walked),
          ),
        ),
        for (final s in layout.scenery)
          Positioned.fromRect(
            rect: s.rect,
            child: s.asset == 'prayer-flags'
                ? const _PrayerFlags()
                : Image.asset('assets/images/${s.asset}.webp',
                    fit: BoxFit.contain, excludeFromSemantics: true),
          ),
        for (final b in layout.banners)
          Positioned(
            left: b.topLeft.dx,
            top: b.topLeft.dy,
            child: ThangkaBanner(chapter: b.chapter, width: 140),
          ),
        if (anchor != null)
          Positioned(
            // Spec: (86, 326) beside the active node at (256, 388). Mirror
            // to the other side when the node is on the left of the trail.
            left: anchor.center.dx > 200
                ? anchor.center.dx - 170
                : anchor.center.dx + 46,
            top: anchor.center.dy - 62,
            child: Squishable(
              semanticLabel: 'Yonten. Tap to say hello',
              onTap: yonten.wave,
              child: YontenSprite(
                size: _yontenSize,
                motion: YontenMotion.breathe,
                controller: yonten,
                waveOnMount: true,
              ),
            ),
          ),
        for (final node in layout.nodes) _positionedNode(node),
        if (active != null && !active.lesson.isChest)
          Positioned(
            // Spec: (304, 368) for the node at (256, 388).
            left: active.center.dx > 256
                ? active.center.dx - 48 - StartBubble.size.width
                : active.center.dx + 48,
            top: active.center.dy - 20,
            child: StartBubble(tailRight: active.center.dx > 256),
          ),
      ],
    );
  }

  Widget _positionedNode(MapNode node) {
    final lesson = node.lesson;
    if (lesson.isChest) {
      const size = MapChest.tapArea;
      return Positioned(
        key: ValueKey('node-${lesson.id}'),
        left: node.center.dx - size.width / 2,
        top: node.center.dy - size.height / 2,
        child: MapChest(
          opened: node.state == NodeState.completed,
          celebrate: celebratingChestId == lesson.id ? celebrate : 0,
          onTap: () => onChestTap(node),
        ),
      );
    }
    final look = switch (node.state) {
      NodeState.completed => LevelNodeLook.completed,
      NodeState.active => LevelNodeLook.active,
      NodeState.locked => LevelNodeLook.locked,
    };
    final size = LevelNode.sizeFor(look);
    final status = switch (node.state) {
      NodeState.completed => 'done. Tap to practice again',
      NodeState.active => 'start here',
      NodeState.locked => 'opens soon',
    };
    return Positioned(
      key: ValueKey('node-${lesson.id}'),
      left: node.center.dx - size.width / 2,
      top: node.center.dy - size.height / 2,
      child: LevelNode(
        label: lesson.label,
        look: look,
        semanticLabel: 'Lesson ${lesson.order}, ${lesson.label}, $status',
        onTap: () => onNodeTap(node),
      ),
    );
  }
}

/// Prayer flags sway: skew 0 → −4°, anchored at the top, 3 s loop.
class _PrayerFlags extends StatelessWidget {
  const _PrayerFlags();

  @override
  Widget build(BuildContext context) {
    return LoopBuilder(
      period: YMotion.prayerFlags,
      mirror: true,
      builder: (context, t, child) => Transform(
        alignment: Alignment.topCenter,
        transform: Matrix4.skewX(math.tan(YMotion.prayerFlagsSkewDegrees *
            math.pi /
            180 *
            Curves.easeInOut.transform(t))),
        child: child,
      ),
      child: Image.asset('assets/images/prayer-flags.webp',
          fit: BoxFit.fill, excludeFromSemantics: true),
    );
  }
}
