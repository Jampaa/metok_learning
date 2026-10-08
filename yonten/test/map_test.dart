import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yonten/data/curriculum_providers.dart';
import 'package:yonten/data/local_store.dart';
import 'package:yonten/data/models/progress.dart';
import 'package:yonten/data/repositories/curriculum_repository.dart';
import 'package:yonten/data/repositories/user_data_repository.dart';
import 'package:yonten/features/map/map_layout.dart';

import 'helpers.dart';

void main() {
  final unit1 = loadUnit1();
  final ordered = lessonsInOrder(unit1);

  group('MapLayout', () {
    test('chapter 1 nodes sit on the spec path points', () {
      final layout = MapLayout.build(unit1, demoProgress);
      expect(
        layout.nodes.map((n) => n.center).toList(),
        const [
          Offset(200, 76), Offset(256, 180), Offset(284, 284),
          Offset(256, 388), Offset(200, 492), Offset(144, 596),
          Offset(116, 700), Offset(144, 804), Offset(200, 908),
          Offset(256, 1012),
        ],
      );
      expect(layout.trailHeight, 1090);
      expect(layout.totalHeight, 340 + 1090);
    });

    test('demo states: 3 done, ང active, chest 5th, rest locked', () {
      final layout = MapLayout.build(unit1, demoProgress);
      final states = layout.nodes.map((n) => n.state).toList();
      expect(states.take(3), everyElement(NodeState.completed));
      expect(states[3], NodeState.active);
      expect(layout.nodes[3].lesson.label, 'ང');
      expect(layout.nodes[4].lesson.isChest, isTrue);
      expect(states.skip(4), everyElement(NodeState.locked));
    });

    test('a new child has ཀ active and no footsteps beyond it', () {
      final layout = MapLayout.build(unit1, MapProgress.start);
      expect(layout.activeNode!.lesson.label, 'ཀ');
      final metric = layout.walked.computeMetrics().single;
      expect(metric.length, closeTo(76, 0.01));
    });

    test('walked path ends at the active node (256, 388)', () {
      final layout = MapLayout.build(unit1, demoProgress);
      final metric = layout.walked.computeMetrics().single;
      final end = metric.getTangentForOffset(metric.length)!.position;
      expect(end.dx, closeTo(256, 0.01));
      expect(end.dy, closeTo(388, 0.01));
      expect(metric.getTangentForOffset(0)!.position, const Offset(200, 0));
    });

    test('a second chapter repeats the pattern after a banner gap', () {
      final two = [...unit1, unit1.first.copyForTest('unit2', 2)];
      final layout = MapLayout.build(two, demoProgress);
      expect(layout.nodes, hasLength(20));
      expect(layout.banners, hasLength(1));
      final firstOfTwo = layout.nodes[10].center;
      expect(firstOfTwo.dy, 1012 + MapLayout.clusterGap);
      expect(firstOfTwo.dx, MapLayout.waveX[10 % 8]);
    });
  });

  test('lettersWithChests puts a chest at every 5th node', () {
    final lessons = CurriculumConfig.lettersWithChests('u', [
      for (var i = 0; i < 9; i++) ('l$i', 'x'),
    ]);
    expect(lessons.where((l) => l.isChest).map((l) => l.order), [5, 10]);
    expect(lessons, hasLength(11));
  });

  group('map screen', () {
    Future<void> tapNode(WidgetTester tester, String id) async {
      final node = find.byKey(ValueKey('node-$id'));
      // Center it, so it isn't under the pills at the top.
      Scrollable.ensureVisible(tester.element(node), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(node);
      await tester.pump();
    }

    String toastText(WidgetTester tester) => tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .firstWhere((t) => t.contains('!') && t.length > 12,
            orElse: () => '');

    /// Nothing on screen watches stickers yet (Backpack is Phase 7), so
    /// subscribe, let the stream emit, then read.
    Future<List<EarnedSticker>> stickers(
        WidgetTester tester, ProviderContainer c) async {
      final sub = c.listen(stickersProvider, (_, _) {});
      await tester.pump();
      sub.close();
      return c.read(stickersProvider).value ?? const [];
    }

    Future<void> letToastHide(WidgetTester tester) =>
        tester.pump(const Duration(seconds: 3));

    testWidgets('a new child starts with ཀ active', (tester) async {
      final c = await pumpYonten(tester);
      expect(c.read(progressProvider).resolveCurrent([for (final l in ordered) l.id]),
          'unit1-ka');
      await tapNode(tester, 'unit1-kha');
      expect(toastText(tester), 'Keep going! This one opens after ཀ.');
      await letToastHide(tester);
    });

    testWidgets('completed node offers practice', (tester) async {
      await pumpYonten(tester, demo: true);
      await tapNode(tester, 'unit1-ka');
      expect(toastText(tester), "Let's practice ཀ again!");
      await letToastHide(tester);
    });

    testWidgets('locked node is gentle, not blocked', (tester) async {
      await pumpYonten(tester, demo: true);
      await tapNode(tester, 'unit1-ca');
      expect(toastText(tester), 'Keep going! This one opens after ང.');
      await letToastHide(tester);
    });

    testWidgets('chest opens once, grants the sticker, stays open',
        (tester) async {
      final c = await pumpYonten(tester, demo: true);
      await tapNode(tester, 'unit1-chest-1');
      await tester.pumpAndSettle();
      expect(toastText(tester), contains('Chest opened!'));
      expect((await stickers(tester, c)).map((s) => s.id), ['chorten']);
      expect(c.read(progressProvider).currentLessonId, 'unit1-nga');
      await letToastHide(tester);

      await tapNode(tester, 'unit1-chest-1');
      expect(toastText(tester), contains('This chest is open!'));
      expect(await stickers(tester, c), hasLength(1));
      await letToastHide(tester);
    });

    testWidgets('reaching the chest opens it automatically', (tester) async {
      final c = await pumpYonten(tester, demo: true);
      final nga = ordered.firstWhere((l) => l.id == 'unit1-nga');
      await c.read(userDataProvider).completeLesson(nga, ordered);
      await tester.pumpAndSettle();
      expect(c.read(progressProvider).currentLessonId, 'unit1-ca');
      expect((await stickers(tester, c)).map((s) => s.id), ['chorten']);
      await letToastHide(tester);
    });

    testWidgets('progress survives an app restart', (tester) async {
      final store = MemoryStore();
      var c = await pumpYonten(tester, store: store, demo: true);
      final nga = ordered.firstWhere((l) => l.id == 'unit1-nga');
      await c.read(userDataProvider).completeLesson(nga, ordered);
      await tester.pumpAndSettle();
      await letToastHide(tester);

      // Tear the app down and start it again on the same device store.
      await tester.pumpWidget(const SizedBox());
      c = await pumpYonten(tester, store: store);
      expect(c.read(progressProvider).currentLessonId, 'unit1-ca');
      expect(find.byKey(const ValueKey('node-unit1-ca')), findsOneWidget);
    });

    testWidgets('active node opens the scanner', (tester) async {
      await pumpYonten(tester, demo: true);
      await tapNode(tester, 'unit1-nga');
      await tester.pumpAndSettle();
      expect(find.text('Magic Eye'), findsOneWidget);
    });
  });
}
