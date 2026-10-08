import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

/// Phase 0 bootstrap: connect to Firebase and sign the child in anonymously.
/// If Firebase isn't reachable, the app still opens in local mode (AGENTS.md:
/// unconfigured services must never break the screen).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final status = await _bootstrap();
  runApp(YontenApp(status: status));
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

class YontenApp extends StatelessWidget {
  const YontenApp({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yonten',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Yonten', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 12),
              Text(status),
            ],
          ),
        ),
      ),
    );
  }
}
