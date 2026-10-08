import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:yonten/data/curriculum_providers.dart';
import 'package:yonten/data/local_store.dart';
import 'package:yonten/data/repositories/local_user_data.dart';
import 'package:yonten/data/repositories/vocab_repository.dart';
import 'package:yonten/services/photo_store.dart';
import 'package:yonten/services/scan_flow.dart';
import 'package:yonten/services/vision_service.dart';

import 'helpers.dart';

class FakeUploader implements PhotoUploader {
  bool online = true;
  final uploaded = <String>[];

  @override
  Future<String> upload(String photoId, Uint8List jpeg) async {
    if (!online) throw Exception('offline');
    uploaded.add(photoId);
    return 'https://storage.test/$photoId.jpg';
  }
}

void main() {
  final ordered = lessonsInOrder(loadUnit1());
  final ka = ordered.first;
  final photo = Uint8List.fromList([1, 2, 3, 4]);
  const unverified = ScanFound(ScanWord(
      id: 'whisk', english: 'whisk', tibetan: '', verified: false));

  late MemoryStore store;
  late LocalUserData repo;
  late FakeUploader uploader;
  late PhotoStore photos;

  ScanFlow flow(List<ScanOutcome> outcomes) => ScanFlow(
        vision: MockVisionService(LocalVocabRepository(), script: outcomes),
        repo: repo,
        photos: photos,
        store: store,
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    store = MemoryStore();
    repo = LocalUserData(store);
    uploader = FakeUploader();
    photos = PhotoStore(store, uploader: uploader);
  });

  test('a find keeps the photo and the card uses it', () async {
    final r = await flow([verifiedApple]).scan(photo);
    await settle();
    expect(photos.local(r.photoId), photo);
    final words = await repo.watchWords().first;
    expect(words.single.id, 'apple');
    expect(words.single.photoId, r.photoId);
    expect(words.single.imageUrl, 'https://storage.test/${r.photoId}.jpg');
    final recs = await repo.watchPhotos().first;
    expect(recs.single.status, 'found');
    expect(recs.single.wordId, 'apple');
    expect((await repo.watchProfile().first).xp, 10);
  });

  test('every photo is kept, even when Yonten is not sure', () async {
    final f = flow([const ScanRetry('low_confidence'), verifiedApple]);
    final a = await f.scan(photo);
    final b = await f.scan(photo);
    await settle();
    final recs = await repo.watchPhotos().first;
    expect(recs.map((p) => p.status).toSet(), {'retry', 'found'});
    expect(photos.local(a.photoId), isNotNull);
    expect(photos.local(b.photoId), isNotNull);
    expect(await repo.watchWords().first, hasLength(1));
  });

  test('finding a word again shows the newest photo', () async {
    final f = flow([verifiedApple, verifiedApple]);
    await f.scan(photo);
    final second = await f.scan(photo);
    await settle();
    final words = await repo.watchWords().first;
    expect(words.single.photoId, second.photoId);
    expect(await repo.watchPhotos().first, hasLength(2));
  });

  test('a scan from the active node completes that lesson', () async {
    await flow([verifiedApple]).scan(photo, lesson: ka, ordered: ordered);
    final p = (await repo.watchProfile().first).progress;
    expect(p.isDone('unit1-ka'), isTrue);
    expect(p.currentLessonId, 'unit1-kha');
  });

  test('a retry never moves the map', () async {
    await flow([const ScanRetry()]).scan(photo, lesson: ka, ordered: ordered);
    expect((await repo.watchProfile().first).progress.completed, isEmpty);
  });

  test('unverified Tibetan never reaches the Backpack', () async {
    await flow([unverified]).scan(photo);
    final w = (await repo.watchWords().first).single;
    expect(w.tibetan, '');
    expect(w.english, 'whisk');
  });

  test('offline: the scan waits in the queue and is checked later', () async {
    uploader.online = false;
    final queued = flow([const ScanQueued()]);
    final r = await queued.scan(photo, lesson: ka, ordered: ordered);
    expect(queued.queuedCount, 1);
    expect(photos.pendingCount, 1);
    expect((await repo.watchPhotos().first).single.status, 'queued');
    expect(await repo.watchWords().first, isEmpty);

    // Back online.
    uploader.online = true;
    final online = flow([verifiedApple]);
    await online.sync(ordered);
    await settle();
    expect(online.queuedCount, 0);
    expect(photos.pendingCount, 0);
    final w = (await repo.watchWords().first).single;
    expect(w.photoId, r.photoId);
    expect(w.imageUrl, 'https://storage.test/${r.photoId}.jpg');
    expect((await repo.watchProfile().first).progress.isDone('unit1-ka'), isTrue);
  });

  test('a queued scan still offline stays queued', () async {
    final f = flow([const ScanQueued()]);
    await f.scan(photo);
    expect(await f.drainQueue(ordered), 0);
    expect(f.queuedCount, 1);
  });

  test('ScanWord drops unverified Tibetan even if the server sent it', () {
    final w = ScanWord.fromMap({
      'id': 'x', 'english': 'x', 'tibetan': 'ཀ', 'verified': false, 'audioUrl': 'u',
    });
    expect(w.tibetan, '');
    expect(w.audioUrl, isNull);
    expect(w.showTibetan, isFalse);
  });

  test('local mode keeps every photo on the device', () async {
    photos = PhotoStore(store, keepOnDevice: 1);
    final f = flow([verifiedApple, verifiedApple, verifiedApple]);
    final ids = [for (var i = 0; i < 3; i++) (await f.scan(photo)).photoId];
    for (final id in ids) {
      expect(photos.local(id), isNotNull);
    }
  });
}
