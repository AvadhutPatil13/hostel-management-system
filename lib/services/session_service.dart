import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/backend_config.dart';

class SessionService {
  SessionService._();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        if (map.isEmpty) return null;
        return map;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.trim().isEmpty) return null;
    return token;
  }

  static Future<void> clear() async {
    if (BackendConfig.useFirebase) {
      await FirebaseAuth.instance.signOut();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// Alias for [clear] with a name that reads better at call sites like a
  /// "Logout" button. Behaves identically — clears the local session and,
  /// when Firebase is the active backend, signs out of Firebase Auth too.
  static Future<void> logout() => clear();

  /// Updates the signed-in user's password.
  ///
  /// Only supported when `BackendConfig.useFirebase` is true and the
  /// current user signed in with an email/password credential — Firebase
  /// requires re-authentication with the current password before it will
  /// allow a password change, so that happens first.
  ///
  /// Throws a [StateError] when Firebase isn't the active backend or no
  /// user is signed in, and rethrows any [FirebaseAuthException] from
  /// re-authentication or the update itself (e.g. wrong current password,
  /// weak new password) so the caller can show a specific message.
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!BackendConfig.useFirebase) {
      throw StateError(
        'Password changes require the Firebase backend to be enabled. '
        'Connect this action to your authentication service.',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (user == null || email == null) {
      throw StateError('No signed-in user found.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }
}