import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/x_api_constants.dart';
import '../../../../data/adapters/x_timeline_adapter.dart';
import '../../../../data/datasources/dummy_x_api_client.dart';
import '../../../../data/datasources/x_api_client.dart';
import '../../../../data/mappers/x_timeline_includes_mapper.dart';
import '../../../../data/repositories/timeline_repository_impl.dart';
import '../../../../domain/models/media_post.dart';
import '../../../../domain/models/timeline_page.dart';
import '../../../../domain/repositories/timeline_repository.dart';
import '../../../../services/auth_persistence_service.dart';
import '../../../../services/timeline_media_extractor.dart';
import '../../../../services/x_timeline_request_builder.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../models/timeline_state.dart';

final dummyXApiClientProvider = Provider<DummyXApiClient>(
  (ref) => DummyXApiClient(),
);

final xApiDioProvider = Provider<Dio>(
  (ref) {
    final dio = Dio(
      BaseOptions(
        baseUrl: XApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
        ),
      );
    }
    return dio;
  },
);

final xTimelineRequestBuilderProvider = Provider<XTimelineRequestBuilder>(
  (ref) => const XTimelineRequestBuilder(),
);

final xTimelineIncludesMapperProvider = Provider<XTimelineIncludesMapper>(
  (ref) => const XTimelineIncludesMapper(),
);

final xApiClientProvider = Provider<XApiClient>((ref) {
  return XApiClient(
    dio: ref.watch(xApiDioProvider),
    requestBuilder: ref.watch(xTimelineRequestBuilderProvider),
  );
});

final xTimelineAdapterProvider = Provider<XTimelineAdapter>(
  (ref) => XTimelineAdapter(ref.watch(xTimelineIncludesMapperProvider)),
);

final timelineMediaExtractorProvider = Provider<TimelineMediaExtractor>(
  (ref) => TimelineMediaExtractor(),
);

final timelineAuthPersistenceServiceProvider = Provider<AuthPersistenceService>(
  (ref) => AuthPersistenceService(),
);

final timelineRepositoryProvider = Provider<TimelineRepository>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  return TimelineRepositoryImpl(
    ref.watch(dummyXApiClientProvider),
    ref.watch(xApiClientProvider),
    ref.watch(xTimelineAdapterProvider),
    ref.watch(timelineMediaExtractorProvider),
    ref.watch(timelineAuthPersistenceServiceProvider),
    environment,
  );
});

final timelineControllerProvider =
    AsyncNotifierProvider<TimelineController, TimelineState>(
  TimelineController.new,
);

class TimelineController extends AsyncNotifier<TimelineState> {
  @override
  Future<TimelineState> build() async {
    final page = await ref.read(timelineRepositoryProvider).fetchTimelinePage();
    return _toState(page);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final page = await ref.read(timelineRepositoryProvider).fetchTimelinePage();
      return _toState(page);
    });
  }

  Future<void> loadNextPage() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        isLoadingMore: true,
        clearErrorMessage: true,
      ),
    );

    try {
      final nextPage = await ref
          .read(timelineRepositoryProvider)
          .fetchTimelinePage(cursor: current.nextCursor);

      final mergedItems = _mergeUniquePosts(current.items, nextPage.posts);
      state = AsyncData(
        current.copyWith(
          items: mergedItems,
          nextCursor: nextPage.nextCursor,
          clearNextCursor: nextPage.nextCursor == null,
          hasMore: nextPage.hasNextPage,
          isLoadingMore: false,
          clearErrorMessage: true,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isLoadingMore: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  TimelineState _toState(TimelinePage page) {
    return TimelineState(
      items: _mergeUniquePosts(const [], page.posts),
      nextCursor: page.nextCursor,
      isLoadingMore: false,
      hasMore: page.hasNextPage,
      errorMessage: null,
    );
  }

  List<MediaPost> _mergeUniquePosts(
    List<MediaPost> current,
    List<MediaPost> incoming,
  ) {
    final byId = <String, MediaPost>{};
    for (final post in current) {
      byId[post.postId] = post;
    }
    for (final post in incoming) {
      byId.putIfAbsent(post.postId, () => post);
    }

    final merged = byId.values.toList(growable: false);
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }
}
