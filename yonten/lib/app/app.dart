import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/layout.dart';
import '../theme/text.dart';
import '../widgets/motion_scope.dart';
import '../widgets/paper_grain.dart';
import '../widgets/yonten_sprite.dart';
import 'router.dart';

class YontenApp extends StatefulWidget {
  const YontenApp({super.key, this.status});

  /// Bootstrap status (Firebase / local mode), shown in the gallery.
  final String? status;

  @override
  State<YontenApp> createState() => _YontenAppState();
}

class _YontenAppState extends State<YontenApp> {
  late final GoRouter _router = buildRouter(status: widget.status);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Yonten',
      debugShowCheckedModeBanner: false,
      theme: yontenTheme(),
      routerConfig: _router,
      builder: (context, child) => ReducedMotionScope(
        child: _Precache(
          child: BlinkClock(
            child: PaperGrain(child: AppFrame(child: child!)),
          ),
        ),
      ),
    );
  }
}

/// Decodes every Yonten frame and nav icon once at startup (spec §3).
class _Precache extends StatefulWidget {
  const _Precache({required this.child});

  final Widget child;

  static const navIcons = [
    'nav-map', 'nav-backpack', 'nav-quests', 'nav-me', 'nav-camera',
    'icon-flame',
  ];

  @override
  State<_Precache> createState() => _PrecacheState();
}

class _PrecacheState extends State<_Precache> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    precacheYonten(context);
    for (final name in _Precache.navIcons) {
      precacheImage(AssetImage('assets/images/$name.webp'), context);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
