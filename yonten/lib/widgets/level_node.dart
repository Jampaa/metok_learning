import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/motion.dart';
import '../theme/text.dart';
import 'ink_icons.dart';
import 'motion_scope.dart';
import 'toy_button.dart';

enum LevelNodeLook { completed, active, locked }

/// A lesson stepping stone on the map (spec §5 Trail):
/// - completed: yellow 64 × 60, ink letter, maroon check badge
/// - active: sky blue 76 × 72 on a 100 px sky-tint disc, with a 4 px ring
///   pulsing outward
/// - locked: disabled colors, but still tappable for a gentle message
class LevelNode extends StatelessWidget {
  const LevelNode({
    super.key,
    required this.label,
    required this.look,
    required this.semanticLabel,
    required this.onTap,
  });

  final String label;
  final LevelNodeLook look;
  final String semanticLabel;
  final VoidCallback onTap;

  /// Box the node occupies, centered on its path point.
  static Size sizeFor(LevelNodeLook look) => look == LevelNodeLook.active
      ? const Size(100, 100)
      : const Size(64, 60);

  @override
  Widget build(BuildContext context) {
    return switch (look) {
      LevelNodeLook.completed => _completed(),
      LevelNodeLook.active => _active(),
      LevelNodeLook.locked => _locked(),
    };
  }

  Widget _button({
    required Color color,
    required double size,
    required Color textColor,
    bool muted = false,
  }) =>
      ToyButton(
        semanticLabel: semanticLabel,
        circle: true,
        color: color,
        muted: muted,
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Text(label, style: YText.tibetan(size, color: textColor)),
      );

  Widget _completed() => SizedBox(
        width: 64,
        height: 60,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: _button(
                  color: YColors.yellow, size: 31, textColor: YColors.ink),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: IgnorePointer(
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: YColors.maroon,
                    shape: BoxShape.circle,
                    border: Border.all(color: YColors.ink, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const InkIcon(InkGlyph.check, size: 18),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _locked() => SizedBox(
        width: 64,
        height: 60,
        child: _button(
          color: YColors.disabledFill,
          size: 31,
          textColor: YColors.disabledText,
          muted: true,
        ),
      );

  Widget _active() => SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: YColors.skyTint,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: 100),
            ),
            IgnorePointer(
              child: LoopBuilder(
                period: YMotion.nodeRing,
                restValue: 1,
                builder: (context, t, child) => Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: Transform.scale(scale: 0.85 + 0.45 * t, child: child),
                ),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: YColors.sky, width: 4),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 76,
              height: 72,
              child: _button(
                  color: YColors.sky, size: 38, textColor: YColors.ink),
            ),
          ],
        ),
      );
}
