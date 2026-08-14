import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Authentication Service - Apple ID & Google Sign-In
class AuthService {
  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  GoogleSignIn? _googleSignInInstance;
  GoogleSignIn get _googleSignIn => _googleSignInInstance ??= GoogleSignIn(
        clientId: kIsWeb ? 'dummy-client-id.apps.googleusercontent.com' : null,
        scopes: const ['email', 'profile'],
      );

  User? get currentUser => _auth?.currentUser;
  bool get isLoggedIn => _auth?.currentUser != null;

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth?.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with Apple
  Future<UserCredential?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      return await _auth?.signInWithCredential(oauthCredential);
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth?.signOut();
  }

  /// Get user display name
  String get displayName {
    final user = currentUser;
    if (user == null) return '';
    return user.displayName ?? user.email ?? 'Wholesale Customer';
  }

  /// Get user email
  String? get email => currentUser?.email;
}
