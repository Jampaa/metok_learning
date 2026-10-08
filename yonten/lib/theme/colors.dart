import 'package:flutter/painting.dart';

/// Himalayan palette (spec §4). The only place colors are defined.
abstract final class YColors {
  // Core
  static const sky = Color(0xFF2AB0EE);
  static const skyDark = Color(0xFF1A8AC1);
  static const maroon = Color(0xFFC03221);
  static const maroonDark = Color(0xFF9A2517);
  static const yellow = Color(0xFFF9C80E);
  static const yellowDark = Color(0xFFD1A507);
  static const background = Color(0xFFF7F9FA);
  static const ink = Color(0xFF2D3142);
  static const white = Color(0xFFFFFFFF);

  // Supporting
  static const muted = Color(0xFF5C6378);
  static const mutedStrong = Color(0xFF3D4357);
  static const disabledFill = Color(0xFFEEF2F5);
  static const disabledBorder = Color(0xFFB8C3CC);
  static const disabledText = Color(0xFF7D8995);
  static const inactiveLabel = Color(0xFF6B7685);

  // Tints
  static const skyTint = Color(0xFFDDF1FB);
  static const yellowTint = Color(0xFFFEF1C2);
  static const yellowDone = Color(0xFFFFF6D6);
  static const maroonTint = Color(0xFFF8DEDA);
  static const slateTint = Color(0xFFE9EDF1);

  // Map scene
  static const path = Color(0xFFF2E2C4);
  static const thangkaCaption = Color(0xFFFBD9D3);
}
