import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'curriculum_providers.dart';
import 'models/word.dart';
import 'rules.dart';

/// The child's local date (`yyyy-mm-dd`). The app's background sync calls
/// [refresh] every 90 s, so daily quests roll over shortly after midnight
/// while the app is open.
class TodayNotifier extends Notifier<String> {
  @override
  String build() => dateKey(DateTime.now());

  void refresh() {
    final now = dateKey(DateTime.now());
    if (now != state) state = now;
  }
}

final todayProvider = NotifierProvider<TodayNotifier, String>(TodayNotifier.new);

/// Today's quests (`users/{uid}/quests/{today}`). Before the first scan of
/// the day there's no doc yet, so fresh quests are shown.
final todayQuestsProvider = StreamProvider<List<QuestEntry>>((ref) {
  final today = ref.watch(todayProvider);
  final goal = ref.watch(profileProvider.select((p) => p.value?.settings.dailyGoal ?? 3));
  return ref
      .watch(userDataProvider)
      .watchQuests(today)
      .map((q) => q ?? GameRules.defaultQuests(dailyGoal: goal));
});
