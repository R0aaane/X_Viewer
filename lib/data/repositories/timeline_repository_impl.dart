import '../../domain/models/media_post.dart';
import '../../domain/repositories/timeline_repository.dart';
import '../../services/timeline_media_extractor.dart';
import '../adapters/x_timeline_adapter.dart';
import '../datasources/dummy_x_api_client.dart';

class TimelineRepositoryImpl implements TimelineRepository {
  TimelineRepositoryImpl(
    this._apiClient,
    this._adapter,
    this._extractor,
  );

  final DummyXApiClient _apiClient;
  final XTimelineAdapter _adapter;
  final TimelineMediaExtractor _extractor;

  @override
  Future<List<MediaPost>> fetchTimelinePosts({String? cursor}) async {
    final response = await _apiClient.fetchHomeTimeline(cursor: cursor);
    final posts = response.map(_adapter.fromMap).toList(growable: false);
    return _extractor.onlyImagePosts(posts);
  }
}
