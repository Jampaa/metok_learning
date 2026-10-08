import 'dart:async';

import '../local_store.dart';
import '../models/curriculum.dart';
import '../models/progress.dart';
import '../models/user_profile.dart';
import '../models/word.dart';
import '../rules.dart';
import 'user_data_repository.dart';

/// Local-mode user data, persisted in the key-value store (Hive). Used when
/// Firebase can't start, and in tests.
class LocalUserData implements UserDataRepository {
  LocalUserData(this._store, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final KeyValueStore _store;
  final DateTime Function() _now;
  final _changes = StreamController<void>.broadcast();

  @override
  String get mode => 'local';

  UserProfile get _profile {
    final m = _store.read(StoreKeys.localProfile);
    return m is Map ? UserProfile.fromMap(m.cast()) : const UserProfile();
  }

  List<FoundWord> get _words => [
        for (final e in _list(StoreKeys.localWords))
          FoundWord.fromMap(e['id'] as String, e),
      ]..sort((a, b) => b.foundAt.compareTo(a.foundAt));

  List<EarnedSticker> get _stickers => [
        for (final e in _list(StoreKeys.localStickers))
          EarnedSticker.fromMap(e['id'] as String, e),
      ];

  List<Map<String, dynamic>> _list(String key) {
    final v = _store.read(key);
    if (v is! List) return [];
    return [for (final e in v) Map<String, dynamic>.from(e as Map)];
  }

  Future<void> _saveProfile(UserProfile p) async {
    await _store.write(StoreKeys.localProfile, p.toMap());
    _changes.add(null);
  }

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  @override
  Stream<UserProfile> watchProfile() => _watch(() => _profile);

  @override
  Stream<List<FoundWord>> watchWords() => _watch(() => _words);

  @override
  Stream<List<EarnedSticker>> watchStickers() => _watch(() => _stickers);

  @override
  Stream<List<QuestEntry>?> watchQuests(String date) => _watch(() {
        final v = _store.read(StoreKeys.localQuests(date));
        if (v is! List) return null;
        return [
          for (final e in v) QuestEntry.fromMap(Map<String, dynamic>.from(e as Map)),
        ];
      });

  @override
  Future<void> completeLesson(Lesson lesson, List<Lesson> ordered) async {
    final before = _profile;
    final after = GameRules.completeLesson(before, lesson, ordered, _now());
    if (identical(after, before)) return;
    final sticker = lesson.rewardStickerId;
    if (lesson.isChest && sticker != null && !_stickers.any((s) => s.id == sticker)) {
      await _store.write(StoreKeys.localStickers, [
        ..._list(StoreKeys.localStickers),
        {
          'id': sticker,
          ...EarnedSticker(
            id: sticker,
            fromLessonId: lesson.id,
            earnedAt: _now(),
          ).toMap(),
        },
      ]);
    }
    await _saveProfile(after);
  }

  @override
  Future<void> recordScan(FoundWord word) async {
    final words = _list(StoreKeys.localWords);
    final isNew = !words.any((e) => e['id'] == word.id);
    final entry = {'id': word.id, ...word.toMap()};
    await _store.write(StoreKeys.localWords, [
      for (final e in words)
        if (e['id'] != word.id) e,
      entry,
    ]);
    await _saveProfile(
        GameRules.recordScan(_profile, isNewWord: isNew, now: _now()));
  }

  @override
  Future<void> saveQuests(String date, List<QuestEntry> quests) async {
    await _store.write(
        StoreKeys.localQuests(date), [for (final q in quests) q.toMap()]);
    _changes.add(null);
  }

  @override
  Future<void> addXp(int amount) async =>
      _saveProfile(_profile.copyWith(xp: _profile.xp + amount));

  @override
  Future<void> updateSettings(UserSettings settings) async =>
      _saveProfile(_profile.copyWith(settings: settings));

  @override
  Future<void> debugReset() async {
    for (final k in _store.keys.where((k) => k.startsWith('local.')).toList()) {
      await _store.remove(k);
    }
    _changes.add(null);
  }

  @override
  Future<void> debugLoadDemo(List<Lesson> ordered, List<FoundWord> words) async {
    await debugReset();
    await _store.write(StoreKeys.localWords, [
      for (final w in words) {'id': w.id, ...w.toMap()},
    ]);
    await _saveProfile(const UserProfile().copyWith(
      progress: demoProgress,
      stats: Stats(words: words.length, lessons: demoProgress.completed.length),
      streak: Streak(count: 3, lastActiveDate: dateKey(_now())),
      xp: words.length * GameRules.xpPerWord,
    ));
  }
}
