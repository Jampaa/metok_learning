import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yonten/app/app.dart';
import 'package:yonten/data/curriculum_providers.dart';
import 'package:yonten/data/local_store.dart';
import 'package:yonten/data/models/curriculum.dart';
import 'package:yonten/data/repositories/curriculum_repository.dart';
import 'package:yonten/data/repositories/local_user_data.dart';
import 'package:yonten/services/audio_service.dart';
import 'package:yonten/services/capture_service.dart';
import 'package:yonten/services/providers.dart';
import 'package:yonten/services/vision_service.dart';
import 'package:yonten/widgets/motion_scope.dart';
import 'package:image/image.dart' as img;

/// The bundled curriculum, read straight from disk.
List<Chapter> loadUnit1() =>
    parseCurriculum(File('assets/data/curriculum.json').readAsStringSync());

/// Pumps the whole app in local mode with reduced motion on (so loops are
/// stopped and pumpAndSettle can settle). With [demo], the store starts in
/// the spec's demo state (ཀ ཁ ག done, ང active).
Future<ProviderContainer> pumpYonten(
  WidgetTester tester, {
  KeyValueStore? store,
  bool demo = false,
  List<ScanOutcome>? scans,
  AudioService audio = const SilentAudioService(),
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = store ?? MemoryStore();
  if (demo) {
    await LocalUserData(s).debugLoadDemo(lessonsInOrder(loadUnit1()), const []);
  }
  final c = ProviderContainer(overrides: [
    backendProvider.overrideWithValue(Backend(store: s)),
    audioServiceProvider.overrideWithValue(audio),
    captureSourceFactoryProvider.overrideWithValue(FakeCapture.new),
    if (scans != null)
      visionServiceProvider.overrideWith(
          (ref) => MockVisionService(ref.watch(vocabRepositoryProvider), script: scans)),
  ]);
  addTearDown(c.dispose);
  c.read(reducedMotionOverrideProvider.notifier).toggle();
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: const YontenApp(status: 'test'),
  ));
  await tester.pumpAndSettle();
  return c;
}

/// A tiny real JPEG, so the shrink step decodes it like a camera photo.
final testJpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 16, height: 12)));

/// Stands in for the camera in tests.
class FakeCapture extends CaptureSource {
  @override
  Future<void> init() async {}
  @override
  bool get live => false;
  @override
  bool get canSwitch => false;
  @override
  bool get hasFlash => false;
  @override
  bool get flashOn => false;
  @override
  Widget? preview() => null;
  @override
  Future<Uint8List?> capture() async => testJpeg;
  @override
  Future<void> switchCamera() async {}
  @override
  Future<void> setFlash(bool on) async {}
}

const verifiedApple = ScanFound(ScanWord(
    id: 'apple', english: 'apple', tibetan: 'ཀུ་ཤུ', verified: true,
    audioUrl: 'https://example.com/apple.wav'));

/// Remembers which words were asked to play.
class RecordingAudio implements AudioService {
  final played = <String?>[];

  @override
  Future<void> playWord(String? wordId, {String? url}) async => played.add(wordId);
}

/// Taps a bottom-nav tab and lets its screen settle.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
