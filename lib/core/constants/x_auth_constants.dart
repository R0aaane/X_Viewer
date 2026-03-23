abstract final class XAuthConstants {
  static const authorizationHost = 'twitter.com';
  static const authorizationPath = '/i/oauth2/authorize';
  static const tokenEndpoint = 'https://api.x.com/2/oauth2/token';
  static const currentUserEndpoint = 'https://api.x.com/2/users/me';
  static const defaultClientId = String.fromEnvironment(
    'X_CLIENT_ID',
    defaultValue: 'TODO_SET_X_CLIENT_ID',
  );
  static const callbackScheme = 'xviewer';
  static const callbackHost = 'auth';
  static const callbackPath = '/callback';
  static const defaultRedirectUri =
      '$callbackScheme://$callbackHost$callbackPath';
  static const callbackUriPrefix = defaultRedirectUri;
  static const defaultScopes = <String>[
    'tweet.read',
    'users.read',
    'offline.access',
  ];
  static const codeChallengeMethod = 'S256';
  static const responseType = 'code';
  static const callbackTimeout = Duration(minutes: 3);
}
