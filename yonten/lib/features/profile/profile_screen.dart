import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/text.dart';
import '../../widgets/yonten_sprite.dart';

/// Me. Phase 2 stand-in: the avatar in its ring (blinking in step with
/// every other Yonten) and the name. Stats and lamps arrive in Phase 8.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
        children: [
          Center(
            child: Container(
              width: 132,
              height: 132,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: YColors.yellow,
                shape: BoxShape.circle,
                border: Border.all(color: YColors.ink, width: 2),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: YColors.skyTint,
                  shape: BoxShape.circle,
                  border: Border.all(color: YColors.ink, width: 2),
                ),
                child: ClipOval(
                  child: Semantics(
                    label: 'Yonten',
                    child: const YontenSprite(
                      pose: YontenPose.avatar,
                      size: 112,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text('Explorer', style: YText.heading(32))),
        ],
      ),
    );
  }
}
