import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'colors.dart';

/// Layout constants (spec §4 "Layout", §5 "Shell").
abstract final class YLayout {
  /// Reference frame the spec's positions are written in.
  static const referenceWidth = 400.0;
  static const referenceHeight = 800.0;

  /// On wide screens (web) the app is a centered column of this width.
  static const maxColumnWidth = 430.0;

  static const navHeight = 88.0;

  /// How far the Scan button's circle rises above the nav bar.
  static const scanRise = 34.0;
}

/// Scale factor from reference px to logical px for the current column:
/// `columnWidth / 400`. Map scene positions use it; UI chrome (nav, text)
/// stays at fixed sizes.
class RefScale extends InheritedWidget {
  const RefScale({super.key, required this.scale, required super.child});

  final double scale;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RefScale>()?.scale ?? 1;

  @override
  bool updateShouldNotify(RefScale old) => old.scale != scale;
}

extension RefPx on num {
  /// Reference px → logical px for the current column width.
  double rp(BuildContext context) => this * RefScale.of(context);
}

/// Centers the app in a column at most 430 px wide and tells everything
/// below it the column's size, so MediaQuery-based layout and [RefScale]
/// work the same on a phone and on a desktop browser.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = math.min(media.size.width, YLayout.maxColumnWidth);
    final framed = media.size.width > width;

    return ColoredBox(
      color: YColors.slateTint,
      child: Center(
        child: Container(
          width: width,
          decoration: framed
              ? const BoxDecoration(
                  color: YColors.background,
                  border: Border.symmetric(
                    vertical: BorderSide(color: YColors.ink, width: 2),
                  ),
                )
              : const BoxDecoration(color: YColors.background),
          child: MediaQuery(
            data: media.copyWith(size: Size(width, media.size.height)),
            child: RefScale(
              scale: width / YLayout.referenceWidth,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
