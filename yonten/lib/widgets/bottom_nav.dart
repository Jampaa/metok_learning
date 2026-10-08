import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/layout.dart';
import '../theme/motion.dart';
import '../theme/text.dart';
import 'motion_scope.dart';
import 'squishable.dart';
import 'toy_button.dart';
import 'toy_surface.dart';

class NavTab {
  const NavTab(this.label, this.icon);

  final String label;
  final String icon;
}

/// Bottom nav (spec §5 "Shell"): Map, Backpack, [Scan], Quests, Me.
///
/// The widget is [YLayout.navHeight] + [YLayout.scanRise] tall. The top
/// band is transparent and only the Scan circle in it takes taps, so the
/// screen underneath stays tappable beside the circle.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onSelect,
    required this.onScan,
  }) : assert(tabs.length == 4);

  final List<NavTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    Widget tab(int i) => Expanded(
          child: _TabItem(
            tab: tabs[i],
            active: i == currentIndex,
            onTap: () => onSelect(i),
          ),
        );

    return SizedBox(
      height: YLayout.navHeight + YLayout.scanRise + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: YLayout.navHeight + bottomInset,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: YColors.white,
                border: Border(top: BorderSide(color: YColors.ink, width: 2)),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    tab(0),
                    tab(1),
                    Expanded(child: _ScanLabel(onTap: onScan)),
                    tab(2),
                    tab(3),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(child: _ScanButton(onTap: onScan)),
          ),
        ],
      ),
    );
  }
}

const _labelTop = 54.0;

TextStyle _labelStyle(Color color) =>
    YText.text(12.5, bold: true, color: color).copyWith(height: 1.1);

class _TabItem extends StatefulWidget {
  const _TabItem({required this.tab, required this.active, required this.onTap});

  final NavTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: YMotion.navHop,
  );

  @override
  void didUpdateWidget(_TabItem old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !ReducedMotion.of(context)) {
      _hop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final icon = AnimatedBuilder(
      animation: _hop,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -YMotion.navHopHeight * math.sin(math.pi * _hop.value)),
        child: child,
      ),
      child: Image.asset('assets/images/${widget.tab.icon}.webp',
          width: 32, height: 32, excludeFromSemantics: true),
    );

    return Semantics(
      button: true,
      selected: active,
      label: widget.tab.label,
      excludeSemantics: true,
      child: Squishable(
        semanticLabel: widget.tab.label,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              SizedBox(
                width: 52,
                height: 38,
                child: active
                    ? ToySurface(
                        color: YColors.sky,
                        radius: 12,
                        child: Center(child: icon),
                      )
                    : Center(child: icon),
              ),
              const SizedBox(height: _labelTop - 10 - 38),
              Text(
                widget.tab.label,
                style: _labelStyle(
                    active ? YColors.skyDark : YColors.inactiveLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Scan" label under the raised button. Tapping it also opens the
/// scanner, so the whole center column is a target.
class _ScanLabel extends StatelessWidget {
  const _ScanLabel({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(top: _labelTop),
          child: Text('Scan',
              textAlign: TextAlign.center,
              style: _labelStyle(YColors.mutedStrong)),
        ),
      ),
    );
  }
}

/// 84 px white circle rising 34 px above the bar, holding a sky-blue
/// 62 × 58 toy button with the camera icon.
class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: YColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: YColors.ink, width: 2),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 62,
        height: 58,
        child: ToyButton(
          semanticLabel: 'Scan',
          circle: true,
          border: 2.5,
          padding: EdgeInsets.zero,
          onPressed: onTap,
          child: Image.asset('assets/images/nav-camera.webp',
              width: 40, height: 40, excludeFromSemantics: true),
        ),
      ),
    );
  }
}
