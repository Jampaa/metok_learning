import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yonten/data/curriculum_providers.dart';
import 'package:yonten/data/local_store.dart';
import 'package:yonten/data/models/word.dart';
import 'package:yonten/data/repositories/local_user_data.dart';
import 'package:yonten/features/backpack/backpack_screen.dart';
import 'package:yonten/features/profile/profile_screen.dart';
import 'package:yonten/widgets/word_photo.dart';

import 'helpers.dart';

void main() {
  FoundWord word(String id, {bool verified = false, String tibetan = ''}) => FoundWord(
      id: id, english: id, tibetan: tibetan, verified: verified,
      photoId: 'p-$id', foundAt: DateTime(2026, 10, 9));

  group('Backpack', () {
    testWidgets('shows found words with the child\'s photos, newest first',
        (tester) async {
      final store = MemoryStore();
      final repo = LocalUserData(store);
      await repo.recordScan(word('cup').copyWith());
      await repo.recordScan(FoundWord(
          id: 'apple', english: 'apple', tibetan: 'ཀུ་ཤུ', verified: true,
          photoId: 'p-apple', foundAt: DateTime(2026, 10, 10)));
      await pumpYonten(tester, store: store);
      await openTab(tester, 'Backpack');

      final cards = tester.widgetList<WordCard>(find.byType(WordCard)).toList();
      expect(cards.map((c) => c.word.id), ['apple', 'cup']);
      expect(find.byType(WordPhoto), findsNWidgets(2));
      expect(find.text('ཀུ་ཤུ'), findsOneWidget); // verified
      expect(find.text('cup'), findsOneWidget); // unverified: English only
      expect(find.text('0 of 3 · from map chests'), findsOneWidget);
    });

    testWidgets('tapping a verified card plays it; unverified stays quiet',
        (tester) async {
      final store = MemoryStore();
      final repo = LocalUserData(store);
      await repo.recordScan(word('cup'));
      await repo.recordScan(word('sun', verified: true, tibetan: 'ཉི་མ'));
      final audio = RecordingAudio();
      await pumpYonten(tester, store: store, audio: audio);
      await openTab(tester, 'Backpack');
      await tester.tap(find.byWidgetPredicate((w) => w is WordCard && w.word.id == 'sun'));
      await tester.tap(find.byWidgetPredicate((w) => w is WordCard && w.word.id == 'cup'));
      await tester.pumpAndSettle();
      expect(audio.played, ['sun']);
    });

    testWidgets('a chest sticker fills a slot', (tester) async {
      final c = await pumpYonten(tester, demo: true);
      final chest = lessonsInOrder(loadUnit1()).firstWhere((l) => l.isChest);
      await c.read(userDataProvider).completeLesson(chest, lessonsInOrder(loadUnit1()));
      await tester.pump(const Duration(seconds: 3));
      await openTab(tester, 'Backpack');
      expect(find.text('1 of 3 · from map chests'), findsOneWidget);
      expect(find.bySemanticsLabel('chorten sticker'), findsOneWidget);
      expect(find.bySemanticsLabel('Empty sticker slot'), findsNWidgets(2));
    });

    testWidgets('"Find more words" opens the scanner', (tester) async {
      await pumpYonten(tester);
      await openTab(tester, 'Backpack');
      final button = find.bySemanticsLabel('Find more words');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Magic Eye'), findsOneWidget);
    });
  });

  group('Quests', () {
    testWidgets('fresh quests; claim unlocks after three finds', (tester) async {
      final store = MemoryStore();
      final c = await pumpYonten(tester, store: store);
      await openTab(tester, 'Quests');
      expect(find.text('Find 3 things in the kitchen'), findsOneWidget);
      expect(find.text('0/3'), findsOneWidget);
      expect(find.bySemanticsLabel('Claim, not ready yet'), findsNWidgets(3));

      final repo = c.read(userDataProvider);
      for (final id in ['a', 'b', 'c']) {
        await repo.recordScan(FoundWord(
            id: id, english: id, tibetan: '', verified: false, foundAt: DateTime.now()));
      }
      await tester.pumpAndSettle();
      expect(find.text('3/3'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
      expect(find.text('30/30'), findsOneWidget);

      final xpBefore = c.read(profileProvider).value!.xp;
      await tester.tap(find.bySemanticsLabel('Claim your reward').first);
      await tester.pumpAndSettle();
      expect(find.text('Got it!'), findsOneWidget);
      expect(c.read(profileProvider).value!.xp, xpBefore + 10);
    });
  });

  group('Me', () {
    testWidgets('stats, level ribbon and this week', (tester) async {
      await pumpYonten(tester, demo: true);
      await openTab(tester, 'Me');
      expect(find.text('Level 1 Explorer'), findsOneWidget);
      expect(find.bySemanticsLabel('Lessons Done: 3'), findsOneWidget);
      expect(find.bySemanticsLabel('Current Streak: 3'), findsOneWidget);
      expect(find.text('3-day streak!'), findsOneWidget);
      expect(find.byType(ButterLamp), findsNWidgets(7));
      final lit = tester.widgetList<ButterLamp>(find.byType(ButterLamp)).where((l) => l.lit);
      // Demo: today and the two days before; some may fall in last week.
      expect(lit.length, inInclusiveRange(1, 3));
    });

    testWidgets('a short press does not unlock; a 1.5 s hold does',
        (tester) async {
      await pumpYonten(tester);
      await openTab(tester, 'Me');
      final button = find.byType(HoldToUnlock);
      await tester.scrollUntilVisible(button, 200,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();

      var g = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 600));
      await g.up();
      await tester.pumpAndSettle();
      expect(find.text('Parent Settings'), findsNothing);

      g = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      await g.up();
      await tester.pumpAndSettle();
      expect(find.text('Parent Settings'), findsOneWidget);
    });

    testWidgets('parent area saves name, daily goal and sound', (tester) async {
      final c = await pumpYonten(tester);
      await openTab(tester, 'Me');
      final button = find.byType(HoldToUnlock);
      await tester.scrollUntilVisible(button, 200,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      final g = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      await g.up();
      await tester.pumpAndSettle();

      expect(find.text('Accounts need an internet connection.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Tenzin');
      await tester.tap(find.bySemanticsLabel('Save name'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('More things to find each day'));
      await tester.pumpAndSettle();
      final sound = find.bySemanticsLabel('Sound is on. Tap to turn off');
      await tester.ensureVisible(sound);
      await tester.tap(sound);
      await tester.pumpAndSettle();

      final p = c.read(profileProvider).value!;
      expect(p.displayName, 'Tenzin');
      expect(p.settings.dailyGoal, 4);
      expect(p.settings.sound, isFalse);

      await tester.tap(find.bySemanticsLabel('Close parent settings'));
      await tester.pumpAndSettle();
      expect(find.text('Tenzin'), findsOneWidget);
    });
  });
}
