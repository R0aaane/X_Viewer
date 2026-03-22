import '../core/constants/x_auth_constants.dart';

class XAuthConfigService {
  const XAuthConfigService({
    this.clientId = const String.fromEnvironment('X_CLIENT_ID'),
    this.redirectUri = const String.fromEnvironment(
      'X_REDIRECT_URI',
      defaultValue: XAuthConstants.defaultRedirectUri,
    ),
  });

  final String clientId;
  final String redirectUri;

  bool get isConfigured => clientId.isNotEmpty && redirectUri.isNotEmpty;
}
