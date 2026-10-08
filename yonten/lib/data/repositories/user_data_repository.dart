import '../models/curriculum.dart';
import '../models/progress.dart';
import '../models/user_profile.dart';
import '../models/word.dart';

/// Everything owned by one child: `users/{uid}` and its subcollections
/// (spec §7). [FirestoreUserData] is the real one; [LocalUserData] is the
/// fallback when Firebase isn't available, with identical behavior.
abstract interface class UserDataRepository {
  /// Emits the profile now and on every change.
  Stream<UserProfile> watchProfile();

  /// Newest first.
  Stream<List<FoundWord>> watchWords();
  Stream<List<EarnedSticker>> watchStickers();
  Stream<List<QuestEntry>?> watchQuests(String date);

  /// Finishes a lesson (forward only). For a chest, also grants its
  /// sticker. Updates stats and the streak.
  Future<void> completeLesson(Lesson lesson, List<Lesson> ordered);

  /// Saves a found word, adds XP, and updates stats and the streak.
  Future<void> recordScan(FoundWord word);

  Future<void> saveQuests(String date, List<QuestEntry> quests);
  Future<void> addXp(int amount);
  Future<void> updateSettings(UserSettings settings);

  /// Debug only: wipe this child's data and start over.
  Future<void> debugReset();

  /// Debug only: the spec's demo state (ཀ ཁ ག done, ང active, four words).
  Future<void> debugLoadDemo(List<Lesson> ordered, List<FoundWord> words);

  /// "firestore" or "local", for the gallery.
  String get mode;
}

/// The spec's demo progress (§5 Trail).
const demoProgress = MapProgress(
  currentLessonId: 'unit1-nga',
  completed: {'unit1-ka', 'unit1-kha', 'unit1-ga'},
);
