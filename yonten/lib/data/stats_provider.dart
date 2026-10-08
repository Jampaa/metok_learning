import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'curriculum_providers.dart';
import 'rules.dart';

/// The numbers in the streak and words pills.
class HeaderStats {
  const HeaderStats({required this.streak, required this.words});

  final int streak;
  final int words;
}

final headerStatsProvider = Provider<HeaderStats>((ref) {
  final profile = ref.watch(profileProvider).value;
  if (profile == null) return const HeaderStats(streak: 0, words: 0);
  return HeaderStats(
    streak: GameRules.visibleStreak(profile.streak, DateTime.now()),
    words: profile.stats.words,
  );
});
