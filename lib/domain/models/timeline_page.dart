import 'media_post.dart';

class TimelinePage {
  const TimelinePage({
    required this.posts,
    required this.nextCursor,
    required this.previousCursor,
    required this.resultCount,
  });

  final List<MediaPost> posts;
  final String? nextCursor;
  final String? previousCursor;
  final int resultCount;

  bool get hasNextPage => (nextCursor ?? '').isNotEmpty;

  static const empty = TimelinePage(
    posts: [],
    nextCursor: null,
    previousCursor: null,
    resultCount: 0,
  );
}
