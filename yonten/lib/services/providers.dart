import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/curriculum_providers.dart';
import '../data/local_store.dart';
import 'audio_service.dart';
import 'capture_service.dart';
import 'photo_store.dart';
import 'scan_flow.dart';
import 'vision_service.dart';

/// `--dart-define=VISION_MOCK=true` cycles through the starter words
/// instead of calling Gemini (demos without a backend).
const _visionMock = bool.fromEnvironment('VISION_MOCK');

FirebaseFunctions functionsInstance() =>
    FirebaseFunctions.instanceFor(region: 'us-central1');

/// Local mode (no Firebase): every scan waits in the queue until the app
/// can reach the server. Never guesses.
class OfflineVisionService implements VisionService {
  const OfflineVisionService();

  @override
  String get name => 'offline';

  @override
  Future<ScanOutcome> identify(Uint8List jpeg) async => const ScanQueued();
}

final visionServiceProvider = Provider<VisionService>((ref) {
  if (_visionMock) return MockVisionService(ref.watch(vocabRepositoryProvider));
  return ref.watch(backendProvider).online
      ? FunctionsVisionService(functionsInstance())
      : const OfflineVisionService();
});

final photoStoreProvider = Provider<PhotoStore>((ref) {
  final b = ref.watch(backendProvider);
  return PhotoStore(
    b.store,
    uploader: b.online ? FirebasePhotoUploader(FirebaseStorage.instance, b.uid!) : null,
  );
});

final scanFlowProvider = Provider<ScanFlow>((ref) => ScanFlow(
      vision: ref.watch(visionServiceProvider),
      repo: ref.watch(userDataProvider),
      photos: ref.watch(photoStoreProvider),
      store: ref.watch(backendProvider).store,
    ));

/// Makes the scanner's photo source. Tests override it with a fake.
final captureSourceFactoryProvider =
    Provider<CaptureSource Function()>((ref) => CameraCapture.new);

final audioServiceProvider = Provider<AudioService>((ref) {
  final b = ref.watch(backendProvider);
  return MonlamAudioService(
    vocab: ref.watch(vocabRepositoryProvider),
    cache: AudioPathCache(b.store),
    functions: b.online ? functionsInstance() : null,
    soundOn: () => ref.read(profileProvider).value?.settings.sound ?? true,
  );
});
