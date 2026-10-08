import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/curriculum_providers.dart';
import 'data/local_store.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/providers.dart';

/// `flutter run --dart-define=USE_EMULATORS=true` talks to the local
/// Firebase emulators (`firebase emulators:start`) instead of production.
const _useEmulators = bool.fromEnvironment('USE_EMULATORS');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await HiveStore.open();
  final backend = await _connect(store);
  runApp(ProviderScope(
    overrides: [backendProvider.overrideWithValue(backend)],
    child: YontenApp(status: _describe(backend)),
  ));
}

/// Starts Firebase and signs the child in anonymously. Any failure falls
/// back to local mode: the app still opens and saves progress on the
/// device (AGENTS.md: unconfigured services never break the screen).
Future<Backend> _connect(KeyValueStore store) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final db = FirebaseFirestore.instance;
    if (_useEmulators) {
      final host = defaultTargetPlatform == TargetPlatform.android && !kIsWeb
          ? '10.0.2.2'
          : 'localhost';
      db.useFirestoreEmulator(host, 8085);
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      functionsInstance().useFunctionsEmulator(host, 5001);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    }
    // Offline cache on every platform, including web (spec §7).
    db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    final uid = await AuthService(FirebaseAuth.instance).ensureSignedIn();
    return Backend(store: store, firebase: true, uid: uid);
  } catch (e) {
    debugPrint('Yonten: starting in local mode ($e)');
    return Backend(store: store);
  }
}

String _describe(Backend b) {
  if (!b.firebase) return 'Local mode (Firebase unavailable)';
  if (b.uid == null) return 'Local mode (not signed in)';
  return 'Signed in${_useEmulators ? ' (emulators)' : ''}: ${b.uid}';
}
