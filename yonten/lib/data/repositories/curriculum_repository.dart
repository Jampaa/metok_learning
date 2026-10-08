import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../models/curriculum.dart';

/// Where the map's chapters come from.
abstract interface class CurriculumRepository {
  Future<List<Chapter>> chapters();

  /// "firestore" or "local", for the gallery.
  String get source;
}

/// Milestone chest spacing for new chapters (spec §5: every 5 or 10 nodes).
abstract final class CurriculumConfig {
  static const chestInterval = 5;

  /// Builds a chapter's lessons from its letters, with a chest as every
  /// [interval]th node. Chapter 1 hand-places its chest instead (D25).
  static List<Lesson> lettersWithChests(
    String chapterId,
    List<(String id, String letter)> letters, {
    int interval = chestInterval,
    String rewardStickerId = 'chorten',
  }) {
    final lessons = <Lesson>[];
    var chest = 0;
    for (final (id, letter) in letters) {
      if ((lessons.length + 1) % interval == 0) {
        chest++;
        lessons.add(Lesson(
          id: '$chapterId-chest-$chest',
          order: lessons.length + 1,
          type: LessonType.chest,
          label: '',
          rewardStickerId: rewardStickerId,
        ));
      }
      lessons.add(Lesson(
        id: '$chapterId-$id',
        order: lessons.length + 1,
        type: LessonType.letter,
        label: letter,
        wordId: 'letter-$id',
      ));
    }
    return lessons;
  }
}

/// Bundled curriculum (`assets/data/curriculum.json`), the same file the
/// seed script uploads. Works with no connection at all.
class LocalCurriculumRepository implements CurriculumRepository {
  LocalCurriculumRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static const asset = 'assets/data/curriculum.json';

  @override
  String get source => 'local';

  @override
  Future<List<Chapter>> chapters() async =>
      parseCurriculum(await _bundle.loadString(asset, cache: false));
}

List<Chapter> parseCurriculum(String json) {
  final root = jsonDecode(json) as Map<String, dynamic>;
  return [
    for (final c in root['chapters'] as List)
      Chapter.fromMap(
        (c as Map)['id'] as String,
        Map<String, dynamic>.from(c),
      ),
  ]..sort((a, b) => a.order.compareTo(b.order));
}

/// `curriculum/{chapterId}` in Firestore (read-only for clients), falling
/// back to the bundled copy if it's empty, unreachable, or slow.
class FirestoreCurriculumRepository implements CurriculumRepository {
  FirestoreCurriculumRepository(this._db, this._fallback);

  final FirebaseFirestore _db;
  final CurriculumRepository _fallback;
  String _source = 'firestore';

  static const _timeout = Duration(seconds: 4);

  @override
  String get source => _source;

  @override
  Future<List<Chapter>> chapters() async {
    try {
      final q = await _db.collection('curriculum').get().timeout(_timeout);
      if (q.docs.isEmpty) throw StateError('curriculum is empty');
      _source = 'firestore';
      return [
        for (final d in q.docs) Chapter.fromMap(d.id, d.data()),
      ]..sort((a, b) => a.order.compareTo(b.order));
    } catch (_) {
      _source = 'local';
      return _fallback.chapters();
    }
  }
}
