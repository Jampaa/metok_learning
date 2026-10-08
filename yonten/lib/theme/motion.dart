import 'package:flutter/animation.dart';

/// Every duration, curve and amplitude in the app (spec §6).
/// Widgets read from here instead of hardcoding timing.
abstract final class YMotion {
  // Press feedback (§4)
  static const press = Duration(milliseconds: 70);
  static const squishScale = 0.94;

  // Yonten
  static const blinkMin = Duration(milliseconds: 3500);
  static const blinkMax = Duration(milliseconds: 6000);
  static const blinkHold = Duration(milliseconds: 140);
  static const breathe = Duration(seconds: 3);
  static const breatheScaleY = 1.025;
  static const waveDelay = Duration(milliseconds: 250);
  static const waveFrame = Duration(milliseconds: 190);
  static const explore = Duration(milliseconds: 2600);
  static const exploreDegrees = 3.0;
  static const think = Duration(seconds: 2);
  static const thinkDegrees = 3.0;
  static const peek = Duration(milliseconds: 450);
  static const peekDelay = Duration(milliseconds: 150);
  static const celebrateCrouch = Duration.zero;
  static const celebrateJump = Duration(milliseconds: 150);
  static const celebrateLand = Duration(milliseconds: 520);
  static const celebrateRest = Duration(milliseconds: 700);
  static const celebrateTransition = Duration(milliseconds: 140);

  // Confetti
  static const confetti = Duration(milliseconds: 1400);
  static const confettiPieces = 7;
  static const confettiFall = 130.0;

  // Map
  static const cloudA = Duration(seconds: 12);
  static const cloudB = Duration(seconds: 15);
  static const cloudDrift = 20.0;
  static const parallaxFactor = 0.35;
  static const parallaxCap = 340.0;
  static const thangkaSwing = Duration(milliseconds: 900);
  static const thangkaKeyframes = [-12.0, 6.0, -3.5, 1.0, -1.5];
  static const prayerFlags = Duration(seconds: 3);
  static const prayerFlagsSkewDegrees = -4.0;
  static const chestLoop = Duration(seconds: 5);
  static const chestWiggleDegrees = 5.0;
  static const chestWiggleTail = 0.14;
  static const nodeRing = Duration(seconds: 2);
  static const startBubble = Duration(milliseconds: 2400);
  static const startBubbleFloat = 4.0;
  static const toast = Duration(milliseconds: 440);
  static const toastHold = Duration(milliseconds: 2800);

  // Scanner
  static const scanLine = Duration(milliseconds: 2800);
  static const scanLineThinking = Duration(milliseconds: 1200);
  static const scanLineTravel = 260.0;
  static const resultCard = Duration(milliseconds: 440);
  static const resultPicture = Duration(milliseconds: 200);
  static const resultSeal = Duration(milliseconds: 250);
  static const retryReturn = Duration(seconds: 2);

  // Backpack, quests, profile
  static const stickerPop = Duration(milliseconds: 380);
  static const cardStagger = Duration(milliseconds: 70);
  static const lampFlicker = Duration(milliseconds: 1500);
  static const lampLight = Duration(milliseconds: 520);
  static const lampLightDelay = Duration(milliseconds: 450);
  static const navHop = Duration(milliseconds: 260);
  static const navHopHeight = 7.0;
  static const claimBreathe = Duration(milliseconds: 2400);
  static const claimBreatheScale = 1.06;
  static const parentHold = Duration(milliseconds: 1500);

  // Curves
  static const overshoot = Curves.easeOutBack;
  static const gentle = Curves.easeInOut;
}
