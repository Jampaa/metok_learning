import 'models/curriculum.dart';
import 'models/progress.dart';
import 'models/user_profile.dart';
import 'models/word.dart';

/// Pure game rules shared by the Firestore and local repositories, so both
/// behave identically and the rules can be unit-tested.
abstract final class GameRules {
  static const xpPerWord = 10;

  /// Marks [lessonId] done. Returns the same object if nothing changes.
  ///
  /// Progress only moves forward (spec §5, §7): nothing is ever removed
  /// from `completed`, and the current lesson only moves when the current
  /// lesson itself is finished. Finishing a lesson out of order (opening a
  /// chest early in the demo) leaves the current lesson where it is.
  static MapProgress advance(
    MapProgress p,
    String lessonId,
    List<Lesson> ordered,
  ) {
    if (p.isDone(lessonId)) return p;
    final ids = [for (final l in ordered) l.id];
    final current = p.resolveCurrent(ids);
    final completed = {...p.completed, lessonId};
    var next = current;
    if (current == null || current == lessonId) {
      next = null;
      final from = ids.indexOf(lessonId);
      for (var i = from + 1; i < ids.length; i++) {
        if (!completed.contains(ids[i])) {
          next = ids[i];
          break;
        }
      }
    }
    return MapProgress(currentLessonId: next, completed: completed);
  }

  /// A day counts as active after one scan or one finished lesson
  /// (spec §7). Dates are the child's local `yyyy-mm-dd`.
  static Streak nextStreak(Streak s, DateTime now) {
    final today = dateKey(now);
    if (s.lastActiveDate == today) return s;
    final yesterday = dateKey(DateTime(now.year, now.month, now.day - 1));
    final count = s.lastActiveDate == yesterday ? s.count + 1 : 1;
    return Streak(count: count, lastActiveDate: today);
  }

  /// The streak as it should be displayed today: a streak whose last
  /// active day is before yesterday has lapsed and shows 0.
  static int visibleStreak(Streak s, DateTime now) {
    final today = dateKey(now);
    final yesterday = dateKey(DateTime(now.year, now.month, now.day - 1));
    return s.lastActiveDate == today || s.lastActiveDate == yesterday
        ? s.count
        : 0;
  }

  /// Marks today active: streak plus the recent-days list for the lamps.
  static UserProfile markActive(UserProfile u, DateTime now) {
    final today = dateKey(now);
    final dates = u.activeDates.contains(today)
        ? u.activeDates
        : [...u.activeDates, today];
    final kept = dates.length > UserProfile.keepActiveDates
        ? dates.sublist(dates.length - UserProfile.keepActiveDates)
        : dates;
    return u.copyWith(streak: nextStreak(u.streak, now), activeDates: kept);
  }

  /// Applies finishing [lesson] to a profile. Chests don't count as a
  /// lesson for stats or streaks; they're rewards.
  static UserProfile completeLesson(
    UserProfile u,
    Lesson lesson,
    List<Lesson> ordered,
    DateTime now,
  ) {
    final progress = advance(u.progress, lesson.id, ordered);
    if (identical(progress, u.progress)) return u;
    if (lesson.isChest) return u.copyWith(progress: progress);
    return markActive(
      u.copyWith(
        progress: progress,
        stats: u.stats.copyWith(lessons: u.stats.lessons + 1),
      ),
      now,
    );
  }

  /// Applies a successful scan. [isNewWord] is false when the child finds
  /// a word that's already in the Backpack: it still counts as a hunt and
  /// for the streak, but doesn't add to the word count.
  static UserProfile recordScan(UserProfile u, {required bool isNewWord, required DateTime now}) {
    return markActive(
      u.copyWith(
        xp: u.xp + xpPerWord,
        stats: u.stats.copyWith(
          words: u.stats.words + (isNewWord ? 1 : 0),
          hunts: u.stats.hunts + 1,
        ),
      ),
      now,
    );
  }

  // ---------- daily quests (spec §5 Quests) ----------

  static const questFind = 'find';
  static const questNewWords = 'new-words';
  static const questXp = 'xp';

  /// XP for claiming a finished quest. It doesn't count toward the XP
  /// quest itself, so claims can't feed each other.
  static const questReward = 10;

  /// Today's three quests. The "find" target follows the parent's daily
  /// goal (spec §5 Me: daily goal).
  static List<QuestEntry> defaultQuests({int dailyGoal = 3}) => [
        QuestEntry(
          id: questFind,
          goal: 'Find $dailyGoal things in the kitchen',
          progress: 0,
          target: dailyGoal.clamp(1, 10),
        ),
        const QuestEntry(
            id: questNewWords, goal: 'Learn 2 new words', progress: 0, target: 2),
        const QuestEntry(
            id: questXp, goal: 'Earn 30 XP to open a chest', progress: 0, target: 30),
      ];

  /// Quest progress after a successful scan. Progress stops at the target.
  static List<QuestEntry> questsAfterScan(List<QuestEntry> qs, {required bool isNewWord}) => [
        for (final q in qs)
          q.copyWith(
            progress: (q.progress +
                    switch (q.id) {
                      questFind => 1,
                      questNewWords => isNewWord ? 1 : 0,
                      questXp => xpPerWord,
                      _ => 0,
                    })
                .clamp(0, q.target),
          ),
      ];

  /// Marks [questId] claimed if it's complete and not yet claimed. Returns
  /// the same list when the claim isn't allowed.
  static List<QuestEntry> claim(List<QuestEntry> qs, String questId) {
    final i = qs.indexWhere((q) => q.id == questId);
    if (i < 0 || !qs[i].complete || qs[i].claimed) return qs;
    return [for (final q in qs) q.id == questId ? q.copyWith(claimed: true) : q];
  }
}

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
