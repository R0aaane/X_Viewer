import '../models/media_post.dart';
import '../models/timeline_page.dart';

abstract interface class TimelineRepository {
  Future<TimelinePage> fetchTimelinePage({String? cursor});
  Future<List<MediaPost>> fetchTimelinePosts({String? cursor});
}
