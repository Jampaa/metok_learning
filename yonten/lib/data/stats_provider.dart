import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The numbers in the streak and words pills.
class HeaderStats {
  const HeaderStats({required this.streak, required this.words});

  final int streak;
  final int words;
}

/// Placeholder values until Phase 4 reads `users/{uid}` (streak.count,
/// stats.words). The four words match the Backpack demo seed.
final headerStatsProvider = Provider<HeaderStats>(
  (ref) => const HeaderStats(streak: 3, words: 4),
);
