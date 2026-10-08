import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How many times each tab (Map, Backpack, Quests, Me) has been switched
/// to. Screens watch their count to replay "when this opens" animations
/// (Yonten waves, word cards pop in, Yonten peeks, today's lamp lights).
class TabVisits extends Notifier<List<int>> {
  @override
  List<int> build() => const [0, 0, 0, 0];

  void visited(int tab) =>
      state = [for (var i = 0; i < state.length; i++) i == tab ? state[i] + 1 : state[i]];
}

final tabVisitsProvider = NotifierProvider<TabVisits, List<int>>(TabVisits.new);

/// Visit count for one tab.
final tabVisitProvider = Provider.family<int, int>(
    (ref, tab) => ref.watch(tabVisitsProvider)[tab]);
