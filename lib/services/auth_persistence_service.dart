import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors/app_exception.dart';
import '../core/constants/storage_keys.dart';
import '../domain/models/auth_session.dart';
import '../domain/models/oauth_token_bundle.dart';
import 'secure_token_storage_service.dart';

class AuthPersistenceService {
  AuthPersistenceService(this._secureTokenStorageService);

  final SecureTokenStorageService _secureTokenStorageService;

  Future<void> saveSession(AuthSession session) async {
    if (!session.hasAccessToken) {
      throw const AppException(
        'Cannot persist an auth session without an access token.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await _secureTokenStorageService.saveTokens(
      OAuthTokenBundle(
        accessToken: session.accessToken!,
        refreshToken: session.refreshToken,
        expiresAt: session.expiresAt,
      ),
    );
    await prefs.setString(
      StorageKeys.authSession,
      jsonEncode(
        session
            .copyWith(
              clearAccessToken: true,
              clearRefreshToken: true,
              clearExpiresAt: true,
            )
            .toJson(),
      ),
    );
  }

  Future<AuthSession?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.authSession);
    if (raw == null || raw.isEmpty) {
      await _secureTokenStorageService.clearTokens();
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await clearSession();
        return null;
      }

      final session = AuthSession.fromJson(decoded);
      final tokens = await _secureTokenStorageService.readTokens();
      if (session.userId.isEmpty ||
          session.username.isEmpty ||
          session.displayName.isEmpty ||
          tokens == null ||
          !tokens.hasAccessToken) {
        await clearSession();
        return null;
      }

      return session.copyWith(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expiresAt: tokens.expiresAt,
      );
    } on FormatException {
      await clearSession();
      return null;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.authSession);
    await _secureTokenStorageService.clearTokens();
  }
}
