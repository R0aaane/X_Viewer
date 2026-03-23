import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/saved_media_repository_impl.dart';
import '../../../../domain/models/media_post.dart';
import '../../../../domain/models/post_image.dart';
import '../../../../domain/models/save_image_result.dart';
import '../../../../domain/models/saved_media_record.dart';
import '../../../../domain/repositories/saved_media_repository.dart';
import '../../../../services/file_storage_service.dart';
import '../../../../services/gallery_save_service.dart';
import '../../../../services/image_download_service.dart';
import '../../../../services/media_save_service.dart';

final dioProvider = Provider<Dio>((ref) => Dio());

final fileStorageServiceProvider = Provider<FileStorageService>(
  (ref) => FileStorageService(),
);

final imageDownloadServiceProvider = Provider<ImageDownloadService>(
  (ref) => ImageDownloadService(ref.watch(dioProvider)),
);

final gallerySaveServiceProvider = Provider<GallerySaveService>(
  (ref) => GallerySaveService(),
);

final savedMediaRepositoryProvider = Provider<SavedMediaRepository>(
  (ref) => createSavedMediaRepository(),
);

final mediaSaveServiceProvider = Provider<MediaSaveService>(
  (ref) => MediaSaveService(
    repository: ref.watch(savedMediaRepositoryProvider),
    fileStorageService: ref.watch(fileStorageServiceProvider),
    imageDownloadService: ref.watch(imageDownloadServiceProvider),
    gallerySaveService: ref.watch(gallerySaveServiceProvider),
  ),
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

  Future<SaveImageResult> saveImage({
    required MediaPost post,
    required PostImage image,
  }) async {
    final result = await ref
        .read(mediaSaveServiceProvider)
        .saveImage(post: post, image: image);
    state = AsyncData(await ref.read(savedMediaRepositoryProvider).getAll());
    return result;
  }

  Future<void> deleteRecord(SavedMediaRecord record) async {
    await ref.read(mediaSaveServiceProvider).deleteRecord(record);
    state = AsyncData(await ref.read(savedMediaRepositoryProvider).getAll());
  }

  Future<String> getStorageDirectory() {
    return ref.read(mediaSaveServiceProvider).getStorageDirectoryDescription();
  }

  Future<void> openGalleryApp() {
    return ref.read(mediaSaveServiceProvider).openGalleryApp();
  }
}
