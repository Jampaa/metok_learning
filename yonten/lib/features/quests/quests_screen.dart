import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tab_visits.dart';
import '../../data/curriculum_providers.dart';
import '../../data/day_providers.dart';
import '../../data/models/word.dart';
import '../../data/rules.dart';
import '../../theme/colors.dart';
import '../../theme/motion.dart';
import '../../theme/text.dart';
import '../../widgets/ink_icons.dart';
import '../../widgets/motion_scope.dart';
import '../../widgets/pop_in.dart';
import '../../widgets/segmented_progress.dart';
import '../../widgets/toy_button.dart';
import '../../widgets/toy_card.dart';

/// Daily Quests (spec §5). Three quests that reset each local day. A
/// finished quest's Claim button turns yellow and breathes; claiming
/// stamps "Got it!" and adds XP.
class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  static const _tilts = [-1.0, 0.8, -0.6];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quests = ref.watch(todayQuestsProvider).value ??
        GameRules.defaultQuests(
            dailyGoal: ref.watch(profileProvider).value?.settings.dailyGoal ?? 3);
    final visit = ref.watch(tabVisitProvider(2));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          Text('Daily Quests', style: YText.heading(34)),
          Text('ཉིན་རེའི་ལས་འགན།', style: YText.tibetan(22, color: YColors.maroon)),
          const SizedBox(height: 18),
          for (final (i, q) in quests.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: i == 0
                  // Yonten peeks out from behind the first card, flush with
                  // the screen's right edge.
                  ? Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          right: -20,
                          top: -118,
                          child: _PeekingYonten(visit: visit),
                        ),
                        _QuestCard(quest: q, tilt: _tilts[i % _tilts.length]),
                      ],
                    )
                  : _QuestCard(quest: q, tilt: _tilts[i % _tilts.length]),
            ),
        ],
      ),
    );
  }
}

/// yonten-peek at 82 × 150, sliding in from fully off-screen right
/// (450 ms after 150 ms) whenever Quests opens.
class _PeekingYonten extends StatefulWidget {
  const _PeekingYonten({required this.visit});

  final int visit;

  @override
  State<_PeekingYonten> createState() => _PeekingYontenState();
}

class _PeekingYontenState extends State<_PeekingYonten>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: YMotion.peek);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _play();
    }
  }

  @override
  void didUpdateWidget(_PeekingYonten old) {
    super.didUpdateWidget(old);
    if (old.visit != widget.visit) _play();
  }

  Future<void> _play() async {
    if (ReducedMotion.of(context)) {
      _c.value = 1;
      return;
    }
    _c.value = 0;
    await Future<void>.delayed(YMotion.peekDelay);
    if (mounted) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.translate(
          offset: Offset(82 * (1 - Curves.easeOutBack.transform(_c.value)), 0),
          child: child,
        ),
        child: Image.asset('assets/images/yonten-peek.webp',
            width: 82, height: 150, fit: BoxFit.contain, excludeFromSemantics: true),
      ),
    );
  }
}

class _QuestCard extends ConsumerWidget {
  const _QuestCard({required this.quest, required this.tilt});

  final QuestEntry quest;
  final double tilt;

  Widget get _icon => switch (quest.id) {
        GameRules.questFind => Image.asset('assets/images/nav-camera.webp',
            width: 30, height: 30, excludeFromSemantics: true),
        GameRules.questNewWords => const InkIcon(InkGlyph.book, size: 30),
        _ => Image.asset('assets/images/nav-quests.webp',
            width: 30, height: 30, excludeFromSemantics: true),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = quest;
    final ready = q.complete && !q.claimed;
    return ToyCard(
      tiltDegrees: tilt,
      color: q.complete ? YColors.yellowDone : YColors.white,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: YColors.white,
                shape: BoxShape.circle,
                border: Border.all(color: YColors.ink, width: 2),
              ),
              child: _icon,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(q.goal, style: YText.text(17, bold: true))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: SegmentedProgress(value: q.progress, target: q.target)),
            const SizedBox(width: 10),
            Text('${q.progress}/${q.target}', style: YText.label(16)),
            const SizedBox(width: 12),
            SizedBox(
              width: 104,
              height: 48,
              child: q.claimed
                  ? const Center(child: _GotItStamp())
                  : _ClaimButton(
                      ready: ready,
                      onClaim: () => ref
                          .read(userDataProvider)
                          .claimQuest(ref.read(todayProvider), q.id),
                    ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ClaimButton extends StatelessWidget {
  const _ClaimButton({required this.ready, required this.onClaim});

  final bool ready;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final button = ToyButton(
      semanticLabel: ready ? 'Claim your reward' : 'Claim, not ready yet',
      label: 'Claim',
      color: YColors.yellow,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      onPressed: ready ? onClaim : null,
    );
    if (!ready) return button;
    return LoopBuilder(
      period: YMotion.claimBreathe,
      mirror: true,
      child: button,
      builder: (context, t, child) => Transform.scale(
        scale: 1 + (YMotion.claimBreatheScale - 1) * Curves.easeInOut.transform(t),
        child: child,
      ),
    );
  }
}

/// The maroon "Got it!" stamp that pops in after a claim.
class _GotItStamp extends StatelessWidget {
  const _GotItStamp();

  @override
  Widget build(BuildContext context) {
    return PopIn(
      from: 1.6,
      child: Transform.rotate(
        angle: -8 * math.pi / 180,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: YColors.maroon,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: YColors.ink, width: 2),
          ),
          child: Text('Got it!', style: YText.heading(17, color: YColors.white)),
        ),
      ),
    );
  }
}
