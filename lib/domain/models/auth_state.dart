import 'app_user.dart';
import 'auth_session.dart';
import 'login_mode.dart';

class AuthState {
  const AuthState({
    required this.user,
    required this.session,
    required this.availableLoginMode,
  });

  final AppUser? user;
  final AuthSession? session;
  final LoginMode availableLoginMode;

  bool get isAuthenticated => user != null && session != null;

  String get loginModeLabel {
    switch (availableLoginMode) {
      case LoginMode.dummy:
        return 'Dummy login';
      case LoginMode.xOAuth:
        return 'X OAuth';
    }
  }
}
