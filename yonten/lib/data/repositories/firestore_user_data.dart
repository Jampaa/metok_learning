import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../local_store.dart';
import '../models/curriculum.dart';
import '../models/progress.dart';
import '../models/user_profile.dart';
import '../models/word.dart';
import '../rules.dart';
import 'user_data_repository.dart';

/// `users/{uid}/**` in Firestore. Offline persistence is on, so reads come
/// from the local cache when there's no connection and writes queue up.
///
/// Progress, streak and quest updates run in a transaction (spec §7).
/// Transactions need the server, so when one fails (offline), the same
/// change is written as a merge computed from the cached profile. That
/// write is still forward-only: completed lessons are added with
/// arrayUnion, never replaced.
///
/// The fallback only runs when the transaction has actually failed, never
/// on a timer: a slow transaction can still commit, and racing it would
/// count the same scan twice (found by the emulator check).
class FirestoreUserData implements UserDataRepository {
  FirestoreUserData({
    required FirebaseFirestore db,
    required this.uid,
    required KeyValueStore cache,
    DateTime Function()? clock,
  })  : _db = db, // ignore: prefer_initializing_formals
        _cache = cache, // ignore: prefer_initializing_formals
        _now = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final String uid;
  final KeyValueStore _cache;
  final DateTime Function() _now;

  @override
  String get mode => 'firestore';

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> get _words =>
      _user.collection('words');
  CollectionReference<Map<String, dynamic>> get _stickers =>
      _user.collection('stickers');
  CollectionReference<Map<String, dynamic>> get _photos =>
      _user.collection('photos');
  DocumentReference<Map<String, dynamic>> _quests(String date) =>
      _user.collection('quests').doc(date);

  @override
  Stream<UserProfile> watchProfile() {
    return _user.snapshots().map((snap) {
      if (!snap.exists && !snap.metadata.isFromCache) {
        // Only create once the server confirms there's no doc, so an
        // offline cold start can never overwrite real progress.
        _user.set(const UserProfile().toMap());
      }
      final profile = UserProfile.fromMap(snap.data());
      _cache.write(StoreKeys.profileCache, profile.toMap());
      return profile;
    });
  }

  @override
  Stream<List<FoundWord>> watchWords() => _words
      .orderBy('foundAt', descending: true)
      .snapshots()
      .map((q) => [for (final d in q.docs) FoundWord.fromMap(d.id, d.data())]);

  @override
  Stream<List<EarnedSticker>> watchStickers() => _stickers
      .orderBy('earnedAt')
      .snapshots()
      .map((q) =>
          [for (final d in q.docs) EarnedSticker.fromMap(d.id, d.data())]);

  @override
  Stream<List<QuestEntry>?> watchQuests(String date) =>
      _quests(date).snapshots().map((s) {
        final list = s.data()?['quests'];
        if (list is! List) return null;
        return [
          for (final e in list)
            QuestEntry.fromMap(Map<String, dynamic>.from(e as Map)),
        ];
      });

  /// The fields a profile change writes. Completed lessons go through
  /// arrayUnion so a write can only ever add to them.
  Map<String, dynamic> _profileWrite(UserProfile after, {String? addCompleted}) => {
        'level': after.level,
        'xp': after.xp,
        'streak': after.streak.toMap(),
        'activeDates': after.activeDates,
        'stats': after.stats.toMap(),
        'progress': {
          'currentLessonId': after.progress.currentLessonId,
          'completedLessonIds': addCompleted == null
              ? after.progress.completed.toList()
              : FieldValue.arrayUnion([addCompleted]),
        },
      };

  Future<UserProfile> _cachedProfile() async {
    try {
      final s = await _user.get(const GetOptions(source: Source.cache));
      return UserProfile.fromMap(s.data());
    } catch (_) {
      final m = _cache.read(StoreKeys.profileCache);
      return m is Map ? UserProfile.fromMap(m.cast()) : const UserProfile();
    }
  }

  Map<String, dynamic> _stickerDoc(Lesson lesson) => {
        'fromLessonId': lesson.id,
        'earnedAt': Timestamp.fromDate(_now()),
      };

  @override
  Future<void> completeLesson(Lesson lesson, List<Lesson> ordered) async {
    final sticker = lesson.isChest ? lesson.rewardStickerId : null;
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_user);
        final stickerSnap =
            sticker == null ? null : await tx.get(_stickers.doc(sticker));
        final before = UserProfile.fromMap(snap.data());
        final after = GameRules.completeLesson(before, lesson, ordered, _now());
        if (identical(after, before)) return;
        tx.set(_user, _profileWrite(after, addCompleted: lesson.id),
            SetOptions(merge: true));
        if (stickerSnap != null && !stickerSnap.exists) {
          tx.set(_stickers.doc(sticker), _stickerDoc(lesson));
        }
      });
    } catch (_) {
      final before = await _cachedProfile();
      final after = GameRules.completeLesson(before, lesson, ordered, _now());
      if (identical(after, before)) return;
      final batch = _db.batch()
        ..set(_user, _profileWrite(after, addCompleted: lesson.id),
            SetOptions(merge: true));
      if (sticker != null) {
        batch.set(_stickers.doc(sticker), _stickerDoc(lesson),
            SetOptions(merge: true));
      }
      unawaited(batch.commit());
    }
  }

  Map<String, dynamic> _wordDoc(FoundWord w) => {
        ...w.toMap(),
        'foundAt': Timestamp.fromDate(w.foundAt),
      };

  List<QuestEntry>? _questsFrom(Map<String, dynamic>? data) {
    final list = data?['quests'];
    if (list is! List) return null;
    return [for (final e in list) QuestEntry.fromMap(Map<String, dynamic>.from(e as Map))];
  }

  Map<String, dynamic> _questsDoc(List<QuestEntry> qs) =>
      {'quests': [for (final q in qs) q.toMap()]};

  @override
  Future<void> recordScan(FoundWord word) async {
    final today = dateKey(_now());
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_user);
        final wordSnap = await tx.get(_words.doc(word.id));
        final questSnap = await tx.get(_quests(today));
        final before = UserProfile.fromMap(snap.data());
        final isNew = !wordSnap.exists;
        final after = GameRules.recordScan(before, isNewWord: isNew, now: _now());
        final quests = _questsFrom(questSnap.data()) ??
            GameRules.defaultQuests(dailyGoal: before.settings.dailyGoal);
        tx.set(_user, _profileWrite(after)..remove('progress'), SetOptions(merge: true));
        tx.set(_words.doc(word.id), _wordDoc(word));
        tx.set(_quests(today),
            _questsDoc(GameRules.questsAfterScan(quests, isNewWord: isNew)));
      });
    } catch (_) {
      bool isNew;
      try {
        final cached =
            await _words.doc(word.id).get(const GetOptions(source: Source.cache));
        isNew = !cached.exists;
      } catch (_) {
        isNew = true;
      }
      List<QuestEntry>? quests;
      try {
        quests = _questsFrom(
            (await _quests(today).get(const GetOptions(source: Source.cache))).data());
      } catch (_) {}
      final before = await _cachedProfile();
      final after = GameRules.recordScan(before, isNewWord: isNew, now: _now());
      quests ??= GameRules.defaultQuests(dailyGoal: before.settings.dailyGoal);
      final batch = _db.batch()
        ..set(_user, _profileWrite(after)..remove('progress'), SetOptions(merge: true))
        ..set(_words.doc(word.id), _wordDoc(word))
        ..set(_quests(today),
            _questsDoc(GameRules.questsAfterScan(quests, isNewWord: isNew)));
      unawaited(batch.commit());
    }
  }

  @override
  Future<void> claimQuest(String date, String questId) async {
    try {
      await _db.runTransaction((tx) async {
        final q = await tx.get(_quests(date));
        final before = _questsFrom(q.data());
        if (before == null) return;
        final after = GameRules.claim(before, questId);
        if (identical(after, before)) return;
        tx.set(_quests(date), _questsDoc(after));
        tx.set(_user, {'xp': FieldValue.increment(GameRules.questReward)},
            SetOptions(merge: true));
      });
    } catch (_) {
      try {
        final before = _questsFrom(
            (await _quests(date).get(const GetOptions(source: Source.cache))).data());
        if (before == null) return;
        final after = GameRules.claim(before, questId);
        if (identical(after, before)) return;
        final batch = _db.batch()
          ..set(_quests(date), _questsDoc(after))
          ..set(_user, {'xp': FieldValue.increment(GameRules.questReward)},
              SetOptions(merge: true));
        unawaited(batch.commit());
      } catch (_) {}
    }
  }

  @override
  Future<void> recordPhoto(PhotoRecord photo) async {
    unawaited(_photos.doc(photo.id).set({
      ...photo.toMap(),
      'takenAt': Timestamp.fromDate(photo.takenAt),
      'storagePath': PhotoRecord.storagePath(uid, photo.id),
    }, SetOptions(merge: true)));
  }

  @override
  Stream<List<PhotoRecord>> watchPhotos() => _photos
      .orderBy('takenAt', descending: true)
      .snapshots()
      .map((q) => [for (final d in q.docs) PhotoRecord.fromMap(d.id, d.data())]);

  @override
  Future<void> attachPhotoUrl(String photoId, String url, {String? wordId}) async {
    unawaited(_photos.doc(photoId).set({'url': url}, SetOptions(merge: true)));
    if (wordId == null) return;
    try {
      final word = await _words.doc(wordId).get();
      if (word.data()?['photoId'] == photoId) {
        unawaited(_words.doc(wordId).set({'imageUrl': url}, SetOptions(merge: true)));
      }
    } catch (_) {
      // Offline: the card already shows the photo from the device.
    }
  }

  @override
  Future<void> saveQuests(String date, List<QuestEntry> quests) async {
    unawaited(_quests(date).set({
      'quests': [for (final q in quests) q.toMap()],
    }));
  }

  @override
  Future<void> addXp(int amount) async {
    final before = await _cachedProfile();
    final after = before.copyWith(xp: before.xp + amount);
    unawaited(_user.set({
      'xp': FieldValue.increment(amount),
      'level': after.level,
    }, SetOptions(merge: true)));
  }

  @override
  Future<void> updateSettings(UserSettings settings) async {
    unawaited(_user.set({'settings': settings.toMap()}, SetOptions(merge: true)));
  }

  @override
  Future<void> updateName(String name) async {
    unawaited(_user.set({'displayName': name.trim()}, SetOptions(merge: true)));
  }

  Future<void> _deleteAll(CollectionReference<Map<String, dynamic>> c) async {
    final docs = await c.get();
    for (final d in docs.docs) {
      await d.reference.delete();
    }
  }

  @override
  Future<void> debugReset() async {
    await _deleteAll(_words);
    await _deleteAll(_stickers);
    await _deleteAll(_user.collection('quests'));
    await _deleteAll(_photos);
    // Deleting the doc (rather than rewinding it) keeps the forward-only
    // rule intact; watchProfile recreates a fresh doc.
    await _user.delete();
    await _cache.remove(StoreKeys.profileCache);
  }

  @override
  Future<void> debugLoadDemo(List<Lesson> ordered, List<FoundWord> words) async {
    await debugReset();
    final demo = const UserProfile().copyWith(
      progress: demoProgress,
      stats: Stats(words: words.length, lessons: demoProgress.completed.length),
      streak: Streak(count: 3, lastActiveDate: dateKey(_now())),
      activeDates: demoActiveDates(_now()),
      xp: words.length * GameRules.xpPerWord,
    );
    final batch = _db.batch()..set(_user, demo.toMap());
    for (final w in words) {
      batch.set(_words.doc(w.id), _wordDoc(w));
    }
    await batch.commit();
  }
}
