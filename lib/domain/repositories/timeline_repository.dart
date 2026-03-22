import '../models/media_post.dart';

abstract interface class TimelineRepository {
  Future<List<MediaPost>> fetchTimelinePosts({String? cursor});
}
