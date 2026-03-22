import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/storage_keys.dart';
import '../domain/models/auth_session.dart';
import '../domain/models/login_mode.dart';

class AuthPersistenceService {
  Future<void> saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.authSession,
      jsonEncode(session.toJson()),
    );
  }

  Future<AuthSession?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.authSession);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await prefs.remove(StorageKeys.authSession);
        return null;
      }
      return AuthSession.fromJson(decoded);
    } on FormatException {
      final legacySession = _tryParseLegacySession(raw);
      if (legacySession != null) {
        await saveSession(legacySession);
        return legacySession;
      }

      await prefs.remove(StorageKeys.authSession);
      return null;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.authSession);
  }

  AuthSession? _tryParseLegacySession(String raw) {
    final username = raw.trim();
    if (username.isEmpty) {
      return null;
    }

    return AuthSession(
      userId: 'me',
      username: username,
      displayName: username,
      loginMode: LoginMode.dummy,
    );
  }
}
