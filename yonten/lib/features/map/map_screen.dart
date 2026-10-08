import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/layout.dart';
import '../../theme/text.dart';
import '../../widgets/squishable.dart';
import '../../widgets/yonten_sprite.dart';

/// Treasure Hunt Map. Phase 2 stand-in: the sky band color and Yonten,
/// who breathes while idle and waves on open and on tap. The full map
/// arrives in Phase 3.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _yonten = YontenController();

  @override
  void dispose() {
    _yonten.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: YColors.skyTint,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Squishable(
              semanticLabel: 'Yonten. Tap to say hello',
              onTap: _yonten.wave,
              child: YontenSprite(
                size: 124.rp(context),
                motion: YontenMotion.breathe,
                controller: _yonten,
                waveOnMount: true,
              ),
            ),
            const SizedBox(height: 12),
            Text('Treasure map coming next', style: YText.label(18)),
          ],
        ),
      ),
    );
  }
}
