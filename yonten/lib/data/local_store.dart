import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// Tiny key-value store for JSON-shaped values. Hive in the app, memory in
/// tests. Values are stored as JSON strings, so no Hive adapters are
/// needed and anything Firestore-shaped round-trips.
abstract interface class KeyValueStore {
  Object? read(String key);
  Future<void> write(String key, Object? value);
  Future<void> remove(String key);
  Iterable<String> get keys;
}

class HiveStore implements KeyValueStore {
  HiveStore._(this._box);

  final Box<String> _box;

  static const boxName = 'yonten';

  /// Opens the box. Call once at startup, before runApp.
  static Future<HiveStore> open() async {
    await Hive.initFlutter();
    return HiveStore._(await Hive.openBox<String>(boxName));
  }

  @override
  Object? read(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, Object? value) =>
      _box.put(key, jsonEncode(value));

  @override
  Future<void> remove(String key) => _box.delete(key);

  @override
  Iterable<String> get keys => _box.keys.cast<String>();
}

class MemoryStore implements KeyValueStore {
  final _data = <String, String>{};

  @override
  Object? read(String key) =>
      _data[key] == null ? null : jsonDecode(_data[key]!);

  @override
  Future<void> write(String key, Object? value) async =>
      _data[key] = jsonEncode(value);

  @override
  Future<void> remove(String key) async => _data.remove(key);

  @override
  Iterable<String> get keys => _data.keys;
}

/// Keys used in the store. `cache.*` mirrors Firestore for instant cold
/// starts; `local.*` is the source of truth only in local mode (no
/// Firebase).
abstract final class StoreKeys {
  static const profileCache = 'cache.profile';
  static const audioPaths = 'cache.audioPaths';
  static const scanQueue = 'queue.scans';
  static const localProfile = 'local.profile';
  static const localWords = 'local.words';
  static const localStickers = 'local.stickers';
  static const localPhotos = 'local.photos';
  static const photoUploads = 'queue.photoUploads';
  static String photoBytes(String id) => 'photo.$id';
  static String localQuests(String date) => 'local.quests.$date';
}

/// Remembers where each word's audio file lives on this device (spec §7),
/// so playback works offline. Filled in by Phase 6.
class AudioPathCache {
  AudioPathCache(this._store);

  final KeyValueStore _store;

  Map<String, String> get _all {
    final v = _store.read(StoreKeys.audioPaths);
    return v is Map ? v.cast<String, String>() : <String, String>{};
  }

  String? pathFor(String wordId) => _all[wordId];

  Future<void> remember(String wordId, String path) =>
      _store.write(StoreKeys.audioPaths, {..._all, wordId: path});
}
