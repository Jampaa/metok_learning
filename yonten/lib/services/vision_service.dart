import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import '../data/models/word.dart';
import '../data/repositories/vocab_repository.dart';

/// What a scan comes back with.
sealed class ScanOutcome {
  const ScanOutcome();
}

/// A word was found. [tibetan] is empty unless the word is verified.
class ScanFound extends ScanOutcome {
  const ScanFound(this.word);

  final ScanWord word;
}

/// Not sure, not kid-safe, or no clear object: "Hmm, let's try again!"
class ScanRetry extends ScanOutcome {
  const ScanRetry([this.reason = '']);

  final String reason;
}

/// Couldn't reach the server. The photo is queued and checked later.
class ScanQueued extends ScanOutcome {
  const ScanQueued();
}

class ScanWord {
  const ScanWord({
    required this.id,
    required this.english,
    required this.tibetan,
    required this.verified,
    this.phonetic = '',
    this.audioUrl,
  });

  final String id;
  final String english;
  final String tibetan;
  final bool verified;
  final String phonetic;
  final String? audioUrl;

  /// Only verified Tibetan ever reaches the screen (AGENTS.md).
  bool get showTibetan => verified && tibetan.isNotEmpty;

  factory ScanWord.fromMap(Map<String, dynamic> m) {
    final verified = m['verified'] as bool? ?? false;
    return ScanWord(
      id: m['id'] as String,
      english: (m['english'] as String?) ?? '',
      tibetan: verified ? (m['tibetan'] as String?) ?? '' : '',
      verified: verified,
      phonetic: verified ? (m['phonetic'] as String?) ?? '' : '',
      audioUrl: verified ? m['audioUrl'] as String? : null,
    );
  }

  FoundWord toFound({required String photoId, required DateTime at, String? imageUrl}) =>
      FoundWord(
        id: id,
        english: english,
        tibetan: showTibetan ? tibetan : '',
        verified: verified,
        phonetic: phonetic,
        audioUrl: audioUrl,
        photoId: photoId,
        imageUrl: imageUrl,
        foundAt: at,
      );
}

abstract interface class VisionService {
  Future<ScanOutcome> identify(Uint8List jpeg);

  /// "functions" or "mock", for the gallery.
  String get name;
}

/// The real thing: the `identify_object` callable (spec §8.1).
class FunctionsVisionService implements VisionService {
  FunctionsVisionService(this._functions);

  final FirebaseFunctions _functions;

  @override
  String get name => 'functions';

  @override
  Future<ScanOutcome> identify(Uint8List jpeg) async {
    try {
      final result = await _functions
          .httpsCallable('identify_object',
              options: HttpsCallableOptions(timeout: const Duration(seconds: 45)))
          .call<Map<String, dynamic>>({'image': base64Encode(jpeg)});
      final data = Map<String, dynamic>.from(result.data);
      if (data['status'] == 'found' && data['word'] is Map) {
        return ScanFound(ScanWord.fromMap(Map<String, dynamic>.from(data['word'] as Map)));
      }
      return ScanRetry('${data['reason'] ?? ''}');
    } on FirebaseFunctionsException catch (e) {
      // Bad input is a retry; anything about reaching the server is a
      // queue, so the photo is checked when we're back online.
      return e.code == 'invalid-argument' ? ScanRetry(e.code) : const ScanQueued();
    } catch (_) {
      return const ScanQueued();
    }
  }
}

/// For demos and tests without the backend. It can't see the photo, so it
/// cycles through the starter words. Only used when explicitly chosen
/// (`--dart-define=VISION_MOCK=true`) or in tests; never as a silent
/// fallback, because naming the wrong object would teach a child the wrong
/// word.
class MockVisionService implements VisionService {
  MockVisionService(this._vocab, {this.script});

  final VocabRepository _vocab;

  /// Optional fixed sequence of outcomes (tests).
  final List<ScanOutcome>? script;
  int _next = 0;

  @override
  String get name => 'mock';

  @override
  Future<ScanOutcome> identify(Uint8List jpeg) async {
    final s = script;
    if (s != null && s.isNotEmpty) return s[_next++ % s.length];
    final words = (await _vocab.starter()).where((v) => !v.id.startsWith('letter-')).toList();
    if (words.isEmpty) return const ScanRetry();
    final v = words[_next++ % words.length];
    return ScanFound(ScanWord(
      id: v.id,
      english: v.english,
      tibetan: v.tibetan,
      verified: v.verified,
      phonetic: v.phonetic,
      audioUrl: v.audioUrl,
    ));
  }
}
