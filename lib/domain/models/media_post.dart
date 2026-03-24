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

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'authorName': authorName,
      'authorUsername': authorUsername,
      'text': text,
      'images': images.map((image) => image.toJson()).toList(growable: false),
      'originalPostUrl': originalPostUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MediaPost.fromJson(Map<String, dynamic> json) {
    return MediaPost(
      postId: json['postId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? 'Unknown',
      authorUsername: json['authorUsername'] as String? ?? 'unknown_user',
      text: json['text'] as String? ?? '',
      images: (json['images'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(PostImage.fromJson)
          .toList(growable: false),
      originalPostUrl: json['originalPostUrl'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
