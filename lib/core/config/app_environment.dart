import '../../domain/models/login_mode.dart';

class AppEnvironment {
  const AppEnvironment({
    required this.loginMode,
    required this.enableRealXApi,
  });

  final LoginMode loginMode;
  final bool enableRealXApi;

  bool get isDummyMode => loginMode == LoginMode.dummy;

  factory AppEnvironment.fromDefines() {
    const loginModeValue = String.fromEnvironment(
      'LOGIN_MODE',
      defaultValue: 'dummy',
    );
    const enableRealXApiValue = bool.fromEnvironment(
      'ENABLE_REAL_X_API',
      defaultValue: false,
    );

    return AppEnvironment(
      loginMode: loginModeValue == LoginMode.xOAuth.name
          ? LoginMode.xOAuth
          : LoginMode.dummy,
      enableRealXApi: enableRealXApiValue,
    );
  }
}
