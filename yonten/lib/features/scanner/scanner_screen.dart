import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../theme/colors.dart';
import '../../theme/text.dart';
import '../../widgets/ink_icons.dart';
import '../../widgets/toy_button.dart';
import '../../widgets/yonten_sprite.dart';

/// Magic Eye scanner. Phase 2 stand-in: the header and Yonten in his
/// explore sway. Camera, states and the result card arrive in Phase 5.
class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox.square(
                    dimension: 52,
                    child: ToyButton(
                      semanticLabel: 'Close',
                      color: YColors.white,
                      circle: true,
                      padding: EdgeInsets.zero,
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go(Routes.map),
                      child: const InkIcon(InkGlyph.close, size: 28),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text('Magic Eye', style: YText.heading(26)),
                        Text('མིག་འཕྲུལ།',
                            style: YText.tibetan(18, color: YColors.maroon)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 52),
                ],
              ),
              const Spacer(),
              const YontenSprite(
                pose: YontenPose.explore,
                motion: YontenMotion.explore,
                size: 112,
              ),
              const SizedBox(height: 8),
              Text("Let's look!", style: YText.label(20)),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
