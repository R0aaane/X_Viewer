import '../core/constants/x_auth_constants.dart';

class XAuthConfigService {
  const XAuthConfigService({
    this.clientId = XAuthConstants.defaultClientId,
    this.redirectUri = const String.fromEnvironment(
      'X_REDIRECT_URI',
      defaultValue: XAuthConstants.defaultRedirectUri,
    ),
    this.scopes = XAuthConstants.defaultScopes,
  });

  final String clientId;
  final String redirectUri;
  final List<String> scopes;

  bool get isConfigured =>
      clientId.isNotEmpty &&
      clientId != 'TODO_SET_X_CLIENT_ID' &&
      redirectUri.isNotEmpty;
}
