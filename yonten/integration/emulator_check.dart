// Emulator smoke check: runs the real Firestore repositories in a browser
// against the local emulators and prints PASS/FAIL lines.
//
//   firebase emulators:start            (repo root, Java 21)
//   functions/venv/bin/python -I functions/seed_curriculum.py --emulator
//   cd yonten && flutter run -d chrome -t integration/emulator_check.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yonten/data/curriculum_providers.dart';
import 'package:yonten/data/local_store.dart';
import 'package:yonten/data/models/word.dart';
import 'package:yonten/data/repositories/curriculum_repository.dart';
import 'package:yonten/data/repositories/firestore_user_data.dart';
import 'package:yonten/firebase_options.dart';
import 'package:yonten/services/photo_store.dart';
import 'package:yonten/services/providers.dart';
import 'package:yonten/services/scan_flow.dart';
import 'package:yonten/services/vision_service.dart';

final _lines = <String>[];

void _log(bool ok, String what) {
  final line = '${ok ? 'PASS' : 'FAIL'} $what';
  _lines.add(line);
  debugPrint('EMULATOR_CHECK $line');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final db = FirebaseFirestore.instance..useFirestoreEmulator('localhost', 8085);
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  functionsInstance().useFunctionsEmulator('localhost', 5001);
  await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  final cred = await FirebaseAuth.instance.signInAnonymously();
  final uid = cred.user!.uid;
  _log(true, 'signed in anonymously as $uid');

  final curriculum = FirestoreCurriculumRepository(db, LocalCurriculumRepository());
  final chapters = await curriculum.chapters();
  _log(curriculum.source == 'firestore', 'curriculum read from ${curriculum.source}');
  final ordered = lessonsInOrder(chapters);

  final repo = FirestoreUserData(db: db, uid: uid, cache: MemoryStore());
  await repo.watchProfile().firstWhere((p) => true);
  await Future<void>.delayed(const Duration(seconds: 1));

  await repo.completeLesson(ordered.first, ordered);
  final chest = ordered.firstWhere((l) => l.isChest);
  await repo.completeLesson(chest, ordered);
  await repo.completeLesson(chest, ordered);
  await repo.recordScan(FoundWord(
      id: 'apple', english: 'apple', tibetan: 'ཀུ་ཤུ', verified: false,
      foundAt: DateTime.now()));
  await repo.recordScan(FoundWord(
      id: 'apple', english: 'apple', tibetan: 'ཀུ་ཤུ', verified: false,
      foundAt: DateTime.now()));

  final user = (await db.doc('users/$uid').get(const GetOptions(source: Source.server))).data()!;
  final progress = Map<String, dynamic>.from(user['progress'] as Map);
  final done = List<String>.from(progress['completedLessonIds'] as List);
  _log(done.contains('unit1-ka') && done.contains(chest.id), 'completed lessons saved: $done');
  _log(progress['currentLessonId'] == 'unit1-kha', 'current lesson moved to ${progress['currentLessonId']}');
  final stats = Map<String, dynamic>.from(user['stats'] as Map);
  _log(stats['lessons'] == 1, 'chest did not count as a lesson (lessons=${stats['lessons']})');
  _log(stats['words'] == 1 && stats['hunts'] == 2, 'duplicate word counted once (words=${stats['words']}, hunts=${stats['hunts']})');
  _log(user['xp'] == 20, 'xp=${user['xp']}');
  _log((user['streak'] as Map)['count'] == 1, 'streak=${(user['streak'] as Map)['count']}');
  final stickers = await db.collection('users/$uid/stickers').get(const GetOptions(source: Source.server));
  _log(stickers.docs.map((d) => d.id).toList().join(',') == 'chorten', 'sticker granted once: ${stickers.docs.map((d) => d.id).toList()}');

  // Rules: rewinding progress must be rejected by the server.
  try {
    await db.doc('users/$uid').update({'progress.completedLessonIds': <String>[]});
    _log(false, 'rewind was allowed');
  } on FirebaseException catch (e) {
    _log(e.code == 'permission-denied', 'rewind rejected (${e.code})');
  }

  // Rules: another user's data is off limits.
  try {
    await db.doc('users/someone-else').get(const GetOptions(source: Source.server));
    _log(false, 'read another user');
  } on FirebaseException catch (e) {
    _log(e.code == 'permission-denied', 'other user blocked (${e.code})');
  }

  // Scan: the app's own ScanFlow, through the Functions emulator (real
  // Gemini) and the Storage emulator. A plain gray photo has no object, so
  // Gemini should say "not sure": a retry, with the photo still kept.
  final hive2 = MemoryStore();
  final flow = ScanFlow(
    vision: FunctionsVisionService(functionsInstance()),
    repo: repo,
    photos: PhotoStore(hive2,
        uploader: FirebasePhotoUploader(FirebaseStorage.instance, uid)),
    store: hive2,
  );
  final gray = img.Image(width: 320, height: 240)..clear(img.ColorRgb8(128, 128, 128));
  final scan = await flow.scan(Uint8List.fromList(img.encodeJpg(gray)));
  _log(scan.outcome is ScanRetry, 'blank photo -> ${scan.outcome.runtimeType} via identify_object');
  await Future<void>.delayed(const Duration(seconds: 2));
  final photoDoc = (await db.doc('users/$uid/photos/${scan.photoId}')
          .get(const GetOptions(source: Source.server)))
      .data();
  _log(photoDoc?['status'] == 'retry' && (photoDoc?['url'] as String?)?.contains('9199') == true,
      'photo kept: status=${photoDoc?['status']}, uploaded=${photoDoc?['url'] != null}');
  final stored = await FirebaseStorage.instance
      .ref('users/$uid/photos/${scan.photoId}.jpg')
      .getMetadata();
  _log(stored.contentType == 'image/jpeg', 'photo in Storage (${stored.size} bytes)');

  // Offline. (disableNetwork() doesn't stop transactions in the web SDK,
  // so it can't simulate this.) A second app instance points at a port
  // where nothing listens: every server call fails, the transaction gives
  // up, and the repository falls back to a local merge write built from
  // the Hive profile cache.
  final offlineApp = await Firebase.initializeApp(
      name: 'offline', options: DefaultFirebaseOptions.currentPlatform);
  final deadDb = FirebaseFirestore.instanceFor(app: offlineApp)
    ..useFirestoreEmulator('localhost', 9);
  final hive = MemoryStore();
  await hive.write(StoreKeys.profileCache, user);
  final offlineRepo = FirestoreUserData(db: deadDb, uid: uid, cache: hive);
  final kha = ordered.firstWhere((l) => l.id == 'unit1-kha');
  final sw = Stopwatch()..start();
  await offlineRepo.completeLesson(kha, ordered);
  final returnedAfter = sw.elapsedMilliseconds;
  final seen = await deadDb
      .doc('users/$uid')
      .snapshots()
      .map((s) => s.data())
      .firstWhere((d) => d != null)
      .timeout(const Duration(seconds: 3), onTimeout: () => null);
  final local = seen == null ? null : Map<String, dynamic>.from(seen['progress'] as Map);
  _log(local != null &&
          (local['completedLessonIds'] as List).contains('unit1-kha') &&
          local['currentLessonId'] == 'unit1-ga',
      'offline: lesson saved locally (current=${local?['currentLessonId']}) '
      'after the $returnedAfter ms server timeout');

  debugPrint('EMULATOR_CHECK DONE ${_lines.where((l) => l.startsWith('FAIL')).isEmpty ? 'ALL PASS' : 'FAILURES'}');
  runApp(MaterialApp(home: Scaffold(body: ListView(children: [for (final l in _lines) Text(l)]))));
}
