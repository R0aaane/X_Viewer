import 'post_image.dart';

class MediaPost {
  const MediaPost({
    required this.postId,
    required this.authorName,
    required this.authorUsername,
    required this.text,
    required this.images,
    required this.originalPostUrl,
    required this.createdAt,
  });

  final String postId;
  final String authorName;
  final String authorUsername;
  final String text;
  final List<PostImage> images;
  final String originalPostUrl;
  final DateTime createdAt;

  bool get hasImages => images.isNotEmpty;
}
