import 'dart:async';
import 'dart:typed_data';

import '../data/local_store.dart';
import '../data/models/curriculum.dart';
import '../data/models/word.dart';
import '../data/repositories/user_data_repository.dart';
import 'photo_store.dart';
import 'vision_service.dart';

/// Result of one tap of the shutter, for the scanner UI.
class ScanResult {
  const ScanResult(this.outcome, this.photoId, this.photo);

  final ScanOutcome outcome;
  final String photoId;

  /// The child's photo, shown on the result card.
  final Uint8List photo;
}

/// Everything that happens after the shutter (spec §5 Scanner, §7):
///
/// 1. The photo is kept: saved on the device, uploaded in the background,
///    and recorded in `photos` whatever the outcome (D37).
/// 2. Gemini (via `identify_object`) says what it is.
/// 3. Found: the word goes in the Backpack with this photo, XP and streak
///    update, and if the scanner was opened from the map's active node,
///    that lesson is completed. Retry: nothing else changes. No
///    connection: the scan is queued and checked later.
class ScanFlow {
  ScanFlow({
    required this.vision,
    required this.repo,
    required this.photos,
    required this.store,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final VisionService vision;
  final UserDataRepository repo;
  final PhotoStore photos;
  final KeyValueStore store;
  final DateTime Function() _now;

  Future<ScanResult> scan(
    Uint8List jpeg, {
    Lesson? lesson,
    List<Lesson> ordered = const [],
  }) async {
    final takenAt = _now();
    final photoId = PhotoStore.newId(takenAt);
    await photos.keep(photoId, jpeg);
    final upload = photos.upload(photoId);

    final outcome = await vision.identify(jpeg);
    await _settle(outcome, photoId, takenAt, upload, lesson: lesson, ordered: ordered);
    return ScanResult(outcome, photoId, jpeg);
  }

  Future<void> _settle(
    ScanOutcome outcome,
    String photoId,
    DateTime takenAt,
    Future<String?> upload, {
    Lesson? lesson,
    List<Lesson> ordered = const [],
  }) async {
    switch (outcome) {
      case ScanFound(:final word):
        await photos.linkWord(photoId, word.id);
        await repo.recordPhoto(PhotoRecord(
            id: photoId, takenAt: takenAt, status: 'found', wordId: word.id));
        await repo.recordScan(word.toFound(photoId: photoId, at: takenAt));
        if (lesson != null && !lesson.isChest) {
          await repo.completeLesson(lesson, ordered);
        }
        unawaited(upload.then((url) {
          if (url != null) repo.attachPhotoUrl(photoId, url, wordId: word.id);
        }));
      case ScanRetry():
        await repo.recordPhoto(
            PhotoRecord(id: photoId, takenAt: takenAt, status: 'retry'));
        unawaited(upload.then((url) {
          if (url != null) repo.attachPhotoUrl(photoId, url);
        }));
      case ScanQueued():
        await repo.recordPhoto(
            PhotoRecord(id: photoId, takenAt: takenAt, status: 'queued'));
        await _enqueue(photoId, takenAt, lesson?.id);
    }
  }

  // ---------- offline queue ----------

  List<Map<String, dynamic>> get _queue {
    final v = store.read(StoreKeys.scanQueue);
    return v is List ? [for (final e in v) Map<String, dynamic>.from(e as Map)] : [];
  }

  int get queuedCount => _queue.length;

  Future<void> _enqueue(String photoId, DateTime takenAt, String? lessonId) =>
      store.write(StoreKeys.scanQueue, [
        ..._queue,
        {'photoId': photoId, 'takenAt': takenAt.toIso8601String(), 'lessonId': lessonId},
      ]);

  /// Checks queued scans now that we may be online. Stops at the first one
  /// that still can't reach the server. Returns how many were settled.
  Future<int> drainQueue(List<Lesson> ordered) async {
    var done = 0;
    for (final item in List.of(_queue)) {
      final photoId = item['photoId'] as String;
      final jpeg = photos.local(photoId);
      final remaining = _queue.where((e) => e['photoId'] != photoId).toList();
      if (jpeg == null) {
        await store.write(StoreKeys.scanQueue, remaining);
        continue;
      }
      final outcome = await vision.identify(jpeg);
      if (outcome is ScanQueued) break;
      await store.write(StoreKeys.scanQueue, remaining);
      final lessonId = item['lessonId'] as String?;
      final lesson = lessonId == null
          ? null
          : ordered.where((l) => l.id == lessonId).firstOrNull;
      await _settle(outcome, photoId, DateTime.parse(item['takenAt'] as String),
          photos.upload(photoId),
          lesson: lesson, ordered: ordered);
      done++;
    }
    return done;
  }

  /// Background sync: queued scans, then queued photo uploads.
  Future<void> sync(List<Lesson> ordered) async {
    await drainQueue(ordered);
    await photos.drainUploads((id, url, wordId) => repo.attachPhotoUrl(id, url, wordId: wordId));
  }
}
