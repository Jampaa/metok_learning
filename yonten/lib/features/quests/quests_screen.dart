import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/text.dart';

/// Daily Quests. Phase 2 stand-in with the spec's header; quest cards and
/// the peeking Yonten arrive in Phase 7.
class QuestsScreen extends StatelessWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Text('Daily Quests', style: YText.heading(34)),
          Text('ཉིན་རེའི་ལས་འགན།',
              style: YText.tibetan(22, color: YColors.maroon)),
        ],
      ),
    );
  }
}
