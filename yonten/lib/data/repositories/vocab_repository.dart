import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../models/word.dart';

/// The global word catalog, `vocab/{wordId}` (read-only for clients).
abstract interface class VocabRepository {
  Future<VocabEntry?> get(String wordId);
  Future<List<VocabEntry>> starter();
}

/// Bundled starter list (`assets/data/vocab_seed.json`). Every entry is
/// unverified until a fluent speaker confirms it.
class LocalVocabRepository implements VocabRepository {
  LocalVocabRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  List<VocabEntry>? _cache;

  static const asset = 'assets/data/vocab_seed.json';

  @override
  Future<List<VocabEntry>> starter() async {
    if (_cache != null) return _cache!;
    final root =
        jsonDecode(await _bundle.loadString(asset, cache: false)) as Map<String, dynamic>;
    return _cache = [
      for (final e in root['vocab'] as List)
        VocabEntry.fromMap(
            (e as Map)['id'] as String, Map<String, dynamic>.from(e)),
    ];
  }

  @override
  Future<VocabEntry?> get(String wordId) async {
    for (final v in await starter()) {
      if (v.id == wordId) return v;
    }
    return null;
  }
}

class FirestoreVocabRepository implements VocabRepository {
  FirestoreVocabRepository(this._db, this._fallback);

  final FirebaseFirestore _db;
  final VocabRepository _fallback;

  @override
  Future<VocabEntry?> get(String wordId) async {
    try {
      final d = await _db
          .collection('vocab')
          .doc(wordId)
          .get()
          .timeout(const Duration(seconds: 4));
      if (d.exists) return VocabEntry.fromMap(d.id, d.data()!);
    } catch (_) {}
    return _fallback.get(wordId);
  }

  @override
  Future<List<VocabEntry>> starter() => _fallback.starter();
}
