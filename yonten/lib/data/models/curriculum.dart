/// Curriculum shapes (spec §7 `curriculum/{chapterId}`).
library;

enum LessonType { letter, word, scan, chest }

class Lesson {
  const Lesson({
    required this.id,
    required this.order,
    required this.type,
    required this.label,
    this.wordId,
    this.rewardStickerId,
  });

  final String id;
  final int order;
  final LessonType type;

  /// What the node shows: a Tibetan letter, or empty for a chest.
  final String label;

  /// `vocab/{wordId}` for the lesson's audio (Phase 6).
  final String? wordId;

  /// Sticker granted when a chest is opened.
  final String? rewardStickerId;

  bool get isChest => type == LessonType.chest;

  factory Lesson.fromMap(Map<String, dynamic> m) => Lesson(
        id: m['id'] as String,
        order: (m['order'] as num).toInt(),
        type: LessonType.values.byName(m['type'] as String),
        label: (m['label'] as String?) ?? '',
        wordId: m['wordId'] as String?,
        rewardStickerId: m['rewardStickerId'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'order': order,
        'type': type.name,
        'label': label,
        if (wordId != null) 'wordId': wordId,
        if (rewardStickerId != null) 'rewardStickerId': rewardStickerId,
      };
}

/// One chapter of the author's mother's workbook = one cluster on the map.
class Chapter {
  const Chapter({
    required this.id,
    required this.order,
    required this.title,
    required this.titleTibetan,
    required this.unitLabel,
    required this.workbookChapter,
    required this.workbookPages,
    required this.lessons,
  });

  final String id;
  final int order;

  /// "The Alphabet"
  final String title;

  /// The chapter's letters as shown on the thangka, e.g. "ཀ་ཁ་ག་ང།".
  final String titleTibetan;

  /// "Unit 1"
  final String unitLabel;
  final int workbookChapter;

  /// First and last page, e.g. [1, 6].
  final List<int> workbookPages;
  final List<Lesson> lessons;

  factory Chapter.fromMap(String id, Map<String, dynamic> m) {
    final lessons = ((m['lessons'] as List?) ?? const [])
        .map((e) => Lesson.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return Chapter(
      id: id,
      order: (m['order'] as num).toInt(),
      title: m['title'] as String,
      titleTibetan: m['titleTibetan'] as String,
      unitLabel: (m['unitLabel'] as String?) ?? 'Unit ${m['order']}',
      workbookChapter: (m['workbookChapter'] as num).toInt(),
      workbookPages: ((m['workbookPages'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      lessons: lessons,
    );
  }

  /// Test helper: the same chapter under another id and order.
  Chapter copyForTest(String newId, int newOrder) => Chapter(
        id: newId,
        order: newOrder,
        title: title,
        titleTibetan: titleTibetan,
        unitLabel: 'Unit $newOrder',
        workbookChapter: newOrder,
        workbookPages: workbookPages,
        lessons: [
          for (final l in lessons)
            Lesson(
              id: '$newId-${l.id}',
              order: l.order,
              type: l.type,
              label: l.label,
              wordId: l.wordId,
              rewardStickerId: l.rewardStickerId,
            ),
        ],
      );

  Map<String, dynamic> toMap() => {
        'order': order,
        'title': title,
        'titleTibetan': titleTibetan,
        'unitLabel': unitLabel,
        'workbookChapter': workbookChapter,
        'workbookPages': workbookPages,
        'lessons': [for (final l in lessons) l.toMap()],
      };
}
