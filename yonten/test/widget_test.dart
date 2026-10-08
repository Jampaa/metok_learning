import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yonten/widgets/motion_scope.dart';
import 'package:yonten/widgets/stat_pills.dart';
import 'package:yonten/widgets/toy_button.dart';
import 'package:yonten/widgets/toy_surface.dart';
import 'package:yonten/widgets/yonten_sprite.dart';

import 'helpers.dart';

Future<void> pumpApp(WidgetTester tester) => pumpYonten(tester, demo: true);

/// The single frame that is currently on stage.
String shownFrame(WidgetTester tester) {
  final visible = tester
      .widgetList<Offstage>(find.descendant(
        of: find.byType(YontenSprite).first,
        matching: find.byType(Offstage),
      ))
      .where((o) => !o.offstage)
      .toList();
  expect(visible, hasLength(1));
  final image = (visible.single.child! as Image).image as AssetImage;
  return image.assetName;
}

void main() {
  testWidgets('opens on the map with the nav and pills', (tester) async {
    await pumpApp(tester);
    expect(find.byKey(const ValueKey('node-unit1-nga')), findsOneWidget);
    for (final label in ['Map', 'Backpack', 'Scan', 'Quests', 'Me']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(StatPills), findsOneWidget);
  });

  testWidgets('tabs switch screens; pills only on Map and Backpack',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Backpack'));
    await tester.pumpAndSettle();
    expect(find.text('My Backpack'), findsOneWidget);
    expect(find.byType(StatPills), findsOneWidget);

    await tester.tap(find.text('Quests'));
    await tester.pumpAndSettle();
    expect(find.text('Daily Quests'), findsOneWidget);
    expect(find.byType(StatPills), findsNothing);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.byType(StatPills), findsNothing);
  });

  testWidgets('Scan opens the scanner full screen and close returns',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Scan').first);
    await tester.pumpAndSettle();
    expect(find.text('Magic Eye'), findsOneWidget);
    expect(find.text('Map'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('node-unit1-nga')), findsOneWidget);
  });

  testWidgets('wave plays a, b, a, b, a then returns to idle', (tester) async {
    final controller = YontenController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ReducedMotion(
        reduced: false,
        child: Center(child: YontenSprite(controller: controller)),
      ),
    ));
    expect(shownFrame(tester), YontenPose.idle.asset);

    controller.wave();
    await tester.pump();
    expect(shownFrame(tester), YontenPose.idle.asset);

    const expected = ['wave-a', 'wave-b', 'wave-a', 'wave-b', 'wave-a'];
    await tester.pump(const Duration(milliseconds: 250));
    for (final frame in expected) {
      await tester.pump();
      expect(shownFrame(tester), 'assets/images/yonten-$frame.webp');
      await tester.pump(const Duration(milliseconds: 190));
    }
    await tester.pump();
    expect(shownFrame(tester), YontenPose.idle.asset);
  });

  testWidgets('blink clock swaps idle to blink for 140 ms', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ReducedMotion(
        reduced: false,
        child: BlinkClock(child: Center(child: YontenSprite())),
      ),
    ));
    var sawBlink = false;
    for (var ms = 0; ms <= 6200 && !sawBlink; ms += 20) {
      await tester.pump(const Duration(milliseconds: 20));
      sawBlink = shownFrame(tester) == YontenPose.blink.asset;
    }
    expect(sawBlink, isTrue);
    await tester.pump(const Duration(milliseconds: 160));
    expect(shownFrame(tester), YontenPose.idle.asset);
  });

  testWidgets('reduced motion: no blinking and loops at rest', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ReducedMotion(
        reduced: true,
        child: BlinkClock(
          child: Center(child: YontenSprite(motion: YontenMotion.breathe)),
        ),
      ),
    ));
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(shownFrame(tester), YontenPose.idle.asset);
    }
    // Nothing is animating, so the tree settles immediately.
    await tester.pumpAndSettle();
  });

  testWidgets('ToyButton keeps its height when pressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: ToyButton(
          semanticLabel: 'Go',
          label: 'Go',
          onPressed: () => taps++,
        ),
      ),
    ));
    final before = tester.getSize(find.byType(ToySurface));
    final face = find.text('Go');
    final faceTopBefore = tester.getTopLeft(face).dy;

    final gesture = await tester.startGesture(tester.getCenter(face));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ToySurface)), before);
    expect(tester.getTopLeft(face).dy, faceTopBefore + 2);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.getTopLeft(face).dy, faceTopBefore);
  });
}
