import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/local_store.dart';
import '../data/repositories/vocab_repository.dart';

/// Plays a word's or letter's Monlam audio (spec §8.2). Audio is generated
/// once on the server and stored in Cloud Storage; the app only plays it.
abstract interface class AudioService {
  /// Plays [wordId]. [url] skips the lookup when the caller already has it.
  /// Never throws: no audio is better than an error for a child.
  Future<void> playWord(String? wordId, {String? url});
}

/// Fallback while audio isn't available (local mode, tests).
class SilentAudioService implements AudioService {
  const SilentAudioService();

  @override
  Future<void> playWord(String? wordId, {String? url}) async {}
}

/// Finds the URL (given, remembered on this device, `vocab/{id}.audioUrl`,
/// or the `get_word_audio` callable, which generates it the first time)
/// and plays it with just_audio.
class MonlamAudioService implements AudioService {
  MonlamAudioService({
    required this.vocab,
    required this.cache,
    this.functions,
    required this.soundOn,
  });

  final VocabRepository vocab;
  final AudioPathCache cache;
  final FirebaseFunctions? functions;
  final bool Function() soundOn;
  AudioPlayer? _player;

  Future<String?> _resolve(String wordId) async {
    final remembered = cache.pathFor(wordId);
    if (remembered != null) return remembered;
    final fromCatalog = (await vocab.get(wordId))?.audioUrl;
    if (fromCatalog != null && fromCatalog.isNotEmpty) return fromCatalog;
    final f = functions;
    if (f == null) return null;
    final result = await f
        .httpsCallable('get_word_audio')
        .call<Map<String, dynamic>>({'wordId': wordId});
    return result.data['audioUrl'] as String?;
  }

  @override
  Future<void> playWord(String? wordId, {String? url}) async {
    if (!soundOn() || (wordId == null && url == null)) return;
    try {
      final resolved = url ?? await _resolve(wordId!);
      if (resolved == null) return;
      if (wordId != null) await cache.remember(wordId, resolved);
      final player = _player ??= AudioPlayer();
      await player.setUrl(resolved);
      await player.seek(Duration.zero);
      await player.play();
    } catch (e) {
      // e.g. Monlam quota expired ("Audio isn't ready yet") or offline.
      debugPrint('Yonten: no audio for $wordId ($e)');
    }
  }
}
