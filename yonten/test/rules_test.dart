import 'package:flutter_test/flutter_test.dart';

import 'package:yonten/data/curriculum_providers.dart';
import 'package:yonten/data/models/progress.dart';
import 'package:yonten/data/models/user_profile.dart';
import 'package:yonten/data/repositories/user_data_repository.dart';
import 'package:yonten/data/rules.dart';

import 'helpers.dart';

void main() {
  final ordered = lessonsInOrder(loadUnit1());
  final ids = [for (final l in ordered) l.id];
  lesson(String id) => ordered.firstWhere((l) => l.id == id);

  group('advance (forward only)', () {
    test('a new child starts at ཀ', () {
      expect(MapProgress.start.resolveCurrent(ids), 'unit1-ka');
    });

    test('finishing the current lesson moves to the next', () {
      final p = GameRules.advance(MapProgress.start, 'unit1-ka', ordered);
      expect(p.currentLessonId, 'unit1-kha');
      expect(p.completed, {'unit1-ka'});
    });

    test('ང → chest → ཅ', () {
      var p = GameRules.advance(demoProgress, 'unit1-nga', ordered);
      expect(p.currentLessonId, 'unit1-chest-1');
      p = GameRules.advance(p, 'unit1-chest-1', ordered);
      expect(p.currentLessonId, 'unit1-ca');
    });

    test('an early chest is skipped later and never rewinds', () {
      var p = GameRules.advance(demoProgress, 'unit1-chest-1', ordered);
      expect(p.currentLessonId, 'unit1-nga');
      p = GameRules.advance(p, 'unit1-nga', ordered);
      expect(p.currentLessonId, 'unit1-ca');
    });

    test('replaying a done lesson returns the same object', () {
      expect(GameRules.advance(demoProgress, 'unit1-ka', ordered),
          same(demoProgress));
    });

    test('finishing the last lesson leaves nothing current', () {
      var p = MapProgress.start;
      for (final l in ordered) {
        p = GameRules.advance(p, l.id, ordered);
      }
      expect(p.resolveCurrent(ids), isNull);
      expect(p.completed, hasLength(ordered.length));
    });
  });

  group('streak (child local date)', () {
    final mon = DateTime(2026, 10, 5, 9);
    test('first activity starts at 1', () {
      expect(GameRules.nextStreak(const Streak(), mon).count, 1);
    });
    test('same day does not double count', () {
      final s = GameRules.nextStreak(const Streak(), mon);
      expect(GameRules.nextStreak(s, mon.add(const Duration(hours: 8))), same(s));
    });
    test('next day adds one, across a month boundary too', () {
      const s = Streak(count: 4, lastActiveDate: '2026-09-30');
      expect(GameRules.nextStreak(s, DateTime(2026, 10, 1, 7)).count, 5);
    });
    test('a missed day restarts at 1, and shows 0 until then', () {
      const s = Streak(count: 9, lastActiveDate: '2026-10-02');
      expect(GameRules.visibleStreak(s, mon), 0);
      expect(GameRules.nextStreak(s, mon).count, 1);
    });
    test('yesterday still shows', () {
      const s = Streak(count: 9, lastActiveDate: '2026-10-04');
      expect(GameRules.visibleStreak(s, mon), 9);
    });
  });

  group('profile updates', () {
    final now = DateTime(2026, 10, 5);
    test('a lesson counts for stats and streak', () {
      final u = GameRules.completeLesson(
          const UserProfile(), lesson('unit1-ka'), ordered, now);
      expect(u.stats.lessons, 1);
      expect(u.streak.count, 1);
    });
    test('a chest is a reward, not a lesson', () {
      const before = UserProfile(progress: demoProgress);
      final u = GameRules.completeLesson(
          before, lesson('unit1-chest-1'), ordered, now);
      expect(u.progress.isDone('unit1-chest-1'), isTrue);
      expect(u.stats.lessons, 0);
      expect(u.streak.count, 0);
    });
    test('scans add XP and hunts; only new words add to words', () {
      var u = GameRules.recordScan(const UserProfile(), isNewWord: true, now: now);
      u = GameRules.recordScan(u, isNewWord: false, now: now);
      expect(u.xp, 20);
      expect(u.stats.hunts, 2);
      expect(u.stats.words, 1);
      expect(u.streak.count, 1);
    });
    test('level follows XP', () {
      expect(const UserProfile().copyWith(xp: 250).level, 3);
    });
  });

  group('active days (butter lamps)', () {
    test('each active day is listed once, newest last, at most 14', () {
      var u = const UserProfile();
      for (var d = 1; d <= 20; d++) {
        u = GameRules.markActive(u, DateTime(2026, 10, d, 9));
        u = GameRules.markActive(u, DateTime(2026, 10, d, 18));
      }
      expect(u.activeDates, hasLength(14));
      expect(u.activeDates.last, '2026-10-20');
      expect(u.streak.count, 20);
    });
    test('a scan marks today active', () {
      final u = GameRules.recordScan(const UserProfile(),
          isNewWord: true, now: DateTime(2026, 10, 9));
      expect(u.activeDates, ['2026-10-09']);
    });
  });

  group('daily quests', () {
    test('defaults follow the daily goal', () {
      final q = GameRules.defaultQuests(dailyGoal: 5);
      expect(q.first.target, 5);
      expect(q.first.goal, 'Find 5 things in the kitchen');
      expect(q.map((e) => e.target).skip(1), [2, 30]);
    });
    test('scans move every quest, and stop at the target', () {
      var q = GameRules.defaultQuests();
      for (var i = 0; i < 4; i++) {
        q = GameRules.questsAfterScan(q, isNewWord: i < 1);
      }
      expect(q.map((e) => e.progress), [3, 1, 30]);
    });
    test('claims only finished, unclaimed quests', () {
      var q = GameRules.defaultQuests();
      expect(GameRules.claim(q, GameRules.questFind), same(q));
      for (var i = 0; i < 3; i++) {
        q = GameRules.questsAfterScan(q, isNewWord: true);
      }
      final claimed = GameRules.claim(q, GameRules.questFind);
      expect(claimed.first.claimed, isTrue);
      expect(GameRules.claim(claimed, GameRules.questFind), same(claimed));
    });
  });
}
