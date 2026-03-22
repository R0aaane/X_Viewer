import '../../domain/models/media_post.dart';
import '../../domain/models/post_image.dart';

class XTimelineAdapter {
  MediaPost fromMap(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>? ?? const {};
    final media = (json['media'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((item) => item['type'] == 'photo')
        .map(_imageFromMap)
        .toList(growable: false);

    final postId = json['id'] as String;
    final username = author['username'] as String? ?? 'unknown_user';

    return MediaPost(
      postId: postId,
      authorName: author['name'] as String? ?? 'Unknown',
      authorUsername: username,
      text: json['text'] as String? ?? '',
      images: media,
      originalPostUrl: 'https://x.com/$username/status/$postId',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  PostImage _imageFromMap(Map<String, dynamic> json) {
    return PostImage(
      mediaKey: json['media_key'] as String,
      imageUrl: json['url'] as String,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
    );
  }
}
