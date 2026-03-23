import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/x_auth_constants.dart';
import '../core/errors/app_exception.dart';
import '../data/datasources/x_auth_client.dart';
import '../domain/models/auth_session.dart';
import '../domain/models/login_mode.dart';
import 'link_launcher_service.dart';
import 'x_auth_callback_service.dart';
import 'x_auth_config_service.dart';

class XOAuthService {
  XOAuthService({
    required XAuthConfigService config,
    required XAuthClient authClient,
    required LinkLauncherService linkLauncherService,
    required XAuthCallbackService callbackService,
  }) : _config = config,
       _authClient = authClient,
       _linkLauncherService = linkLauncherService,
       _callbackService = callbackService;

  final XAuthConfigService _config;
  final XAuthClient _authClient;
  final LinkLauncherService _linkLauncherService;
  final XAuthCallbackService _callbackService;

  Future<AuthSession> signIn() async {
    if (!_config.isConfigured) {
      throw const AppException(
        'X OAuth is not configured. Set X_CLIENT_ID and X_REDIRECT_URI.',
      );
    }

    final state = _randomString();
    final codeVerifier = _randomString(length: 96);
    final codeChallenge = _createCodeChallenge(codeVerifier);

    final callbackFuture = _callbackService.waitForCallback(
      _config.redirectUri,
      timeout: XAuthConstants.callbackTimeout,
    );
    final authorizeUri = _buildAuthorizationUri(
      state: state,
      codeChallenge: codeChallenge,
    );
    debugPrint(
      '[xviewer][flutter] Starting OAuth authorization. authorizeUrl=$authorizeUri',
    );

    await _linkLauncherService.openExternal(
      authorizeUri.toString(),
    );

    final callbackUri = await callbackFuture;
    debugPrint('[xviewer][flutter] OAuth callback received: $callbackUri');
    final error = callbackUri.queryParameters['error'];
    if ((error ?? '').isNotEmpty) {
      throw AppException(
        'X authorization was denied: $error',
        details: callbackUri.queryParameters['error_description'],
      );
    }

    final returnedState = callbackUri.queryParameters['state'] ?? '';
    final code = callbackUri.queryParameters['code'] ?? '';
    debugPrint(
      '[xviewer][flutter] OAuth callback parsed: scheme=${callbackUri.scheme}, host=${callbackUri.host}, path=${callbackUri.path}, code=$code, state=$returnedState, error=$error',
    );
    if (returnedState != state) {
      throw AppException(
        'X OAuth state verification failed.',
        details: callbackUri.toString(),
      );
    }

    if (code.isEmpty) {
      throw AppException(
        'X OAuth callback did not contain an authorization code.',
        details: callbackUri.toString(),
      );
    }

    debugPrint(
      '[xviewer][flutter] Starting token exchange. redirectUri=${_config.redirectUri} stateVerified=${returnedState == state}',
    );
    final token = await _authClient.exchangeCodeForToken(
      clientId: _config.clientId,
      code: code,
      codeVerifier: codeVerifier,
      redirectUri: _config.redirectUri,
    );
    final user = await _authClient.fetchCurrentUser(
      accessToken: token.accessToken,
    );

    return AuthSession(
      userId: user.id,
      username: user.username,
      displayName: user.name,
      loginMode: LoginMode.xOAuth,
      accessToken: token.accessToken,
      refreshToken: token.refreshToken,
      expiresAt: token.expiresIn == null
          ? null
          : DateTime.now().add(Duration(seconds: token.expiresIn!)),
    );
  }

  Uri _buildAuthorizationUri({
    required String state,
    required String codeChallenge,
  }) {
    return Uri.https(
      XAuthConstants.authorizationHost,
      XAuthConstants.authorizationPath,
      <String, String>{
        'client_id': _config.clientId,
        'redirect_uri': _config.redirectUri,
        'response_type': XAuthConstants.responseType,
        'scope': XAuthConstants.defaultScopes.join(' '),
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': XAuthConstants.codeChallengeMethod,
      },
    );
  }

  String _createCodeChallenge(String codeVerifier) {
    final digest = sha256.convert(utf8.encode(codeVerifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  String _randomString({int length = 64}) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
