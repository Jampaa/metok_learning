import 'package:flutter_test/flutter_test.dart';

import 'package:yonten/data/curriculum_providers.dart';
import 'package:yonten/data/local_store.dart';
import 'package:yonten/data/models/word.dart';
import 'package:yonten/data/repositories/local_user_data.dart';

import 'helpers.dart';

void main() {
  final ordered = lessonsInOrder(loadUnit1());
  final chest = ordered.firstWhere((l) => l.isChest);
  DateTime clock() => DateTime(2026, 10, 5, 10);

  FoundWord word(String id) => FoundWord(
      id: id, english: id, tibetan: '', verified: false, foundAt: clock());

  test('progress, stickers and words survive a reload', () async {
    final store = MemoryStore();
    final a = LocalUserData(store, clock: clock);
    await a.completeLesson(ordered.first, ordered);
    await a.completeLesson(chest, ordered);
    await a.recordScan(word('apple'));

    // A new instance on the same store = the app reopened.
    final b = LocalUserData(store, clock: clock);
    final profile = await b.watchProfile().first;
    expect(profile.progress.completed, {'unit1-ka', chest.id});
    expect(profile.progress.currentLessonId, 'unit1-kha');
    expect((await b.watchStickers().first).map((s) => s.id), ['chorten']);
    expect((await b.watchWords().first).map((w) => w.id), ['apple']);
  });

  test('a chest grants its sticker once', () async {
    final repo = LocalUserData(MemoryStore(), clock: clock);
    await repo.completeLesson(chest, ordered);
    await repo.completeLesson(chest, ordered);
    expect(await repo.watchStickers().first, hasLength(1));
  });

  test('finding the same word twice keeps one card, counts one word',
      () async {
    final repo = LocalUserData(MemoryStore(), clock: clock);
    await repo.recordScan(word('sun'));
    await repo.recordScan(word('sun'));
    final p = await repo.watchProfile().first;
    expect(await repo.watchWords().first, hasLength(1));
    expect(p.stats.words, 1);
    expect(p.stats.hunts, 2);
    expect(p.xp, 20);
  });

  test('words are newest first', () async {
    final repo = LocalUserData(MemoryStore());
    await repo.recordScan(FoundWord(
        id: 'old', english: 'old', tibetan: '', verified: false,
        foundAt: DateTime(2026, 1, 1)));
    await repo.recordScan(FoundWord(
        id: 'new', english: 'new', tibetan: '', verified: false,
        foundAt: DateTime(2026, 6, 1)));
    expect((await repo.watchWords().first).map((w) => w.id), ['new', 'old']);
  });

  test('quests save per day', () async {
    final repo = LocalUserData(MemoryStore());
    expect(await repo.watchQuests('2026-10-05').first, isNull);
    await repo.saveQuests('2026-10-05', const [
      QuestEntry(id: 'scan3', goal: 'Find 3 things', progress: 1, target: 3),
    ]);
    final q = await repo.watchQuests('2026-10-05').first;
    expect(q!.single.progress, 1);
    expect(await repo.watchQuests('2026-10-06').first, isNull);
  });
}
