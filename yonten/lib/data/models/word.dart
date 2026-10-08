import 'progress.dart';

/// A word the child found (`users/{uid}/words/{wordId}`, spec §7).
class FoundWord {
  const FoundWord({
    required this.id,
    required this.english,
    required this.tibetan,
    required this.verified,
    this.phonetic = '',
    this.imageUrl,
    this.audioUrl,
    this.picture,
    required this.foundAt,
  });

  final String id;
  final String english;

  /// Shown to the child only when [verified] (AGENTS.md).
  final String tibetan;
  final bool verified;
  final String phonetic;
  final String? imageUrl;
  final String? audioUrl;

  /// Built-in placeholder art name (e.g. `obj-apple`), if any.
  final String? picture;
  final DateTime foundAt;

  Map<String, dynamic> toMap() => {
        'english': english,
        'tibetan': tibetan,
        'verified': verified,
        'phonetic': phonetic,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (audioUrl != null) 'audioUrl': audioUrl,
        if (picture != null) 'picture': picture,
        'foundAt': foundAt.toIso8601String(),
      };

  factory FoundWord.fromMap(String id, Map<String, dynamic> m) => FoundWord(
        id: id,
        english: (m['english'] as String?) ?? id,
        tibetan: (m['tibetan'] as String?) ?? '',
        verified: m['verified'] as bool? ?? false,
        phonetic: (m['phonetic'] as String?) ?? '',
        imageUrl: m['imageUrl'] as String?,
        audioUrl: m['audioUrl'] as String?,
        picture: m['picture'] as String?,
        foundAt: parseTime(m['foundAt']),
      );

  factory FoundWord.fromVocab(VocabEntry v, {DateTime? at}) => FoundWord(
        id: v.id,
        english: v.english,
        tibetan: v.tibetan,
        verified: v.verified,
        phonetic: v.phonetic,
        audioUrl: v.audioUrl,
        picture: v.picture,
        foundAt: at ?? DateTime.now(),
      );
}

/// Global catalog entry (`vocab/{wordId}`), read-only for clients.
class VocabEntry {
  const VocabEntry({
    required this.id,
    required this.english,
    required this.tibetan,
    required this.verified,
    this.phonetic = '',
    this.audioUrl,
    this.picture,
  });

  final String id;
  final String english;
  final String tibetan;
  final bool verified;
  final String phonetic;
  final String? audioUrl;
  final String? picture;

  factory VocabEntry.fromMap(String id, Map<String, dynamic> m) => VocabEntry(
        id: id,
        english: (m['english'] as String?) ?? id,
        tibetan: (m['tibetan'] as String?) ?? '',
        // Spec §7 calls it `reviewed`; we use `verified` (D3). Accept both.
        verified: (m['verified'] ?? m['reviewed']) as bool? ?? false,
        phonetic: (m['phonetic'] as String?) ?? '',
        audioUrl: m['audioUrl'] as String?,
        picture: m['picture'] as String?,
      );
}

/// One daily quest (`users/{uid}/quests/{date}.quests[]`, spec §7).
class QuestEntry {
  const QuestEntry({
    required this.id,
    required this.goal,
    required this.progress,
    required this.target,
    this.claimed = false,
  });

  final String id;
  final String goal;
  final int progress;
  final int target;
  final bool claimed;

  bool get complete => progress >= target;

  QuestEntry copyWith({int? progress, bool? claimed}) => QuestEntry(
        id: id,
        goal: goal,
        progress: progress ?? this.progress,
        target: target,
        claimed: claimed ?? this.claimed,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'goal': goal,
        'progress': progress,
        'target': target,
        'claimed': claimed,
      };

  factory QuestEntry.fromMap(Map<String, dynamic> m) => QuestEntry(
        id: m['id'] as String,
        goal: (m['goal'] as String?) ?? '',
        progress: (m['progress'] as num?)?.toInt() ?? 0,
        target: (m['target'] as num?)?.toInt() ?? 1,
        claimed: m['claimed'] as bool? ?? false,
      );
}
