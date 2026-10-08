import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/vision_service.dart';
import '../../theme/colors.dart';
import '../../theme/motion.dart';
import '../../theme/text.dart';
import '../../widgets/ink_icons.dart';
import '../../widgets/motion_scope.dart';
import '../../widgets/toy_button.dart';
import '../../widgets/toy_surface.dart';
import '../../widgets/word_photo.dart';

/// The card that slides up after a find (spec §5, §6): the child's photo
/// (pops in at 200 ms), the Tibetan word (Jomolhari 46, maroon), English
/// (Grandstander 22), the phonetic spelling, "Play audio", and a +10 XP
/// seal that stamps in at 250 ms. Tilted −1.5°.
///
/// Tibetan is shown only for verified words; otherwise the card says the
/// Tibetan is coming soon (AGENTS.md).
class ResultCard extends StatefulWidget {
  const ResultCard({
    super.key,
    required this.word,
    required this.photo,
    required this.onPlay,
  });

  final ScanWord word;
  final Uint8List photo;
  final VoidCallback onPlay;

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    // Long enough for the seal, which starts at 250 ms.
    duration: YMotion.resultSeal + YMotion.resultCard,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status == AnimationStatus.dismissed) {
      ReducedMotion.of(context) ? _c.value = 1 : _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _phase(Duration start, Duration length) {
    final total = _c.duration!.inMicroseconds;
    final t = (_c.value * total - start.inMicroseconds) / length.inMicroseconds;
    return t.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.word;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final slide = YMotion.overshoot.transform(
          _phase(Duration.zero, YMotion.resultCard),
        );
        final pic = Curves.easeOutBack.transform(
          _phase(YMotion.resultPicture, const Duration(milliseconds: 300)),
        );
        final seal = Curves.easeOutCubic.transform(
          _phase(YMotion.resultSeal, const Duration(milliseconds: 260)),
        );
        return FractionalTranslation(
          translation: Offset(0, 1.15 * (1 - slide)),
          child: Transform.rotate(
            angle: -1.5 * math.pi / 180,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ToySurface(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Transform.scale(
                        scale: pic,
                        child: WordPhoto(
                          bytes: widget.photo,
                          size: 104,
                          semanticLabel: 'Your photo of the ${w.english}',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: _words(w)),
                    ],
                  ),
                ),
                Positioned(
                  top: -20,
                  right: -12,
                  child: Opacity(
                    opacity: seal > 0 ? 1 : 0,
                    child: Transform.rotate(
                      angle: (30 + (12 - 30) * seal) * math.pi / 180,
                      child: Transform.scale(
                        scale: 1.8 + (1 - 1.8) * seal,
                        child: const XpSeal(size: 62),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _words(ScanWord w) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (w.showTibetan)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              w.tibetan,
              style: YText.tibetan(46, color: YColors.maroon),
            ),
          ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(w.english, style: YText.heading(w.showTibetan ? 22 : 28)),
        ),
        if (w.showTibetan && w.phonetic.isNotEmpty)
          Text(w.phonetic, style: YText.text(15, color: YColors.muted)),
        if (!w.showTibetan)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "We'll learn this one in Tibetan soon!",
              style: YText.text(14, color: YColors.muted),
            ),
          ),
        if (w.showTibetan) ...[
          const SizedBox(height: 8),
          ToyButton(
            semanticLabel: 'Play audio',
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            onPressed: widget.onPlay,
            // Scales down rather than overflowing on narrow phones.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const InkIcon(InkGlyph.speaker, size: 22),
                  const SizedBox(width: 6),
                  Text('Play audio', style: YText.label(16)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
