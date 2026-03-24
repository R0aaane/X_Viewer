import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_routes.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/saved/presentation/screens/saved_media_detail_screen.dart';
import '../features/saved/presentation/screens/saved_media_screen.dart';
import '../features/timeline/presentation/screens/timeline_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.timeline,
        builder: (context, state) => const TimelineScreen(),
      ),
      GoRoute(
        path: AppRoutes.saved,
        builder: (context, state) => const SavedMediaScreen(),
      ),
      GoRoute(
        path: AppRoutes.savedDetail,
        builder: (context, state) {
          final recordId = state.pathParameters['recordId'] ?? '';
          return SavedMediaDetailScreen(recordId: recordId);
        },
      ),
    ],
  );
});
