import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yonten/data/curriculum_providers.dart';
import 'package:yonten/services/vision_service.dart';
import 'package:yonten/widgets/word_photo.dart';

import 'helpers.dart';

void main() {
  Future<void> openScanner(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Scan').first);
    await tester.pumpAndSettle();
    expect(find.text('Magic Eye'), findsOneWidget);
    expect(find.text("Let's look!"), findsOneWidget);
    expect(find.text("What's in your kitchen?"), findsOneWidget);
  }

  Future<void> shoot(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Take a photo'));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  String speech(WidgetTester tester) => tester
      .widgetList<RichText>(find.byType(RichText))
      .map((r) => r.text.toPlainText())
      .firstWhere(
          (t) => t.contains('find') || t.contains('try again') || t.contains('look') || t.contains('later'),
          orElse: () => '');

  testWidgets('a verified find shows the photo, Tibetan and audio button',
      (tester) async {
    final c = await pumpYonten(tester, scans: [verifiedApple]);
    await openScanner(tester);
    await shoot(tester);

    expect(speech(tester), 'ཡག་པོ་རེད། Great find!');
    expect(find.text('ཀུ་ཤུ'), findsOneWidget);
    expect(find.text('apple'), findsOneWidget);
    expect(find.bySemanticsLabel('Play audio'), findsOneWidget);
    expect(find.byType(WordPhoto), findsOneWidget);
    expect(find.bySemanticsLabel('+10 XP'), findsOneWidget);

    final sub = c.listen(wordsProvider, (_, _) {});
    await tester.pump();
    expect(c.read(wordsProvider).value!.single.photoId, isNotNull);
    sub.close();
  });

  testWidgets('an unverified find never shows Tibetan', (tester) async {
    await pumpYonten(tester, scans: [
      const ScanFound(ScanWord(id: 'whisk', english: 'whisk', tibetan: '', verified: false)),
    ]);
    await openScanner(tester);
    await shoot(tester);
    expect(find.text('whisk'), findsOneWidget);
    expect(find.text("We'll learn this one in Tibetan soon!"), findsOneWidget);
    expect(find.bySemanticsLabel('Play audio'), findsNothing);
  });

  testWidgets('retry is gentle and returns to looking after 2 s',
      (tester) async {
    await pumpYonten(tester, scans: [const ScanRetry()]);
    await openScanner(tester);
    await shoot(tester);
    expect(speech(tester), "Hmm, let's try again!");
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(speech(tester), "Let's look!");
  });

  testWidgets('offline scans are queued with a friendly note', (tester) async {
    await pumpYonten(tester, scans: [const ScanQueued()]);
    await openScanner(tester);
    await shoot(tester);
    expect(find.text('Yonten will check this when we’re back online'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(speech(tester), "Let's look!");
  });

  testWidgets('the shutter after a find starts a new scan', (tester) async {
    await pumpYonten(tester, scans: [verifiedApple]);
    await openScanner(tester);
    await shoot(tester);
    await tester.tap(find.bySemanticsLabel('Scan again'));
    await tester.pumpAndSettle();
    expect(speech(tester), "Let's look!");
  });

  testWidgets('scanning from the active node completes the lesson',
      (tester) async {
    final c = await pumpYonten(tester, demo: true, scans: [verifiedApple]);
    final node = find.byKey(const ValueKey('node-unit1-nga'));
    Scrollable.ensureVisible(tester.element(node), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(node);
    await tester.pumpAndSettle();
    await shoot(tester);
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    // ང done; the chest after it opens itself when reached.
    expect(c.read(progressProvider).isDone('unit1-nga'), isTrue);
    await tester.pump(const Duration(seconds: 3));
  });
}
