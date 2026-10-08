import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/text.dart';
import 'toy_surface.dart';

/// White sticker pill holding an icon and a short value, such as the
/// streak and words pills on the Map and Backpack screens (spec §5).
class StickerChip extends StatelessWidget {
  const StickerChip({
    super.key,
    required this.icon,
    required this.text,
    required this.semanticLabel,
    this.tiltDegrees = 0,
  });

  final Widget icon;
  final String text;
  final String semanticLabel;
  final double tiltDegrees;

  @override
  Widget build(BuildContext context) {
    final chip = ToySurface(
      radius: 999,
      bottomEdge: 3.5,
      padding: const EdgeInsets.fromLTRB(8, 4, 14, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(dimension: 26, child: icon),
          const SizedBox(width: 6),
          Text(text, style: YText.label(18)),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: tiltDegrees == 0
          ? chip
          : Transform.rotate(angle: tiltDegrees * math.pi / 180, child: chip),
    );
  }
}
