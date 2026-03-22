import '../models/app_user.dart';

abstract interface class AuthRepository {
  Future<AppUser?> getCurrentUser();
  Future<AppUser> signIn();
  Future<void> signOut();
}
