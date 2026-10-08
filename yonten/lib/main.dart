import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'firebase_options.dart';

/// Connect to Firebase and sign the child in anonymously. If Firebase
/// isn't reachable, the app still opens in local mode (AGENTS.md:
/// unconfigured services must never break the screen).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final status = await _bootstrap();
  runApp(ProviderScope(child: YontenApp(status: status)));
}

Future<String> _bootstrap() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    return 'Local mode (Firebase unavailable)';
  }
  try {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
    return 'Signed in: ${user?.uid ?? 'unknown'}';
  } catch (e) {
    return 'Local mode (anonymous sign-in unavailable)';
  }
}
