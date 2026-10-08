/// `users/{uid}.progress` (spec §7): `{currentLessonId, completedLessonIds[]}`.
class MapProgress {
  const MapProgress({required this.currentLessonId, required this.completed});

  /// Null when every lesson is done.
  final String? currentLessonId;
  final Set<String> completed;

  bool isDone(String lessonId) => completed.contains(lessonId);

  Map<String, dynamic> toMap() => {
        'currentLessonId': currentLessonId,
        'completedLessonIds': completed.toList(),
      };

  factory MapProgress.fromMap(Map<String, dynamic> m) => MapProgress(
        currentLessonId: m['currentLessonId'] as String?,
        completed: {
          for (final id in (m['completedLessonIds'] as List?) ?? const [])
            id as String,
        },
      );
}

/// Earned sticker (`users/{uid}/stickers/{stickerId}`).
class EarnedSticker {
  const EarnedSticker({
    required this.id,
    required this.fromLessonId,
    required this.earnedAt,
  });

  final String id;
  final String fromLessonId;
  final DateTime earnedAt;
}
