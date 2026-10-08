import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/curriculum.dart';
import 'models/progress.dart';
import 'repositories/curriculum_repository.dart';

final curriculumRepositoryProvider = Provider<CurriculumRepository>(
  (ref) => const LocalCurriculumRepository(),
);

final curriculumProvider = FutureProvider<List<Chapter>>((ref) async {
  final chapters = await ref.watch(curriculumRepositoryProvider).chapters();
  return [...chapters]..sort((a, b) => a.order.compareTo(b.order));
});

/// Every lesson in map order, across chapters.
List<Lesson> lessonsInOrder(List<Chapter> chapters) =>
    [for (final c in chapters) ...c.lessons];

/// The child's place on the map. It only ever moves forward (spec §5):
/// there's no API that removes a completed lesson. Phase 4 persists it.
class ProgressNotifier extends Notifier<MapProgress> {
  /// Demo start (spec §5 Trail): ཀ ཁ ག done, ང active.
  static const demoStart = MapProgress(
    currentLessonId: 'unit1-nga',
    completed: {'unit1-ka', 'unit1-kha', 'unit1-ga'},
  );

  @override
  MapProgress build() => demoStart;

  /// Marks [lessonId] done. If it was the current lesson, the next
  /// lesson that isn't done yet becomes current. Completing a lesson
  /// twice, or a lesson out of order (e.g. tapping the chest early in the
  /// demo), never moves the current lesson backward.
  void complete(String lessonId, List<Lesson> ordered) {
    if (state.isDone(lessonId)) return;
    final completed = {...state.completed, lessonId};
    var current = state.currentLessonId;
    if (current == lessonId || current == null) {
      final from = ordered.indexWhere((l) => l.id == lessonId);
      current = null;
      for (var i = from + 1; i < ordered.length; i++) {
        if (!completed.contains(ordered[i].id)) {
          current = ordered[i].id;
          break;
        }
      }
    }
    state = MapProgress(currentLessonId: current, completed: completed);
  }

  /// Debug only (gallery): restore the demo start.
  void debugReset() => state = demoStart;
}

final progressProvider =
    NotifierProvider<ProgressNotifier, MapProgress>(ProgressNotifier.new);

/// Stickers earned from map chests. Phase 4 persists them; Phase 7 shows
/// them in the Backpack.
class StickersNotifier extends Notifier<List<EarnedSticker>> {
  @override
  List<EarnedSticker> build() => const [];

  /// Adds a sticker once; earning the same one again is a no-op.
  void earn(String stickerId, {required String fromLessonId}) {
    if (state.any((s) => s.id == stickerId)) return;
    state = [
      ...state,
      EarnedSticker(
        id: stickerId,
        fromLessonId: fromLessonId,
        earnedAt: DateTime.now(),
      ),
    ];
  }

  void debugReset() => state = const [];
}

final stickersProvider =
    NotifierProvider<StickersNotifier, List<EarnedSticker>>(
        StickersNotifier.new);
