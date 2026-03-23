import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/x_auth_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/models/app_user.dart';

class XAuthClient {
  XAuthClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<XTokenResponse> exchangeCodeForToken({
    required String clientId,
    required String code,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        XAuthConstants.tokenEndpoint,
        data: <String, dynamic>{
          'client_id': clientId,
          'code': code,
          'code_verifier': codeVerifier,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
        ),
      );
      debugPrint(
        '[xviewer][flutter] Token exchange response: status=${response.statusCode} body=${response.data}',
      );

      final body = response.data;
      if (body == null) {
        throw const AppException('X token response was empty.');
      }

      final accessToken = body['access_token'] as String? ?? '';
      if (accessToken.isEmpty) {
        throw AppException(
          'X token response did not include an access token.',
          details: body,
        );
      }

      return XTokenResponse(
        accessToken: accessToken,
        refreshToken: body['refresh_token'] as String?,
        expiresIn: (body['expires_in'] as num?)?.toInt(),
      );
    } on DioException catch (error) {
      debugPrint(
        '[xviewer][flutter] Token exchange failed: status=${error.response?.statusCode} body=${error.response?.data}',
      );
      throw AppException(
        'Failed to exchange the X authorization code for a token.',
        details: error.response?.data ?? error.message,
      );
    }
  }

  Future<AppUser> fetchCurrentUser({required String accessToken}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        XAuthConstants.currentUserEndpoint,
        options: Options(
          headers: <String, String>{'Authorization': 'Bearer $accessToken'},
          responseType: ResponseType.json,
        ),
      );

      final body = response.data;
      final data = body?['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw const AppException('X user response was empty.');
      }

      final id = data['id'] as String? ?? '';
      final name = data['name'] as String? ?? '';
      final username = data['username'] as String? ?? '';
      if (id.isEmpty || name.isEmpty || username.isEmpty) {
        throw AppException(
          'X user response did not include the required user fields.',
          details: body,
        );
      }

      return AppUser(
        id: id,
        name: name,
        username: username,
      );
    } on DioException catch (error) {
      throw AppException(
        'Failed to fetch the authenticated X user.',
        details: error.response?.data ?? error.message,
      );
    }
  }
}

class XTokenResponse {
  const XTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;
}
