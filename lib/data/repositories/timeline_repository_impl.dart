import '../../core/config/app_environment.dart';
import '../../core/errors/x_api_exception.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/models/media_post.dart';
import '../../domain/models/timeline_page.dart';
import '../../domain/repositories/timeline_repository.dart';
import '../../services/auth_persistence_service.dart';
import '../../services/timeline_media_extractor.dart';
import '../adapters/x_timeline_adapter.dart';
import '../datasources/dummy_x_api_client.dart';
import '../datasources/x_api_client.dart';

class TimelineRepositoryImpl implements TimelineRepository {
  TimelineRepositoryImpl(
    this._dummyApiClient,
    this._xApiClient,
    this._adapter,
    this._extractor,
    this._authPersistenceService,
    this._environment,
  );

  final DummyXApiClient _dummyApiClient;
  final XApiClient _xApiClient;
  final XTimelineAdapter _adapter;
  final TimelineMediaExtractor _extractor;
  final AuthPersistenceService _authPersistenceService;
  final AppEnvironment _environment;

  @override
  Future<TimelinePage> fetchTimelinePage({String? cursor}) async {
    if (!_environment.enableRealXApi) {
      final response = await _dummyApiClient.fetchHomeTimeline(cursor: cursor);
      final posts = response.map(_adapter.fromMap).toList(growable: false);
      return TimelinePage(
        posts: _extractor.onlyImagePosts(posts),
        nextCursor: null,
        previousCursor: null,
        resultCount: posts.length,
      );
    }

    final session = await _authPersistenceService.getSession();
    _validateSession(session);

    final response = await _xApiClient.fetchHomeTimeline(
      accessToken: session!.accessToken!,
      userId: session.userId,
      cursor: cursor,
    );
    final page = _adapter.fromApiResponse(response);
    return TimelinePage(
      posts: _extractor.onlyImagePosts(page.posts),
      nextCursor: page.nextCursor,
      previousCursor: page.previousCursor,
      resultCount: page.resultCount,
    );
  }

  @override
  Future<List<MediaPost>> fetchTimelinePosts({String? cursor}) async {
    final page = await fetchTimelinePage(cursor: cursor);
    return page.posts;
  }

  void _validateSession(AuthSession? session) {
    if (session == null) {
      throw XApiException.unauthorized('No auth session found');
    }
    if (!session.hasAccessToken) {
      throw XApiException.unauthorized('Session did not contain an access token');
    }
    if (session.userId.isEmpty || session.userId == 'me') {
      throw XApiException.invalidResponse(
        'Session userId is missing. A real X user ID is required.',
      );
    }
  }
}
