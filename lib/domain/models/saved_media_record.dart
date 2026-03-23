import 'save_location_type.dart';

class SavedMediaRecord {
  const SavedMediaRecord({
    required this.recordId,
    required this.postId,
    required this.mediaKey,
    required this.authorName,
    required this.authorUsername,
    required this.text,
    required this.imageUrl,
    required this.sourceImageUrl,
    required this.localSavedPath,
    required this.previewFilePath,
    required this.originalPostUrl,
    required this.createdAt,
    required this.savedAt,
    required this.saveLocationType,
    this.galleryContentUri,
    this.galleryDisplayName,
  });

  final String recordId;
  final String postId;
  final String mediaKey;
  final String authorName;
  final String authorUsername;
  final String text;
  final String imageUrl;
  final String sourceImageUrl;
  final String localSavedPath;
  final String previewFilePath;
  final String originalPostUrl;
  final DateTime createdAt;
  final DateTime savedAt;
  final SaveLocationType saveLocationType;
  final String? galleryContentUri;
  final String? galleryDisplayName;

  Map<String, dynamic> toJson() {
    return {
      'recordId': recordId,
      'postId': postId,
      'mediaKey': mediaKey,
      'authorName': authorName,
      'authorUsername': authorUsername,
      'text': text,
      'imageUrl': imageUrl,
      'sourceImageUrl': sourceImageUrl,
      'localSavedPath': localSavedPath,
      'previewFilePath': previewFilePath,
      'originalPostUrl': originalPostUrl,
      'createdAt': createdAt.toIso8601String(),
      'savedAt': savedAt.toIso8601String(),
      'saveLocationType': saveLocationType.name,
      'galleryContentUri': galleryContentUri,
      'galleryDisplayName': galleryDisplayName,
    };
  }

  factory SavedMediaRecord.fromJson(Map<String, dynamic> json) {
    return SavedMediaRecord(
      recordId: json['recordId'] as String,
      postId: json['postId'] as String,
      mediaKey: json['mediaKey'] as String,
      authorName: json['authorName'] as String,
      authorUsername: json['authorUsername'] as String,
      text: json['text'] as String? ?? '',
      imageUrl: json['imageUrl'] as String,
      sourceImageUrl:
          json['sourceImageUrl'] as String? ?? json['imageUrl'] as String,
      localSavedPath: json['localSavedPath'] as String,
      previewFilePath:
          json['previewFilePath'] as String? ??
          json['localSavedPath'] as String,
      originalPostUrl: json['originalPostUrl'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      savedAt: DateTime.parse(json['savedAt'] as String),
      saveLocationType: SaveLocationType.values.byName(
        json['saveLocationType'] as String? ?? SaveLocationType.appPrivate.name,
      ),
      galleryContentUri: json['galleryContentUri'] as String?,
      galleryDisplayName: json['galleryDisplayName'] as String?,
    );
  }
}
