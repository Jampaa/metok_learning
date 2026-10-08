import 'dart:ui';

import '../../data/models/curriculum.dart';
import '../../data/models/progress.dart';

enum NodeState { completed, active, locked }

class MapNode {
  const MapNode({
    required this.lesson,
    required this.chapter,
    required this.center,
    required this.state,
  });

  final Lesson lesson;
  final Chapter chapter;

  /// Center in trail coordinates (reference px, y = 0 at the hills).
  final Offset center;
  final NodeState state;
}

/// A chapter thangka hanging at the start of a cluster after the first.
/// (Chapter 1's thangka lives in the sky band.)
class ClusterBanner {
  const ClusterBanner(this.chapter, this.topLeft);

  final Chapter chapter;
  final Offset topLeft;
}

/// Decorations placed relative to each cluster's first node.
class Scenery {
  const Scenery(this.asset, this.rect);

  final String asset;
  final Rect rect;
}

/// Everything the map needs to draw, in reference px (400 wide).
///
/// The node pattern reproduces the spec's SVG path exactly: nodes 104 px
/// apart vertically, x following 200, 256, 284, 256, 200, 144, 116, 144
/// and repeating, joined by cubic curves whose control points sit half
/// the vertical gap above and below. Chapter 1 gives
/// `M200 0 L200 76 C200 128 256 128 256 180 ... L256 1090`.
class MapLayout {
  MapLayout._({
    required this.nodes,
    required this.path,
    required this.walked,
    required this.banners,
    required this.scenery,
    required this.trailHeight,
  });

  static const skyHeight = 340.0;
  static const firstNodeY = 76.0;
  static const nodeGap = 104.0;
  static const tailLength = 78.0;

  /// Extra vertical room before each later cluster, for its thangka.
  static const clusterGap = 320.0;
  static const waveX = [200.0, 256.0, 284.0, 256.0, 200.0, 144.0, 116.0, 144.0];

  final List<MapNode> nodes;

  /// The whole dirt path.
  final Path path;

  /// The part already walked: from the start to the active node (or to
  /// the last node, once everything is done). Golden footsteps go here.
  final Path walked;
  final List<ClusterBanner> banners;
  final List<Scenery> scenery;
  final double trailHeight;

  double get totalHeight => skyHeight + trailHeight;

  MapNode? get activeNode {
    for (final n in nodes) {
      if (n.state == NodeState.active) return n;
    }
    return null;
  }

  factory MapLayout.build(List<Chapter> chapters, MapProgress progress) {
    final nodes = <MapNode>[];
    final banners = <ClusterBanner>[];
    final scenery = <Scenery>[];
    var y = firstNodeY;
    var i = 0;

    for (var c = 0; c < chapters.length; c++) {
      final chapter = chapters[c];
      if (chapter.lessons.isEmpty) continue;
      if (nodes.isNotEmpty) {
        y += clusterGap;
        // Hang the banner on the side away from the next node.
        final nextX = waveX[i % waveX.length];
        final bannerX = nextX >= 200 ? 24.0 : 236.0;
        banners.add(ClusterBanner(chapter, Offset(bannerX, y - clusterGap + 40)));
      }
      final first = Offset(waveX[i % waveX.length], y);
      // Spec positions, relative to chapter 1's first node (200, 76).
      if (chapter.lessons.length >= 7) {
        scenery.add(Scenery('prayer-flags',
            Rect.fromLTWH(first.dx - 10, first.dy + 472, 230, 54)));
      }
      if (chapter.lessons.length >= 8) {
        scenery.add(Scenery('chorten',
            Rect.fromLTWH(first.dx + 102, first.dy + 596, 72, 128)));
      }
      for (final lesson in chapter.lessons) {
        final state = progress.isDone(lesson.id)
            ? NodeState.completed
            : lesson.id == progress.currentLessonId
                ? NodeState.active
                : NodeState.locked;
        nodes.add(MapNode(
          lesson: lesson,
          chapter: chapter,
          center: Offset(waveX[i % waveX.length], y),
          state: state,
        ));
        i++;
        y += nodeGap;
      }
      y -= nodeGap;
    }

    final path = Path();
    final walked = Path();
    final points = [for (final n in nodes) n.center];
    if (points.isEmpty) {
      return MapLayout._(
        nodes: nodes,
        path: path,
        walked: walked,
        banners: banners,
        scenery: scenery,
        trailHeight: firstNodeY + tailLength,
      );
    }

    final activeIndex = nodes.indexWhere((n) => n.state == NodeState.active);
    final walkedUntil = activeIndex >= 0
        ? activeIndex
        : (nodes.every((n) => n.state == NodeState.completed)
            ? nodes.length - 1
            : -1);

    for (final p in [path, walked]) {
      p.moveTo(points.first.dx, 0);
      p.lineTo(points.first.dx, points.first.dy);
    }
    for (var k = 1; k < points.length; k++) {
      final a = points[k - 1];
      final b = points[k];
      final half = (b.dy - a.dy) / 2;
      void curve(Path p) =>
          p.cubicTo(a.dx, a.dy + half, b.dx, b.dy - half, b.dx, b.dy);
      curve(path);
      if (k <= walkedUntil) curve(walked);
    }
    final last = points.last;
    final trailHeight = last.dy + tailLength;
    path.lineTo(last.dx, trailHeight);

    return MapLayout._(
      nodes: nodes,
      path: path,
      walked: walkedUntil >= 0 ? walked : Path(),
      banners: banners,
      scenery: scenery,
      trailHeight: trailHeight,
    );
  }
}
