import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stats_provider.dart';
import 'ink_icons.dart';
import 'sticker_chip.dart';

/// Streak and words pills, top-right of the Map and Backpack (spec §5).
class StatPills extends ConsumerWidget {
  const StatPills({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(headerStatsProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StickerChip(
          icon: Image.asset('assets/images/icon-flame.webp'),
          text: '${stats.streak}',
          semanticLabel: '${stats.streak} day streak',
        ),
        const SizedBox(width: 8),
        StickerChip(
          icon: const InkIcon(InkGlyph.book),
          text: '${stats.words}',
          semanticLabel: '${stats.words} words learned',
        ),
      ],
    );
  }
}
