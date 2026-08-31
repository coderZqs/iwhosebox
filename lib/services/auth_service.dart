import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authentication Service - Apple ID & Google Sign-In with Robust Local Persistence
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

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

  bool _isLoggedIn = false;
  String? _userId;
  String? _userName;
  String? _userEmail;
  String? _authProvider;
  bool _initialized = false;

  bool get isLoggedIn => _isLoggedIn || (_auth?.currentUser != null);
  User? get currentUser => _auth?.currentUser;
  String? get userId => _userId ?? _auth?.currentUser?.uid;
  String? get authProvider => _authProvider;

  /// Initialize local session from SharedPreferences
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool('auth_is_logged_in') ?? false;
      _userId = prefs.getString('auth_user_id');
      _userName = prefs.getString('auth_user_name');
      _userEmail = prefs.getString('auth_user_email');
      _authProvider = prefs.getString('auth_provider');

      // If Firebase has an active session, sync from Firebase
      final fbUser = _auth?.currentUser;
      if (fbUser != null) {
        _isLoggedIn = true;
        _userId ??= fbUser.uid;
        _userName ??= fbUser.displayName;
        _userEmail ??= fbUser.email;
      }
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('AuthService init error: $e');
      _initialized = true;
    }
  }

  /// Save session to SharedPreferences
  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auth_is_logged_in', _isLoggedIn);
      if (_userId != null) await prefs.setString('auth_user_id', _userId!);
      if (_userName != null) await prefs.setString('auth_user_name', _userName!);
      if (_userEmail != null) await prefs.setString('auth_user_email', _userEmail!);
      if (_authProvider != null) await prefs.setString('auth_provider', _authProvider!);
    } catch (e) {
      debugPrint('AuthService persist error: $e');
    }
  }

  /// Clear session from SharedPreferences
  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_is_logged_in');
      await prefs.remove('auth_user_id');
      await prefs.remove('auth_user_name');
      await prefs.remove('auth_user_email');
      await prefs.remove('auth_provider');
    } catch (e) {
      debugPrint('AuthService clear error: $e');
    }
  }

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

      UserCredential? userCred;
      if (_auth != null) {
        try {
          userCred = await _auth?.signInWithCredential(credential);
        } catch (e) {
          debugPrint('Firebase Google sign-in non-fatal: $e');
        }
      }

      _isLoggedIn = true;
      _userId = userCred?.user?.uid ?? googleUser.id;
      _userName = userCred?.user?.displayName ?? googleUser.displayName ?? 'Google User';
      _userEmail = userCred?.user?.email ?? googleUser.email;
      _authProvider = 'google';

      await _persistSession();
      notifyListeners();
      return userCred;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with Apple
  Future<AuthorizationCredentialAppleID> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Extract user information
      final String? givenName = appleCredential.givenName;
      final String? familyName = appleCredential.familyName;
      String? computedName;
      if (givenName != null || familyName != null) {
        computedName = [givenName, familyName].where((s) => s != null && s.isNotEmpty).join(' ').trim();
      }

      // Try Firebase Auth sync if available
      if (_auth != null && appleCredential.identityToken != null) {
        try {
          final oauthCredential = OAuthProvider("apple.com").credential(
            idToken: appleCredential.identityToken,
            accessToken: appleCredential.authorizationCode,
          );
          await _auth?.signInWithCredential(oauthCredential);
        } catch (e) {
          debugPrint('Firebase Apple sign-in non-fatal fallback: $e');
        }
      }

      _isLoggedIn = true;
      _userId = _auth?.currentUser?.uid ?? appleCredential.userIdentifier ?? 'apple_user_${DateTime.now().millisecondsSinceEpoch}';
      
      if (computedName != null && computedName.isNotEmpty) {
        _userName = computedName;
      } else if (_userName == null || _userName!.isEmpty) {
        _userName = _auth?.currentUser?.displayName ?? 'Apple User';
      }

      if (appleCredential.email != null && appleCredential.email!.isNotEmpty) {
        _userEmail = appleCredential.email;
      } else if (_userEmail == null || _userEmail!.isEmpty) {
        _userEmail = _auth?.currentUser?.email;
      }

      _authProvider = 'apple';

      await _persistSession();
      notifyListeners();

      return appleCredential;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await _auth?.signOut();
    } catch (_) {}

    _isLoggedIn = false;
    _userId = null;
    _userName = null;
    _userEmail = null;
    _authProvider = null;

    await _clearPersistedSession();
    notifyListeners();
  }

  /// Get user display name
  String get displayName {
    if (_userName != null && _userName!.isNotEmpty) return _userName!;
    final fbUser = _auth?.currentUser;
    if (fbUser?.displayName != null && fbUser!.displayName!.isNotEmpty) {
      return fbUser.displayName!;
    }
    if (_userEmail != null && _userEmail!.isNotEmpty) return _userEmail!;
    if (fbUser?.email != null && fbUser!.email!.isNotEmpty) {
      return fbUser.email!;
    }
    return 'Wholesale Customer';
  }

  /// Get user email
  String? get email => _userEmail ?? _auth?.currentUser?.email;
}
