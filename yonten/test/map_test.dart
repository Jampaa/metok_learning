import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yonten/app/app.dart';
import 'package:yonten/data/curriculum_providers.dart';
import 'package:yonten/data/models/progress.dart';
import 'package:yonten/data/repositories/curriculum_repository.dart';
import 'package:yonten/features/map/map_layout.dart';
import 'package:yonten/widgets/motion_scope.dart';

final unit1 = LocalCurriculumRepository.seedChapters;
final ordered = lessonsInOrder(unit1);

void main() {
  group('MapLayout', () {
    test('chapter 1 nodes sit on the spec path points', () {
      final layout = MapLayout.build(unit1, ProgressNotifier.demoStart);
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
      final layout = MapLayout.build(unit1, ProgressNotifier.demoStart);
      final states = layout.nodes.map((n) => n.state).toList();
      expect(states.take(3), everyElement(NodeState.completed));
      expect(states[3], NodeState.active);
      expect(layout.nodes[3].lesson.label, 'ང');
      expect(layout.nodes[4].lesson.isChest, isTrue);
      expect(states.skip(4), everyElement(NodeState.locked));
    });

    test('walked path ends at the active node (256, 388)', () {
      final layout = MapLayout.build(unit1, ProgressNotifier.demoStart);
      final metric = layout.walked.computeMetrics().single;
      final end = metric.getTangentForOffset(metric.length)!.position;
      expect(end.dx, closeTo(256, 0.01));
      expect(end.dy, closeTo(388, 0.01));
      final start = metric.getTangentForOffset(0)!.position;
      expect(start, const Offset(200, 0));
    });

    test('a second chapter repeats the pattern after a banner gap', () {
      final two = [
        ...unit1,
        LocalCurriculumRepository.seedChapters.first.copyForTest('unit2', 2),
      ];
      final layout = MapLayout.build(two, ProgressNotifier.demoStart);
      expect(layout.nodes, hasLength(20));
      expect(layout.banners, hasLength(1));
      final firstOfTwo = layout.nodes[10].center;
      expect(firstOfTwo.dy, 1012 + MapLayout.clusterGap);
      expect(firstOfTwo.dx, MapLayout.waveX[10 % 8]);
    });
  });

  group('ProgressNotifier only moves forward', () {
    late ProviderContainer c;
    setUp(() => c = ProviderContainer());
    tearDown(() => c.dispose());

    MapProgress p() => c.read(progressProvider);
    ProgressNotifier n() => c.read(progressProvider.notifier);

    test('finishing ང makes the chest current, then ཅ', () {
      n().complete('unit1-nga', ordered);
      expect(p().currentLessonId, 'unit1-chest-1');
      n().complete('unit1-chest-1', ordered);
      expect(p().currentLessonId, 'unit1-ca');
      expect(p().completed, containsAll(['unit1-ka', 'unit1-nga', 'unit1-chest-1']));
    });

    test('opening the chest early skips it later, never rewinds', () {
      n().complete('unit1-chest-1', ordered);
      expect(p().currentLessonId, 'unit1-nga');
      n().complete('unit1-nga', ordered);
      expect(p().currentLessonId, 'unit1-ca');
    });

    test('replaying a done lesson changes nothing', () {
      final before = p();
      n().complete('unit1-ka', ordered);
      expect(p(), same(before));
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
    Future<ProviderContainer> pumpMap(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(reducedMotionOverrideProvider.notifier).toggle();
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const YontenApp(status: 'test'),
      ));
      await tester.pumpAndSettle();
      return c;
    }

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

    testWidgets('completed node offers practice', (tester) async {
      await pumpMap(tester);
      await tapNode(tester, 'unit1-ka');
      expect(toastText(tester), "Let's practice ཀ again!");
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('locked node is gentle, not blocked', (tester) async {
      await pumpMap(tester);
      await tapNode(tester, 'unit1-ca');
      expect(toastText(tester), 'Keep going! This one opens after ང.');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('chest opens once, grants the sticker, stays open',
        (tester) async {
      final c = await pumpMap(tester);
      await tapNode(tester, 'unit1-chest-1');
      expect(toastText(tester), contains('Chest opened!'));
      expect(c.read(stickersProvider).map((s) => s.id), ['chorten']);
      expect(c.read(progressProvider).currentLessonId, 'unit1-nga');
      await tester.pump(const Duration(seconds: 3));

      await tapNode(tester, 'unit1-chest-1');
      expect(toastText(tester), contains('This chest is open!'));
      expect(c.read(stickersProvider), hasLength(1));
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('reaching the chest opens it automatically', (tester) async {
      final c = await pumpMap(tester);
      c.read(progressProvider.notifier).complete('unit1-nga', ordered);
      await tester.pumpAndSettle();
      expect(c.read(progressProvider).currentLessonId, 'unit1-ca');
      expect(c.read(stickersProvider).map((s) => s.id), ['chorten']);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('active node opens the scanner', (tester) async {
      await pumpMap(tester);
      await tapNode(tester, 'unit1-nga');
      await tester.pumpAndSettle();
      expect(find.text('Magic Eye'), findsOneWidget);
    });
  });
}
