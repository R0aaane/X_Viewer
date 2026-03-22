import 'dart:async';

import 'package:flutter/services.dart';

import '../core/errors/app_exception.dart';

class XAuthCallbackService {
  const XAuthCallbackService();

  static const MethodChannel _methodChannel = MethodChannel(
    'xviewer/auth_callback',
  );
  static const EventChannel _eventChannel = EventChannel(
    'xviewer/auth_callback/events',
  );

  Future<Uri> waitForCallback(
    String redirectUri, {
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final pendingUrl = await _consumePendingCallbackUrl();
    final pendingUri = _tryParseMatchingUri(pendingUrl, redirectUri);
    if (pendingUri != null) {
      return pendingUri;
    }

    try {
      return _eventChannel
          .receiveBroadcastStream()
          .where((event) => event is String)
          .cast<String>()
          .map((url) => _tryParseMatchingUri(url, redirectUri))
          .where((uri) => uri != null)
          .cast<Uri>()
          .first
          .timeout(timeout);
    } on MissingPluginException catch (error) {
      throw AppException(
        'X OAuth callback handling is not available on this platform.',
        details: error,
      );
    } on TimeoutException catch (error) {
      throw AppException(
        'Timed out waiting for the X OAuth callback.',
        details: error,
      );
    }
  }

  Future<String?> _consumePendingCallbackUrl() async {
    try {
      return await _methodChannel.invokeMethod<String>(
        'consumePendingCallbackUrl',
      );
    } on MissingPluginException {
      return null;
    }
  }

  Uri? _tryParseMatchingUri(String? rawUrl, String redirectUri) {
    if ((rawUrl ?? '').isEmpty) {
      return null;
    }

    final actual = Uri.tryParse(rawUrl!);
    final expected = Uri.tryParse(redirectUri);
    if (actual == null || expected == null) {
      return null;
    }

    final sameAuthority =
        actual.scheme == expected.scheme && actual.host == expected.host;
    final samePath = actual.path == expected.path;
    if (!sameAuthority || !samePath) {
      return null;
    }

    return actual;
  }
}
