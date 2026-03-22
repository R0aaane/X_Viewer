import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_environment.dart';
import '../../../../core/constants/x_api_constants.dart';
import '../../../../data/datasources/x_auth_client.dart';
import '../../../../data/repositories/auth_repository_impl.dart';
import '../../../../domain/models/auth_state.dart';
import '../../../../domain/repositories/auth_repository.dart';
import '../../../../services/auth_persistence_service.dart';
import '../../../../services/service_providers.dart';
import '../../../../services/x_auth_callback_service.dart';
import '../../../../services/x_auth_config_service.dart';
import '../../../../services/x_oauth_service.dart';

final authPersistenceServiceProvider = Provider<AuthPersistenceService>(
  (ref) => AuthPersistenceService(),
);

final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => AppEnvironment.fromDefines(),
);

final xAuthConfigServiceProvider = Provider<XAuthConfigService>(
  (ref) => const XAuthConfigService(),
);

final authDioProvider = Provider<Dio>(
  (ref) => Dio(
    BaseOptions(
      baseUrl: XApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ),
  ),
);

final xAuthCallbackServiceProvider = Provider<XAuthCallbackService>(
  (ref) => const XAuthCallbackService(),
);

final xAuthClientProvider = Provider<XAuthClient>(
  (ref) => XAuthClient(dio: ref.watch(authDioProvider)),
);

final xOAuthServiceProvider = Provider<XOAuthService>(
  (ref) => XOAuthService(
    config: ref.watch(xAuthConfigServiceProvider),
    authClient: ref.watch(xAuthClientProvider),
    linkLauncherService: ref.watch(linkLauncherServiceProvider),
    callbackService: ref.watch(xAuthCallbackServiceProvider),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  return AuthRepositoryImpl(
    ref.watch(authPersistenceServiceProvider),
    ref.watch(xOAuthServiceProvider),
    mode: environment.loginMode,
  );
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final repository = ref.read(authRepositoryProvider);
    final user = await repository.getCurrentUser();
    final session = await repository.getCurrentSession();

    return AuthState(
      user: user,
      session: session,
      availableLoginMode: repository.loginMode,
    );
  }

  Future<void> signIn() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.signIn();
      final session = await repository.getCurrentSession();
      return AuthState(
        user: user,
        session: session,
        availableLoginMode: repository.loginMode,
      );
    });
  }

  Future<void> signOut() async {
    final repo = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    await repo.signOut();
    state = AsyncData(
      AuthState(
        user: null,
        session: null,
        availableLoginMode: repo.loginMode,
      ),
    );
  }
}
