import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/auth_repository_impl.dart';
import '../../../../domain/models/app_user.dart';
import '../../../../domain/repositories/auth_repository.dart';
import '../../../../services/auth_persistence_service.dart';

final authPersistenceServiceProvider = Provider<AuthPersistenceService>(
  (ref) => AuthPersistenceService(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authPersistenceServiceProvider));
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);

class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    return ref.read(authRepositoryProvider).getCurrentUser();
  }

  Future<void> signIn() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signIn(),
    );
  }

  Future<void> signOut() async {
    final repo = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    await repo.signOut();
    state = const AsyncData(null);
  }
}
