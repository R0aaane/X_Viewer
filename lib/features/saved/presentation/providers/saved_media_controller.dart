import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/saved_media_repository_impl.dart';
import '../../../../domain/models/media_post.dart';
import '../../../../domain/models/post_image.dart';
import '../../../../domain/models/saved_media_record.dart';
import '../../../../domain/repositories/saved_media_repository.dart';
import '../../../../services/file_storage_service.dart';

final dioProvider = Provider<Dio>((ref) => Dio());

final fileStorageServiceProvider = Provider<FileStorageService>(
  (ref) => FileStorageService(ref.watch(dioProvider)),
);

final savedMediaRepositoryProvider = Provider<SavedMediaRepository>(
  (ref) => createSavedMediaRepository(),
);

final savedMediaControllerProvider =
    AsyncNotifierProvider<SavedMediaController, List<SavedMediaRecord>>(
  SavedMediaController.new,
);

class SavedMediaController extends AsyncNotifier<List<SavedMediaRecord>> {
  @override
  Future<List<SavedMediaRecord>> build() {
    return ref.read(savedMediaRepositoryProvider).getAll();
  }

  Future<SavedMediaRecord?> saveImage({
    required MediaPost post,
    required PostImage image,
  }) async {
    final repository = ref.read(savedMediaRepositoryProvider);
    final existing = await repository.findByMediaKey(image.mediaKey);
    if (existing != null) {
      state = AsyncData(await repository.getAll());
      return existing;
    }

    final storage = ref.read(fileStorageServiceProvider);
    final path = await storage.saveImage(
      imageUrl: image.imageUrl,
      fileName:
          '${post.postId}_${image.mediaKey}_${Random().nextInt(9999)}.jpg',
    );

    final record = SavedMediaRecord(
      recordId: '${post.postId}_${image.mediaKey}',
      postId: post.postId,
      mediaKey: image.mediaKey,
      authorName: post.authorName,
      authorUsername: post.authorUsername,
      text: post.text,
      imageUrl: image.imageUrl,
      localSavedPath: path,
      originalPostUrl: post.originalPostUrl,
      createdAt: post.createdAt,
      savedAt: DateTime.now(),
    );

    await repository.save(record);
    state = AsyncData(await repository.getAll());
    return null;
  }

  Future<void> deleteRecord(SavedMediaRecord record) async {
    await ref.read(fileStorageServiceProvider).deleteFile(record.localSavedPath);
    await ref.read(savedMediaRepositoryProvider).delete(record.recordId);
    state = AsyncData(await ref.read(savedMediaRepositoryProvider).getAll());
  }

  Future<String> getStorageDirectory() {
    return ref.read(fileStorageServiceProvider).getBaseDirectoryPath();
  }
}
