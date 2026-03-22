import 'login_mode.dart';

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.loginMode,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  final String userId;
  final String username;
  final String displayName;
  final LoginMode loginMode;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  bool get hasAccessToken => (accessToken ?? '').isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'loginMode': loginMode.name,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      loginMode: LoginMode.values.firstWhere(
        (mode) => mode.name == json['loginMode'],
        orElse: () => LoginMode.dummy,
      ),
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.tryParse(json['expiresAt'] as String),
    );
  }
}
