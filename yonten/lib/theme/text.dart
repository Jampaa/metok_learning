import 'package:flutter/material.dart';

import 'colors.dart';

/// Type scale (spec §4). Fonts are bundled so text renders offline.
///
/// - Grandstander 700/800: headings, numbers, button labels.
/// - Andika 400/700: body text and labels (designed for early readers).
/// - Jomolhari: all Tibetan text. One weight only, never bold.
abstract final class YText {
  static const display = 'Grandstander';
  static const body = 'Andika';
  static const tibetanFamily = 'Jomolhari';

  static TextStyle heading(double size, {Color color = YColors.ink}) =>
      TextStyle(
        fontFamily: display,
        fontWeight: FontWeight.w800,
        fontSize: size,
        height: 1.1,
        color: color,
      );

  /// Numbers and button labels.
  static TextStyle label(double size, {Color color = YColors.ink}) =>
      TextStyle(
        fontFamily: display,
        fontWeight: FontWeight.w700,
        fontSize: size,
        height: 1.15,
        color: color,
      );

  static TextStyle text(
    double size, {
    Color color = YColors.ink,
    bool bold = false,
  }) =>
      TextStyle(
        fontFamily: body,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        fontSize: size,
        height: 1.3,
        color: color,
      );

  /// Tibetan script. Weight is pinned to 400 because Jomolhari has no bold;
  /// a synthetic bold would smear the stacked letters.
  static TextStyle tibetan(double size, {Color color = YColors.ink}) =>
      TextStyle(
        fontFamily: tibetanFamily,
        fontWeight: FontWeight.w400,
        fontSize: size,
        height: 1.35,
        color: color,
      );
}

ThemeData yontenTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: YText.body,
    scaffoldBackgroundColor: YColors.background,
    colorScheme: const ColorScheme.light(
      primary: YColors.sky,
      onPrimary: YColors.ink,
      secondary: YColors.maroon,
      onSecondary: YColors.white,
      tertiary: YColors.yellow,
      surface: YColors.white,
      onSurface: YColors.ink,
    ),
    // Toy buttons give their own press feedback; no Material ripples.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: TextTheme(
      bodyMedium: YText.text(16),
      bodyLarge: YText.text(18),
      labelLarge: YText.label(16),
    ),
  );
}
