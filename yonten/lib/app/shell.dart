import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/map/map_screen.dart';
import '../theme/layout.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/stat_pills.dart';
import 'routes.dart';

/// The tab shell: the current tab's screen above the 88 px bottom nav, plus
/// the streak and words pills on the Map and Backpack only (spec §5).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const tabs = [
    NavTab('Map', 'nav-map'),
    NavTab('Backpack', 'nav-backpack'),
    NavTab('Quests', 'nav-quests'),
    NavTab('Me', 'nav-me'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = navigationShell.currentIndex;
    final media = MediaQuery.of(context);
    final navSpace = YLayout.navHeight + media.padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            bottom: navSpace,
            child: MediaQuery(
              data: media.copyWith(
                padding: media.padding.copyWith(bottom: 0),
                viewPadding: media.viewPadding.copyWith(bottom: 0),
              ),
              child: navigationShell,
            ),
          ),
          if (index == 0 || index == 1)
            Positioned(
              top: media.padding.top + 12,
              right: 14,
              child: const StatPills(),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNav(
              tabs: tabs,
              currentIndex: index,
              onSelect: (i) {
                if (i == 0 && index != 0) {
                  ref.read(mapVisitsProvider.notifier).visited();
                }
                navigationShell.goBranch(i, initialLocation: i == index);
              },
              onScan: () => context.push(Routes.scan),
            ),
          ),
        ],
      ),
    );
  }
}
