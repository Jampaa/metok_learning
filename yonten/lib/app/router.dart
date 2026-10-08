import 'package:go_router/go_router.dart';

import '../features/backpack/backpack_screen.dart';
import '../features/gallery/gallery_screen.dart';
import '../features/map/map_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/quests/quests_screen.dart';
import '../features/scanner/scanner_screen.dart';
import 'routes.dart';
import 'shell.dart';

GoRouter buildRouter({String? status}) => GoRouter(
      initialLocation: Routes.map,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              AppShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: Routes.map, builder: (_, _) => const MapScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: Routes.backpack,
                  builder: (_, _) => const BackpackScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: Routes.quests, builder: (_, _) => const QuestsScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: Routes.me, builder: (_, _) => const ProfileScreen()),
            ]),
          ],
        ),
        GoRoute(
          path: Routes.scan,
          builder: (_, state) =>
              ScannerScreen(lessonId: state.uri.queryParameters['lesson']),
        ),
        GoRoute(
          path: Routes.gallery,
          builder: (_, _) => GalleryScreen(status: status),
        ),
      ],
    );
