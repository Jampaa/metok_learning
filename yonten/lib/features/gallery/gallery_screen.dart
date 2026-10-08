import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/curriculum_providers.dart';
import '../../theme/colors.dart';
import '../../theme/text.dart';
import '../../widgets/ink_icons.dart';
import '../../widgets/motion_scope.dart';
import '../../widgets/paper_grain.dart';
import '../../widgets/segmented_progress.dart';
import '../../widgets/squishable.dart';
import '../../widgets/sticker_chip.dart';
import '../../widgets/toy_button.dart';
import '../../widgets/toy_card.dart';

/// Developer gallery: every design token, widget and processed image in one
/// scrollable page. Hidden route: open `/#/gallery` in the browser.
class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key, this.status});

  final String? status;

  static const poses = [
    'idle', 'blink', 'wave-a', 'wave-b', 'explore', 'explore-blink',
    'crouch', 'cheer-jump', 'cheer-land', 'think',
  ];

  static const images = [
    'yonten-avatar', 'yonten-avatar-blink', 'yonten-peek',
    'map-mountains', 'map-hills', 'cloud-1', 'cloud-2', 'prayer-flags',
    'thangka-frame', 'chorten', 'chest-closed', 'chest-open',
    'lamp-base', 'lamp-flame',
    'nav-map', 'nav-backpack', 'nav-quests', 'nav-me', 'nav-camera',
    'icon-flame', 'icon-flash',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grainOn = ref.watch(paperGrainEnabledProvider);
    final reduced = ref.watch(reducedMotionOverrideProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Gallery', style: YText.heading(34)),
                Text('ཡོན་ཏན།', style: YText.tibetan(22, color: YColors.maroon)),
                if (status != null)
                  Text(status!, style: YText.text(13, color: YColors.muted)),
                const SizedBox(height: 12),
                ToyButton(
                  semanticLabel: 'Toggle paper texture',
                  label: grainOn ? 'Paper texture: on' : 'Paper texture: off',
                  color: YColors.white,
                  onPressed: () =>
                      ref.read(paperGrainEnabledProvider.notifier).toggle(),
                ),
                const SizedBox(height: 10),
                ToyButton(
                  semanticLabel: 'Toggle reduced motion',
                  label: reduced ? 'Reduced motion: on' : 'Reduced motion: off',
                  color: YColors.white,
                  onPressed: () =>
                      ref.read(reducedMotionOverrideProvider.notifier).toggle(),
                ),
                _section('Map progress (debug)'),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  ToyButton(
                    semanticLabel: 'Complete the current lesson',
                    label: 'Complete current lesson',
                    color: YColors.yellow,
                    onPressed: () {
                      final current = ref.read(progressProvider).currentLessonId;
                      final ordered = lessonsInOrder(
                          ref.read(curriculumProvider).value ?? const []);
                      if (current != null) {
                        ref.read(progressProvider.notifier).complete(current, ordered);
                      }
                    },
                  ),
                  ToyButton(
                    semanticLabel: 'Reset map progress to the demo start',
                    label: 'Reset demo',
                    color: YColors.white,
                    onPressed: () {
                      ref.read(progressProvider.notifier).debugReset();
                      ref.read(stickersProvider.notifier).debugReset();
                    },
                  ),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Current: ${ref.watch(progressProvider).currentLessonId ?? 'all done'} · '
                  'stickers: ${ref.watch(stickersProvider).map((s) => s.id).join(', ')}',
                  style: YText.text(13, color: YColors.muted),
                ),
                _section('Colors'),
                const _Swatches(),
                _section('Type'),
                Text('Daily Quests', style: YText.heading(34)),
                Text('Level 3 Explorer', style: YText.label(20)),
                Text('Words you\'ve found', style: YText.text(16)),
                Text('Inactive label', style: YText.text(12.5, bold: true, color: YColors.inactiveLabel)),
                Text('ཀ་ཁ་ག་ང། ཡག་པོ་རེད།', style: YText.tibetan(30, color: YColors.maroon)),
                _section('Buttons'),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ToyButton(semanticLabel: 'Start here', label: 'Start here!', onPressed: () {}),
                    ToyButton(semanticLabel: 'Claim', label: 'Claim', color: YColors.yellow, onPressed: () {}),
                    const ToyButton(semanticLabel: 'Claim, not ready yet', label: 'Claim', onPressed: null),
                    ToyButton(
                      semanticLabel: 'Play audio',
                      onPressed: () {},
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const InkIcon(InkGlyph.speaker, size: 24),
                        const SizedBox(width: 8),
                        Text('Play audio', style: YText.label(18)),
                      ]),
                    ),
                    SizedBox(
                      width: 64,
                      height: 60,
                      child: ToyButton(
                        semanticLabel: 'Letter ka, completed',
                        circle: true,
                        color: YColors.yellow,
                        padding: EdgeInsets.zero,
                        onPressed: () {},
                        child: Text('ཀ', style: YText.tibetan(26)),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      height: 60,
                      child: ToyButton(
                        semanticLabel: 'Locked lesson',
                        circle: true,
                        padding: EdgeInsets.zero,
                        onPressed: null,
                        child: Text('ཅ', style: YText.tibetan(26, color: YColors.disabledText)),
                      ),
                    ),
                    Squishable(
                      semanticLabel: 'Treasure chest',
                      onTap: () {},
                      child: Image.asset('assets/images/chest-closed.webp', width: 86),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ToyButton(
                  semanticLabel: 'Find more words',
                  label: 'Find more words',
                  expand: true,
                  onPressed: () {},
                ),
                _section('Cards and chips'),
                Row(children: [
                  StickerChip(
                    icon: Image.asset('assets/images/icon-flame.webp'),
                    text: '5',
                    semanticLabel: '5 day streak',
                  ),
                  const SizedBox(width: 10),
                  const StickerChip(
                    icon: InkIcon(InkGlyph.book),
                    text: '12',
                    semanticLabel: '12 words learned',
                  ),
                ]),
                const SizedBox(height: 16),
                ToyCard(
                  tiltDegrees: -1.5,
                  child: Column(children: [
                    const InkIcon(InkGlyph.apple, size: 96),
                    Text('ཀུ་ཤུ', style: YText.tibetan(30, color: YColors.maroon)),
                    Text('apple', style: YText.label(20)),
                  ]),
                ),
                const SizedBox(height: 16),
                ToyCard(
                  color: YColors.yellowDone,
                  tiltDegrees: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Find 3 things in the kitchen', style: YText.text(16, bold: true)),
                      const SizedBox(height: 8),
                      const SegmentedProgress(value: 1, target: 3),
                      const SizedBox(height: 8),
                      const SegmentedProgress(value: 2, target: 2),
                      const SizedBox(height: 8),
                      const SegmentedProgress(value: 10, target: 30),
                    ],
                  ),
                ),
                _section('Ink icons and word pictures'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final g in InkGlyph.values)
                      _labelled(g.fileName, InkIcon(g, size: g.fileName.startsWith('obj') ? 72 : 40)),
                    _labelled('xp-seal', const XpSeal()),
                  ],
                ),
                _section('Yonten poses (stacked, tap to flip)'),
                const _PoseFlipper(),
                _section('Processed images'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final name in images)
                      _labelled(name, Image.asset('assets/images/$name.webp', height: 72)),
                    _labelled('lamp stacked', const _StackedLamp()),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 10),
        child: Text(title, style: YText.label(20, color: YColors.skyDark)),
      );

  static Widget _labelled(String name, Widget child) => SizedBox(
        width: 100,
        child: Column(children: [
          SizedBox(height: 76, child: Center(child: child)),
          Text(name, textAlign: TextAlign.center, style: YText.text(11, color: YColors.muted)),
        ]),
      );
}

class _Swatches extends StatelessWidget {
  const _Swatches();

  static const colors = {
    'sky': YColors.sky, 'skyDark': YColors.skyDark,
    'maroon': YColors.maroon, 'maroonDark': YColors.maroonDark,
    'yellow': YColors.yellow, 'yellowDark': YColors.yellowDark,
    'ink': YColors.ink, 'background': YColors.background,
    'muted': YColors.muted, 'mutedStrong': YColors.mutedStrong,
    'disabledFill': YColors.disabledFill, 'disabledBorder': YColors.disabledBorder,
    'skyTint': YColors.skyTint, 'yellowTint': YColors.yellowTint,
    'yellowDone': YColors.yellowDone, 'maroonTint': YColors.maroonTint,
    'slateTint': YColors.slateTint, 'path': YColors.path,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in colors.entries)
          SizedBox(
            width: 80,
            child: Column(children: [
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: e.value,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: YColors.ink, width: 2),
                ),
              ),
              Text(e.key, style: YText.text(11, color: YColors.muted)),
            ]),
          ),
      ],
    );
  }
}

/// Stacks every pose and shows one, the same way YontenSprite will (Phase 2).
/// If the shared crop is right, flipping frames shows no jump.
class _PoseFlipper extends StatefulWidget {
  const _PoseFlipper();

  @override
  State<_PoseFlipper> createState() => _PoseFlipperState();
}

class _PoseFlipperState extends State<_PoseFlipper> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final poses = GalleryScreen.poses;
    return Column(children: [
      Squishable(
        semanticLabel: 'Next pose',
        onTap: () => setState(() => _index = (_index + 1) % poses.length),
        child: SizedBox.square(
          dimension: 140,
          child: Stack(children: [
            for (var i = 0; i < poses.length; i++)
              Offstage(
                offstage: i != _index,
                child: Image.asset('assets/images/yonten-${poses[i]}.webp',
                    width: 140, height: 140, gaplessPlayback: true),
              ),
          ]),
        ),
      ),
      Text(poses[_index], style: YText.text(13, color: YColors.muted)),
    ]);
  }
}

class _StackedLamp extends StatelessWidget {
  const _StackedLamp();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 60,
      child: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/images/lamp-base.webp'),
        Image.asset('assets/images/lamp-flame.webp'),
      ]),
    );
  }
}
