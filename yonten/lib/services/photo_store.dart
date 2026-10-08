import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../data/local_store.dart';
import '../data/models/word.dart';

/// Uploads a photo and returns its download URL.
abstract interface class PhotoUploader {
  Future<String> upload(String photoId, Uint8List jpeg);
}

/// `users/{uid}/photos/{photoId}.jpg` in Cloud Storage. Storage rules allow
/// only the owner, images only, at most 2 MB.
class FirebasePhotoUploader implements PhotoUploader {
  FirebasePhotoUploader(this._storage, this._uid);

  final FirebaseStorage _storage;
  final String _uid;

  @override
  Future<String> upload(String photoId, Uint8List jpeg) async {
    final ref = _storage.ref(PhotoRecord.storagePath(_uid, photoId));
    await ref.putData(jpeg, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}

/// Every photo the child takes is kept (D37).
///
/// Each photo is saved on the device first, so it shows instantly and works
/// offline, then uploaded. Uploads that fail (offline) wait in a queue and
/// are retried by [drainUploads]. The device keeps the newest [keepOnDevice]
/// photos; older ones are dropped locally once they're safely uploaded.
class PhotoStore {
  PhotoStore(this._store, {this.uploader, this.keepOnDevice = 80});

  final KeyValueStore _store;

  /// Null in local mode (no Firebase): photos stay on the device only.
  final PhotoUploader? uploader;
  final int keepOnDevice;

  static final _random = Random();

  static String newId(DateTime now) =>
      '${now.millisecondsSinceEpoch}-${_random.nextInt(0x7fffffff).toRadixString(36)}';

  /// The photo's bytes if they're on this device.
  Uint8List? local(String photoId) {
    final v = _store.read(StoreKeys.photoBytes(photoId));
    return v is String ? base64Decode(v) : null;
  }

  /// Saves [jpeg] on the device and queues it for upload. In local mode
  /// (no uploader) the device copy is the only copy and is never pruned.
  Future<void> keep(String photoId, Uint8List jpeg, {String? wordId}) async {
    await _store.write(StoreKeys.photoBytes(photoId), base64Encode(jpeg));
    if (uploader != null) {
      await _setPending([..._pending.where((p) => p['id'] != photoId),
        {'id': photoId, 'wordId': wordId}]);
    }
    await _prune();
  }

  /// Remembers which word a queued photo belongs to (known after the scan).
  Future<void> linkWord(String photoId, String wordId) => _setPending([
        for (final p in _pending)
          p['id'] == photoId ? {...p, 'wordId': wordId} : p,
      ]);

  List<Map<String, dynamic>> get _pending {
    final v = _store.read(StoreKeys.photoUploads);
    return v is List ? [for (final e in v) Map<String, dynamic>.from(e as Map)] : [];
  }

  Future<void> _setPending(List<Map<String, dynamic>> list) =>
      _store.write(StoreKeys.photoUploads, list);

  int get pendingCount => _pending.length;

  /// Uploads one photo now. Returns its URL, or null if it can't upload yet
  /// (it stays queued).
  Future<String?> upload(String photoId) async {
    final up = uploader;
    final bytes = local(photoId);
    if (up == null || bytes == null) return null;
    try {
      final url = await up.upload(photoId, bytes).timeout(const Duration(seconds: 30));
      await _setPending(_pending.where((p) => p['id'] != photoId).toList());
      return url;
    } catch (_) {
      return null;
    }
  }

  /// Retries every queued upload. [onUploaded] records the URL (photo doc
  /// and, if it's the card photo, the word).
  Future<int> drainUploads(
      Future<void> Function(String photoId, String url, String? wordId) onUploaded) async {
    var done = 0;
    for (final p in List.of(_pending)) {
      final id = p['id'] as String;
      final url = await upload(id);
      if (url == null) break; // still offline; try again later
      await onUploaded(id, url, p['wordId'] as String?);
      done++;
    }
    return done;
  }

  Future<void> _prune() async {
    final pending = {for (final p in _pending) p['id']};
    final ids = _store.keys
        .where((k) => k.startsWith('photo.'))
        .map((k) => k.substring('photo.'.length))
        .toList()
      ..sort(); // ids start with a timestamp, so this is oldest first
    if (uploader == null) return;
    final extra = ids.length - keepOnDevice;
    for (final id in ids.take(extra < 0 ? 0 : extra)) {
      if (!pending.contains(id)) await _store.remove(StoreKeys.photoBytes(id));
    }
  }
}
