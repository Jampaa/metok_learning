/// `users/{uid}.progress` (spec §7): `{currentLessonId, completedLessonIds[]}`.
class MapProgress {
  const MapProgress({required this.currentLessonId, required this.completed});

  /// A brand-new child: nothing done, the first lesson is current.
  static const start = MapProgress(currentLessonId: null, completed: {});

  /// Null means "the first lesson that isn't done" (see [resolveCurrent]).
  final String? currentLessonId;
  final Set<String> completed;

  bool isDone(String lessonId) => completed.contains(lessonId);

  /// The lesson that's active on the map: the stored current lesson if it
  /// still exists and isn't done, otherwise the first lesson not done yet.
  /// Null once everything is done.
  String? resolveCurrent(List<String> orderedIds) {
    final stored = currentLessonId;
    if (stored != null && orderedIds.contains(stored) && !isDone(stored)) {
      return stored;
    }
    for (final id in orderedIds) {
      if (!isDone(id)) return id;
    }
    return null;
  }

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

  @override
  bool operator ==(Object other) =>
      other is MapProgress &&
      other.currentLessonId == currentLessonId &&
      other.completed.length == completed.length &&
      other.completed.containsAll(completed);

  @override
  int get hashCode => Object.hash(currentLessonId, completed.length);
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

  Map<String, dynamic> toMap() => {
        'fromLessonId': fromLessonId,
        'earnedAt': earnedAt.toIso8601String(),
      };

  factory EarnedSticker.fromMap(String id, Map<String, dynamic> m) =>
      EarnedSticker(
        id: id,
        fromLessonId: (m['fromLessonId'] as String?) ?? '',
        earnedAt: parseTime(m['earnedAt']),
      );
}

/// Accepts a Firestore Timestamp (anything with `toDate()`), an ISO string
/// or epoch millis.
DateTime parseTime(Object? v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  try {
    return (v as dynamic).toDate() as DateTime;
  } catch (_) {
    return DateTime.now();
  }
}
