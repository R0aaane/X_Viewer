import '../../data/mappers/x_timeline_includes_mapper.dart';
import '../../data/models/x_api_timeline_response.dart';
import '../../domain/models/media_post.dart';
import '../../domain/models/post_image.dart';
import '../../domain/models/timeline_page.dart';

class XTimelineAdapter {
  XTimelineAdapter(this._includesMapper);

  final XTimelineIncludesMapper _includesMapper;

  TimelinePage fromApiResponse(XApiTimelineResponse response) {
    final usersById = _includesMapper.usersById(response.includes);
    final mediaByKey = _includesMapper.mediaByKey(response.includes);

    final posts = response.data
        .map(
          (tweet) => _buildApiPost(
            tweet: tweet,
            usersById: usersById,
            mediaByKey: mediaByKey,
          ),
        )
        .whereType<MediaPost>()
        .toList(growable: false);

    return TimelinePage(
      posts: posts,
      newestId: response.newestId,
      nextCursor: response.nextToken,
      resultCount: response.resultCount,
    );
  }

  MediaPost fromMap(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>? ?? const {};
    final media = (json['media'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((item) => item['type'] == 'photo')
        .map(_legacyImageFromMap)
        .toList(growable: false);

    final postId = _asString(json['id']);
    final username = _asString(
      author['username'],
      fallback: 'unknown_user',
    );

    return MediaPost(
      postId: postId,
      authorName: _asString(author['name'], fallback: 'Unknown'),
      authorUsername: username,
      text: _extractText(json),
      images: media,
      originalPostUrl: 'https://x.com/$username/status/$postId',
      createdAt: _parseCreatedAt(json['created_at']),
    );
  }

  MediaPost? _buildApiPost({
    required Map<String, dynamic> tweet,
    required Map<String, Map<String, dynamic>> usersById,
    required Map<String, Map<String, dynamic>> mediaByKey,
  }) {
    final images = _extractApiImages(tweet, mediaByKey);
    if (images.isEmpty) {
      return null;
    }

    final sourceAuthor = usersById[_asString(tweet['author_id'])];
    final authorUsername = _asString(
      sourceAuthor?['username'],
      fallback: 'unknown_user',
    );
    final postId = _asString(tweet['id']);

    return MediaPost(
      postId: postId,
      authorName: _asString(sourceAuthor?['name'], fallback: 'Unknown'),
      authorUsername: authorUsername,
      text: _extractText(tweet),
      images: images,
      originalPostUrl: 'https://x.com/$authorUsername/status/$postId',
      createdAt: _parseCreatedAt(tweet['created_at']),
    );
  }

  List<PostImage> _extractApiImages(
    Map<String, dynamic> tweet,
    Map<String, Map<String, dynamic>> mediaByKey,
  ) {
    final attachments = tweet['attachments'] as Map<String, dynamic>?;
    final mediaKeys = (attachments?['media_keys'] as List<dynamic>? ?? const [])
        .whereType<String>();

    return mediaKeys
        .map((key) => mediaByKey[key])
        .whereType<Map<String, dynamic>>()
        .where((media) => media['type'] == 'photo')
        .map(_apiImageFromMap)
        .whereType<PostImage>()
        .toList(growable: false);
  }

  PostImage? _apiImageFromMap(Map<String, dynamic> json) {
    final mediaKey = _asString(json['media_key']);
    final imageUrl = _asString(
      json['url'] ?? json['preview_image_url'],
    );

    if (mediaKey.isEmpty || imageUrl.isEmpty) {
      return null;
    }

    return PostImage(
      mediaKey: mediaKey,
      imageUrl: imageUrl,
      width: _asInt(json['width']),
      height: _asInt(json['height']),
    );
  }

  PostImage _legacyImageFromMap(Map<String, dynamic> json) {
    return PostImage(
      mediaKey: _asString(json['media_key']),
      imageUrl: _asString(json['url']),
      width: _asInt(json['width']),
      height: _asInt(json['height']),
    );
  }

  String _extractText(Map<String, dynamic> json) {
    // TODO(api-usage): avoid note_tweet fetch until the detail UX truly requires it.
    return _asString(json['text']);
  }

  DateTime _parseCreatedAt(Object? value) {
    final parsed = DateTime.tryParse(_asString(value));
    return parsed ?? DateTime.now();
  }

  String _asString(Object? value, {String fallback = ''}) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return fallback;
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }
}
