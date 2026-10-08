import '../models/curriculum.dart';

/// Where the map's chapters come from. Phase 3 uses [LocalCurriculumRepository];
/// Phase 4 adds a Firestore implementation that falls back to it.
abstract interface class CurriculumRepository {
  Future<List<Chapter>> chapters();
}

/// Milestone chest spacing for new chapters (spec §5: every 5 or 10 nodes).
abstract final class CurriculumConfig {
  static const chestInterval = 5;

  /// Builds a chapter's lessons from its letters, with a chest as every
  /// [chestInterval]th node. Use it for chapters that don't hand-place
  /// their chests.
  static List<Lesson> lettersWithChests(
    String chapterId,
    List<(String id, String letter)> letters, {
    int interval = chestInterval,
    String rewardStickerId = 'chorten',
  }) {
    final lessons = <Lesson>[];
    var chest = 0;
    for (final (id, letter) in letters) {
      if ((lessons.length + 1) % interval == 0) {
        chest++;
        lessons.add(Lesson(
          id: '$chapterId-chest-$chest',
          order: lessons.length + 1,
          type: LessonType.chest,
          label: '',
          rewardStickerId: rewardStickerId,
        ));
      }
      lessons.add(Lesson(
        id: '$chapterId-$id',
        order: lessons.length + 1,
        type: LessonType.letter,
        label: letter,
        wordId: 'letter-$id',
      ));
    }
    return lessons;
  }
}

/// Offline curriculum: the spec's chapter 1 seed (§7). Also the fallback
/// when Firestore is unavailable.
class LocalCurriculumRepository implements CurriculumRepository {
  const LocalCurriculumRepository();

  @override
  Future<List<Chapter>> chapters() async => seedChapters;

  static final seedChapters = [
    Chapter(
      id: 'unit1',
      order: 1,
      title: 'The Alphabet',
      titleTibetan: 'ཀ་ཁ་ག་ང།',
      unitLabel: 'Unit 1',
      workbookChapter: 1,
      // Placeholder until the real workbook page range is confirmed (D27).
      workbookPages: const [1, 6],
      lessons: _unit1Lessons,
    ),
  ];

  // Hand-placed to match the spec exactly: ཀ ཁ ག ང, a chest, then ཅ ཆ ཇ ཉ ཏ.
  static const _unit1Lessons = [
    Lesson(id: 'unit1-ka', order: 1, type: LessonType.letter, label: 'ཀ', wordId: 'letter-ka'),
    Lesson(id: 'unit1-kha', order: 2, type: LessonType.letter, label: 'ཁ', wordId: 'letter-kha'),
    Lesson(id: 'unit1-ga', order: 3, type: LessonType.letter, label: 'ག', wordId: 'letter-ga'),
    Lesson(id: 'unit1-nga', order: 4, type: LessonType.letter, label: 'ང', wordId: 'letter-nga'),
    Lesson(id: 'unit1-chest-1', order: 5, type: LessonType.chest, label: '', rewardStickerId: 'chorten'),
    Lesson(id: 'unit1-ca', order: 6, type: LessonType.letter, label: 'ཅ', wordId: 'letter-ca'),
    Lesson(id: 'unit1-cha', order: 7, type: LessonType.letter, label: 'ཆ', wordId: 'letter-cha'),
    Lesson(id: 'unit1-ja', order: 8, type: LessonType.letter, label: 'ཇ', wordId: 'letter-ja'),
    Lesson(id: 'unit1-nya', order: 9, type: LessonType.letter, label: 'ཉ', wordId: 'letter-nya'),
    Lesson(id: 'unit1-ta', order: 10, type: LessonType.letter, label: 'ཏ', wordId: 'letter-ta'),
  ];
}
