import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/x_api_constants.dart';
import '../../../../core/errors/error_message_formatter.dart';
import '../../../../data/adapters/x_timeline_adapter.dart';
import '../../../../data/datasources/x_api_client.dart';
import '../../../../data/mappers/x_timeline_includes_mapper.dart';
import '../../../../data/repositories/timeline_repository_impl.dart';
import '../../../../domain/models/auth_session.dart';
import '../../../../domain/models/media_post.dart';
import '../../../../domain/models/timeline_page.dart';
import '../../../../domain/repositories/timeline_repository.dart';
import '../../../../services/timeline_cache_service.dart';
import '../../../../services/timeline_media_extractor.dart';
import '../../../../services/x_timeline_request_builder.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../models/timeline_state.dart';

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

final timelineCacheServiceProvider = Provider<TimelineCacheService>(
  (ref) => const TimelineCacheService(),
);

final timelineRepositoryProvider = Provider<TimelineRepository>((ref) {
  return TimelineRepositoryImpl(
    ref.watch(xApiClientProvider),
    ref.watch(xTimelineAdapterProvider),
    ref.watch(timelineMediaExtractorProvider),
    ref.watch(authPersistenceServiceProvider),
  );
});

final timelineControllerProvider =
    AsyncNotifierProvider<TimelineController, TimelineState>(
      TimelineController.new,
    );

class TimelineController extends AsyncNotifier<TimelineState> {
  @override
  Future<TimelineState> build() async {
    final session = await _getSession();
    if (session == null || session.userId.isEmpty) {
      return TimelineState.empty;
    }

    final cached = await ref
        .read(timelineCacheServiceProvider)
        .read(session.userId);
    if (cached != null && cached.items.isNotEmpty) {
      final hydrated = cached.copyWith(
        isRefreshing: false,
        isLoadingMore: false,
        clearErrorMessage: true,
      );

      if (ref
          .read(timelineRepositoryProvider)
          .shouldSync(lastSyncedAt: hydrated.lastSyncedAt)) {
        Future.microtask(syncIfStale);
      } else {
        debugPrint(
          '[xviewer][flutter] Timeline sync skipped: reason=skipped_cache_fresh lastSyncedAt=${hydrated.lastSyncedAt}',
        );
      }
      return hydrated;
    }

    final initialPage = await ref.read(timelineRepositoryProvider).fetchInitial();
    final initialState = _toState(initialPage);
    await _persistState(initialState);
    return initialState;
  }

  Future<void> syncIfStale() async {
    final current = state.valueOrNull;
    final repository = ref.read(timelineRepositoryProvider);
    if (current == null || current.isRefreshing) {
      return;
    }
    if (!repository.shouldSync(lastSyncedAt: current.lastSyncedAt)) {
      debugPrint(
        '[xviewer][flutter] Timeline sync skipped: reason=skipped_cache_fresh lastSyncedAt=${current.lastSyncedAt}',
      );
      return;
    }

    await _refreshInternal(manual: false);
  }

  Future<void> reload() async {
    await _refreshInternal(manual: true);
  }

  Future<void> loadNextPage() async {
    final current = state.valueOrNull;
    final nextToken = current?.nextToken;
    if (current == null ||
        current.isLoadingMore ||
        nextToken == null ||
        nextToken.isEmpty ||
        !current.hasMore) {
      return;
    }
    if (current.lastUsedPaginationToken == nextToken) {
      debugPrint(
        '[xviewer][flutter] Timeline loadMore skipped: duplicate pagination token token=$nextToken',
      );
      return;
    }

    state = AsyncData(
      current.copyWith(
        isLoadingMore: true,
        lastUsedPaginationToken: nextToken,
        clearErrorMessage: true,
      ),
    );

    try {
      final nextPage = await ref
          .read(timelineRepositoryProvider)
          .fetchNext(paginationToken: nextToken);
      final mergedItems = ref
          .read(timelineRepositoryProvider)
          .mergeAndDedupePosts(current.items, nextPage.posts);
      final nextState = current.copyWith(
        items: mergedItems,
        lastNewestId: current.lastNewestId ?? nextPage.newestId,
        nextToken: nextPage.nextCursor,
        clearNextToken: (nextPage.nextCursor ?? '').isEmpty,
        hasMore: nextPage.hasNextPage,
        isLoadingMore: false,
        lastSyncedAt: DateTime.now(),
        clearErrorMessage: true,
      );
      state = AsyncData(nextState);
      await _persistState(nextState);
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isLoadingMore: false,
          errorMessage: formatErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _refreshInternal({required bool manual}) async {
    final current = state.valueOrNull ?? TimelineState.empty;
    if (current.isRefreshing) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        isRefreshing: true,
        clearErrorMessage: true,
      ),
    );

    try {
      final TimelinePage page;
      if (current.items.isEmpty) {
        page = await ref.read(timelineRepositoryProvider).fetchInitial();
      } else {
        page = await ref
            .read(timelineRepositoryProvider)
            .fetchNewer(
              sinceId: current.lastNewestId,
              requestReason: manual ? 'manual_refresh' : 'stale_sync',
            );
      }

      final mergedItems = current.items.isEmpty
          ? page.posts
          : ref
                .read(timelineRepositoryProvider)
                .mergeAndDedupePosts(page.posts, current.items);
      final nextState = current.copyWith(
        items: mergedItems,
        lastNewestId: page.newestId ?? current.lastNewestId,
        nextToken: current.nextToken ?? page.nextCursor,
        hasMore: (current.nextToken ?? page.nextCursor ?? '').isNotEmpty,
        isRefreshing: false,
        lastSyncedAt: DateTime.now(),
        clearErrorMessage: true,
      );
      state = AsyncData(nextState);
      await _persistState(nextState);
      debugPrint(
        '[xviewer][flutter] Timeline sync completed: manual=$manual newItems=${page.posts.length} totalItems=${nextState.items.length}',
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isRefreshing: false,
          errorMessage: formatErrorMessage(error),
        ),
      );
    }
  }

  TimelineState _toState(TimelinePage page) {
    return TimelineState(
      items: page.posts,
      lastNewestId: page.newestId,
      nextToken: page.nextCursor,
      hasMore: page.hasNextPage,
      isRefreshing: false,
      isLoadingMore: false,
      lastSyncedAt: DateTime.now(),
      lastUsedPaginationToken: null,
      errorMessage: null,
    );
  }

  Future<AuthSession?> _getSession() {
    return ref.read(authPersistenceServiceProvider).getSession();
  }

  Future<void> _persistState(TimelineState state) async {
    final session = await _getSession();
    if (session == null || session.userId.isEmpty) {
      return;
    }
    await ref
        .read(timelineCacheServiceProvider)
        .write(userId: session.userId, state: state);
  }
}
