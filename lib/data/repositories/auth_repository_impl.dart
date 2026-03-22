import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../services/auth_persistence_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._persistenceService);

  final AuthPersistenceService _persistenceService;

  @override
  Future<AppUser?> getCurrentUser() async {
    final username = await _persistenceService.getSession();
    if (username == null) {
      return null;
    }

    return AppUser(
      id: 'me',
      name: 'Demo User',
      username: username,
    );
  }

  @override
  Future<AppUser> signIn() async {
    const user = AppUser(
      id: 'me',
      name: 'Demo User',
      username: 'demo_user',
    );
    await _persistenceService.saveSession(user.username);
    return user;
  }

  @override
  Future<void> signOut() {
    return _persistenceService.clearSession();
  }
}
