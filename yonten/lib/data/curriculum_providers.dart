import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_store.dart';
import 'models/curriculum.dart';
import 'models/progress.dart';
import 'models/user_profile.dart';
import 'models/word.dart';
import 'repositories/curriculum_repository.dart';
import 'repositories/firestore_user_data.dart';
import 'repositories/local_user_data.dart';
import 'repositories/user_data_repository.dart';
import 'repositories/vocab_repository.dart';

/// What the app started with: whether Firebase is usable, the signed-in
/// uid, and the on-device store. Set once in main() via an override.
class Backend {
  const Backend({required this.store, this.firebase = false, this.uid});

  final KeyValueStore store;
  final bool firebase;
  final String? uid;

  bool get online => firebase && uid != null;
}

final backendProvider = Provider<Backend>(
  (ref) => throw UnimplementedError('backendProvider must be overridden'),
);

final curriculumRepositoryProvider = Provider<CurriculumRepository>((ref) {
  final local = LocalCurriculumRepository();
  return ref.watch(backendProvider).online
      ? FirestoreCurriculumRepository(FirebaseFirestore.instance, local)
      : local;
});

final vocabRepositoryProvider = Provider<VocabRepository>((ref) {
  final local = LocalVocabRepository();
  return ref.watch(backendProvider).online
      ? FirestoreVocabRepository(FirebaseFirestore.instance, local)
      : local;
});

final userDataProvider = Provider<UserDataRepository>((ref) {
  final b = ref.watch(backendProvider);
  return b.online
      ? FirestoreUserData(
          db: FirebaseFirestore.instance, uid: b.uid!, cache: b.store)
      : LocalUserData(b.store);
});

final curriculumProvider = FutureProvider<List<Chapter>>(
  (ref) => ref.watch(curriculumRepositoryProvider).chapters(),
);

/// Every lesson in map order, across chapters.
List<Lesson> lessonsInOrder(List<Chapter> chapters) =>
    [for (final c in chapters) ...c.lessons];

/// The child's profile. Starts from the Hive snapshot so the app opens
/// instantly with no connection (spec §7), then follows the repository.
final profileProvider = StreamProvider<UserProfile>((ref) async* {
  final b = ref.watch(backendProvider);
  final repo = ref.watch(userDataProvider);
  if (b.online) {
    final cached = b.store.read(StoreKeys.profileCache);
    if (cached is Map) yield UserProfile.fromMap(cached.cast());
  }
  yield* repo.watchProfile();
});

/// Map progress, derived from the profile. Changes go through
/// [UserDataRepository.completeLesson], which only moves forward.
final progressProvider = Provider<MapProgress>(
  (ref) => ref.watch(profileProvider).value?.progress ?? MapProgress.start,
);

final stickersProvider = StreamProvider<List<EarnedSticker>>(
  (ref) => ref.watch(userDataProvider).watchStickers(),
);

final wordsProvider = StreamProvider<List<FoundWord>>(
  (ref) => ref.watch(userDataProvider).watchWords(),
);
