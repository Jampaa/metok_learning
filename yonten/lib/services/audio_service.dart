import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Plays a word's or letter's Monlam audio. Phase 6 adds the real
/// just_audio implementation backed by `vocab/{wordId}.audioUrl`.
abstract interface class AudioService {
  Future<void> playWord(String? wordId);
}

/// Fallback while audio isn't wired up: does nothing, never throws.
class SilentAudioService implements AudioService {
  const SilentAudioService();

  @override
  Future<void> playWord(String? wordId) async {}
}

final audioServiceProvider =
    Provider<AudioService>((ref) => const SilentAudioService());
