import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/text.dart';

/// Backpack. Phase 2 stand-in with the spec's header; the word grid and
/// stickers arrive in Phase 7.
class BackpackScreen extends StatelessWidget {
  const BackpackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 64, 20, 24),
        children: [
          Text('My Backpack', style: YText.heading(34)),
          Text('རྒྱབ་ཁུར།', style: YText.tibetan(22, color: YColors.maroon)),
          const SizedBox(height: 4),
          Text("Words you've found", style: YText.text(16, color: YColors.muted)),
        ],
      ),
    );
  }
}
