import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/curriculum_providers.dart';

/// Parent account linking (spec §7). The child plays on an anonymous
/// account; linking Google, Apple or email turns it into a permanent one
/// with the same uid, so all progress, words and photos are kept.
abstract interface class AccountLinker {
  bool get available;

  /// e.g. "Not linked yet" or "Linked: parent@example.com".
  String get status;
  bool get linked;

  /// Returns a message to show the parent.
  Future<String> linkGoogle();
  Future<String> linkApple();
  Future<String> linkEmail(String email, String password);
}

/// Local mode: nothing to link to.
class UnavailableLinker implements AccountLinker {
  const UnavailableLinker();

  @override
  bool get available => false;
  @override
  String get status => 'Accounts need an internet connection.';
  @override
  bool get linked => false;
  @override
  Future<String> linkGoogle() async => status;
  @override
  Future<String> linkApple() async => status;
  @override
  Future<String> linkEmail(String email, String password) async => status;
}

class FirebaseAccountLinker implements AccountLinker {
  FirebaseAccountLinker(this._auth);

  final FirebaseAuth _auth;

  @override
  bool get available => _auth.currentUser != null;

  @override
  bool get linked => !(_auth.currentUser?.isAnonymous ?? true);

  @override
  String get status {
    final u = _auth.currentUser;
    if (u == null) return 'Not signed in.';
    if (u.isAnonymous) return 'Not linked yet. Progress is saved on this device’s account.';
    final who = u.email ?? u.providerData.map((p) => p.email ?? p.providerId).join(', ');
    return 'Linked: $who';
  }

  Future<String> _withProvider(AuthProvider provider, String name) async {
    final u = _auth.currentUser;
    if (u == null) return 'Not signed in.';
    try {
      if (kIsWeb) {
        await u.linkWithPopup(provider);
      } else {
        await u.linkWithProvider(provider);
      }
      return '$name account linked. All progress is kept.';
    } on FirebaseAuthException catch (e) {
      return _explain(e);
    }
  }

  @override
  Future<String> linkGoogle() => _withProvider(GoogleAuthProvider(), 'Google');

  @override
  Future<String> linkApple() => _withProvider(AppleAuthProvider(), 'Apple');

  @override
  Future<String> linkEmail(String email, String password) async {
    final u = _auth.currentUser;
    if (u == null) return 'Not signed in.';
    try {
      await u.linkWithCredential(
          EmailAuthProvider.credential(email: email.trim(), password: password));
      return 'Email linked. All progress is kept.';
    } on FirebaseAuthException catch (e) {
      return _explain(e);
    }
  }

  static String _explain(FirebaseAuthException e) => switch (e.code) {
        'operation-not-allowed' =>
          'This sign-in method isn’t switched on yet in the Firebase console.',
        'credential-already-in-use' || 'email-already-in-use' =>
          'That account is already used by another child profile.',
        'provider-already-linked' => 'This account is already linked.',
        'invalid-email' => 'That email address doesn’t look right.',
        'weak-password' => 'Please use a password of at least 6 characters.',
        'popup-closed-by-user' || 'cancelled-popup-request' => 'Linking was cancelled.',
        'network-request-failed' => 'No internet connection. Try again later.',
        _ => 'Couldn’t link the account (${e.code}).',
      };
}

final accountLinkerProvider = Provider<AccountLinker>((ref) =>
    ref.watch(backendProvider).online
        ? FirebaseAccountLinker(FirebaseAuth.instance)
        : const UnavailableLinker());
