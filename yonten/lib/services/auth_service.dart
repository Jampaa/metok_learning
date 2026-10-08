import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Auth (spec §7): the child is signed in anonymously on first
/// launch so they can play immediately. Phase 8 adds parent account
/// linking with `linkWithCredential`, which keeps the same uid.
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  /// Returns the signed-in uid, signing in anonymously if needed. On web
  /// the saved session is restored asynchronously, so wait for the first
  /// auth state before deciding there's no user.
  Future<String?> ensureSignedIn() async {
    final restored = await _auth
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () => _auth.currentUser);
    if (restored != null) return restored.uid;
    final cred = await _auth.signInAnonymously();
    return cred.user?.uid;
  }

  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;
}
