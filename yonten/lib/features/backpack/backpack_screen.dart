import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/tab_visits.dart';
import '../../data/curriculum_providers.dart';
import '../../data/models/progress.dart';
import '../../data/models/word.dart';
import '../../data/stickers.dart';
import '../../services/providers.dart';
import '../../theme/colors.dart';
import '../../theme/motion.dart';
import '../../theme/text.dart';
import '../../widgets/motion_scope.dart';
import '../../widgets/pop_in.dart';
import '../../widgets/toy_button.dart';
import '../../widgets/toy_surface.dart';
import '../../widgets/word_photo.dart';

/// My Backpack (spec §5): the words the child has found, each card showing
/// the child's own photo (D37), plus stickers from map chests.
class BackpackScreen extends ConsumerWidget {
  const BackpackScreen({super.key});

  /// Hand-placed tilts, repeating (spec §5).
  static const tilts = [-1.5, 1.2, 1.0, -1.8];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = ref.watch(wordsProvider).value ?? const <FoundWord>[];
    final stickers = ref.watch(stickersProvider).value ?? const <EarnedSticker>[];
    final visit = ref.watch(tabVisitProvider(1));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 64, 20, 28),
        children: [
          Text('My Backpack', style: YText.heading(34)),
          Text('རྒྱབ་ཁུར།', style: YText.tibetan(22, color: YColors.maroon)),
          const SizedBox(height: 2),
          Text("Words you've found", style: YText.text(16, color: YColors.muted)),
          const SizedBox(height: 18),
          if (words.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Your Backpack is empty. Let’s go find something!',
                  textAlign: TextAlign.center, style: YText.label(18)),
            )
          else
            LayoutBuilder(builder: (context, c) {
              const gap = 14.0;
              final w = (c.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap + 4,
                children: [
                  for (final (i, word) in words.indexed)
                    SizedBox(
                      width: w,
                      height: 178,
                      child: PopIn(
                        key: ValueKey('word-${word.id}'),
                        trigger: visit,
                        delay: YMotion.cardStagger * i,
                        from: 0.6,
                        child: WordCard(word: word, tilt: tilts[i % tilts.length]),
                      ),
                    ),
                ],
              );
            }),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text('Stickers', style: YText.heading(24))),
              Text('${math.min(stickers.length, StickerCatalog.slots)} of ${StickerCatalog.slots} · from map chests',
                  style: YText.text(14, color: YColors.muted, bold: true)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < StickerCatalog.slots; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                i < stickers.length
                    ? PopIn(
                        key: ValueKey('sticker-${stickers[i].id}'),
                        child: _EarnedSticker(stickers[i].id),
                      )
                    : const _EmptySlot(),
              ],
            ],
          ),
          const SizedBox(height: 28),
          ToyButton(
            semanticLabel: 'Find more words',
            label: 'Find more words',
            expand: true,
            onPressed: () => context.push(Routes.scan),
          ),
        ],
      ),
    );
  }
}

/// One found word. Tapping plays its audio (verified words only) and
/// wiggles the card.
class WordCard extends ConsumerStatefulWidget {
  const WordCard({super.key, required this.word, this.tilt = 0});

  final FoundWord word;
  final double tilt;

  @override
  ConsumerState<WordCard> createState() => _WordCardState();
}

class _WordCardState extends ConsumerState<WordCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  void _tap() {
    final w = widget.word;
    if (w.verified && w.tibetan.isNotEmpty) {
      ref.read(audioServiceProvider).playWord(w.id, url: w.audioUrl);
    }
    if (!ReducedMotion.of(context)) _wiggle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.word;
    final showTibetan = w.verified && w.tibetan.isNotEmpty;
    return Semantics(
      container: true,
      button: true,
      label: showTibetan ? '${w.english}. Tap to hear it' : w.english,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _tap,
        child: AnimatedBuilder(
          animation: _wiggle,
          builder: (context, child) {
            final wobble = math.sin(_wiggle.value * math.pi * 4) * (1 - _wiggle.value) * 5;
            return Transform.rotate(
              angle: (widget.tilt + wobble) * math.pi / 180,
              child: child,
            );
          },
          child: ToySurface(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(
                      builder: (context, c) => WordPhoto(
                        photoId: w.photoId,
                        imageUrl: w.imageUrl,
                        size: c.maxWidth,
                        radius: 12,
                        semanticLabel: 'Your photo of the ${w.english}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (showTibetan)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(w.tibetan, style: YText.tibetan(30, color: YColors.maroon)),
                  ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(w.english, style: YText.label(showTibetan ? 16 : 20)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EarnedSticker extends StatelessWidget {
  const _EarnedSticker(this.id);

  final String id;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -6 * math.pi / 180,
      child: Container(
        width: 72,
        height: 72,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: YColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: YColors.ink, width: 2),
        ),
        child: Image.asset(StickerCatalog.asset(id),
            semanticLabel: '$id sticker', fit: BoxFit.contain),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Empty sticker slot',
      child: const SizedBox.square(
        dimension: 72,
        child: CustomPaint(painter: _DashedCircle()),
      ),
    );
  }
}

class _DashedCircle extends CustomPainter {
  const _DashedCircle();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = YColors.disabledBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final rect = (Offset.zero & size).deflate(2);
    const dashes = 18;
    for (var i = 0; i < dashes; i++) {
      final start = i * 2 * math.pi / dashes;
      canvas.drawArc(rect, start, math.pi / dashes, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => false;
}
