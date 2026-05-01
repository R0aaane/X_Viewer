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
import '../models/saved_media_filter_state.dart';

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

final savedMediaFilterProvider =
    NotifierProvider<SavedMediaFilterController, SavedMediaFilterState>(
      SavedMediaFilterController.new,
    );

final savedMediaFilteredRecordsProvider = Provider<List<SavedMediaRecord>>((ref) {
  final records =
      ref.watch(savedMediaControllerProvider).valueOrNull ??
      const <SavedMediaRecord>[];
  final filter = ref.watch(savedMediaFilterProvider);

  final filtered = records.where((record) {
    final authorMatch =
        filter.authorUsername == null ||
        filter.authorUsername == record.authorUsername;
    final favoriteMatch = !filter.onlyFavorites || record.favorite;
    final normalizedTagQuery = filter.tagQuery.trim().toLowerCase();
    final tagMatch =
        normalizedTagQuery.isEmpty ||
        record.tags.any((tag) => tag.contains(normalizedTagQuery));
    return authorMatch && favoriteMatch && tagMatch;
  }).toList(growable: false);

  switch (filter.sort) {
    case SavedMediaSort.savedAtDesc:
      filtered.sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }
  return filtered;
});

final savedMediaAuthorsProvider = Provider<List<String>>((ref) {
  final records =
      ref.watch(savedMediaControllerProvider).valueOrNull ??
      const <SavedMediaRecord>[];
  final authors = records.map((record) => record.authorUsername).toSet().toList()
    ..sort();
  return authors;
});

final savedMediaTagsProvider = Provider<List<String>>((ref) {
  final records =
      ref.watch(savedMediaControllerProvider).valueOrNull ??
      const <SavedMediaRecord>[];
  final tags = records.expand((record) => record.tags).toSet().toList()..sort();
  return tags;
});

final savedMediaRecordProvider =
    Provider.family<SavedMediaRecord?, String>((ref, recordId) {
      final records =
          ref.watch(savedMediaControllerProvider).valueOrNull ??
          const <SavedMediaRecord>[];
      for (final record in records) {
        if (record.recordId == recordId) {
          return record;
        }
      }
      return null;
    });

class SavedMediaController extends AsyncNotifier<List<SavedMediaRecord>> {
  @override
  Future<List<SavedMediaRecord>> build() async {
    final mediaSaveService = ref.read(mediaSaveServiceProvider);
    await mediaSaveService.importExistingSavedImageFiles();
    await mediaSaveService.migrateSavedMediaToAuthorFolders();
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

  Future<void> toggleFavorite(String recordId) async {
    final repository = ref.read(savedMediaRepositoryProvider);
    final record = await repository.findByRecordId(recordId);
    if (record == null) {
      return;
    }

    await repository.save(record.copyWith(favorite: !record.favorite));
    state = AsyncData(await repository.getAll());
  }

  Future<void> addTag({
    required String recordId,
    required String rawTag,
  }) async {
    final repository = ref.read(savedMediaRepositoryProvider);
    final record = await repository.findByRecordId(recordId);
    if (record == null) {
      return;
    }

    final normalizedTag = _normalizeTag(rawTag);
    if (normalizedTag == null) {
      return;
    }

    final updatedTags = {...record.tags, normalizedTag}.toList()..sort();
    await repository.save(record.copyWith(tags: updatedTags));
    state = AsyncData(await repository.getAll());
  }

  Future<void> removeTag({
    required String recordId,
    required String tag,
  }) async {
    final repository = ref.read(savedMediaRepositoryProvider);
    final record = await repository.findByRecordId(recordId);
    if (record == null) {
      return;
    }

    final updatedTags = record.tags.where((entry) => entry != tag).toList();
    await repository.save(record.copyWith(tags: updatedTags));
    state = AsyncData(await repository.getAll());
  }

  Future<String> getStorageDirectory() {
    return ref.read(mediaSaveServiceProvider).getStorageDirectoryDescription();
  }

  Future<void> openGalleryApp() {
    return ref.read(mediaSaveServiceProvider).openGalleryApp();
  }

  String? _normalizeTag(String rawTag) {
    final normalized = rawTag.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

class SavedMediaFilterController extends Notifier<SavedMediaFilterState> {
  @override
  SavedMediaFilterState build() {
    return const SavedMediaFilterState();
  }

  void setAuthor(String? authorUsername) {
    state = authorUsername == null || authorUsername.isEmpty
        ? state.copyWith(clearAuthor: true)
        : state.copyWith(authorUsername: authorUsername);
  }

  void toggleFavoritesOnly() {
    state = state.copyWith(onlyFavorites: !state.onlyFavorites);
  }

  void setTagQuery(String value) {
    state = state.copyWith(tagQuery: value.trim().toLowerCase());
  }

  void clear() {
    state = state.clear();
  }
}
