import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/errors/app_exception.dart';
import '../domain/models/media_post.dart';
import '../domain/models/post_image.dart';
import '../domain/models/save_failure_reason.dart';
import '../domain/models/save_image_result.dart';
import '../domain/models/save_location_type.dart';
import '../domain/models/saved_media_record.dart';
import '../domain/repositories/saved_media_repository.dart';
import 'downloaded_image.dart';
import 'file_storage_service.dart';
import 'gallery_save_service.dart';
import 'image_download_service.dart';

class MediaSaveService {
  MediaSaveService({
    required SavedMediaRepository repository,
    required FileStorageService fileStorageService,
    required ImageDownloadService imageDownloadService,
    required GallerySaveService gallerySaveService,
  }) : _repository = repository,
       _fileStorageService = fileStorageService,
       _imageDownloadService = imageDownloadService,
       _gallerySaveService = gallerySaveService;

  final SavedMediaRepository _repository;
  final FileStorageService _fileStorageService;
  final ImageDownloadService _imageDownloadService;
  final GallerySaveService _gallerySaveService;

  Future<SaveImageResult> saveImage({
    required MediaPost post,
    required PostImage image,
  }) async {
    final existing = await _repository.findByMediaKey(image.mediaKey);
    if (existing != null) {
      return SaveImageResult(
        record: existing,
        locationType: existing.saveLocationType,
        wasDuplicate: true,
        usedFallback: false,
        savedPath: existing.localSavedPath,
        galleryContentUri: existing.galleryContentUri,
        failureReason: SaveFailureReason.duplicate,
        message: 'This image is already saved',
      );
    }

    final fileName = _buildFileName(post: post, image: image);
    final DownloadedImage downloadedImage;
    try {
      downloadedImage = await _imageDownloadService.downloadImage(
        imageUrl: image.imageUrl,
        fileName: fileName,
      );
    } on AppException catch (error) {
      throw SaveImageException(
        SaveFailureReason.downloadFailed,
        error.message,
        details: error.details,
      );
    }

    GallerySaveResult? gallerySave;
    SaveFailureReason? fallbackReason;

    if (_shouldTryGallerySave()) {
      try {
        await _ensureGalleryPermissionIfNeeded();
        gallerySave = await _gallerySaveService.saveImage(
          bytes: downloadedImage.bytes,
          fileName: downloadedImage.fileName,
          mimeType: downloadedImage.mimeType,
        );
      } on SaveImageException catch (error) {
        fallbackReason = error.reason;
      } on AppException catch (_) {
        fallbackReason = SaveFailureReason.galleryUnavailable;
      } catch (_) {
        fallbackReason = SaveFailureReason.writeFailed;
      }
    } else {
      fallbackReason = SaveFailureReason.unsupportedPlatform;
    }

    final previewPath = await _savePreviewCopyOrRollback(
      image: downloadedImage,
      galleryContentUri: gallerySave?.contentUri,
    );
    final now = DateTime.now();

    final record = SavedMediaRecord(
      recordId: '${post.postId}_${image.mediaKey}',
      postId: post.postId,
      mediaKey: image.mediaKey,
      authorName: post.authorName,
      authorUsername: post.authorUsername,
      text: post.text,
      imageUrl: image.imageUrl,
      sourceImageUrl: image.imageUrl,
      localSavedPath: gallerySave?.savedPath ?? previewPath,
      previewFilePath: previewPath,
      originalPostUrl: post.originalPostUrl,
      createdAt: post.createdAt,
      savedAt: now,
      saveLocationType: gallerySave != null
          ? SaveLocationType.gallery
          : SaveLocationType.appPrivate,
      galleryContentUri: gallerySave?.contentUri,
      galleryDisplayName: gallerySave?.displayName ?? downloadedImage.fileName,
    );

    await _repository.save(record);

    return SaveImageResult(
      record: record,
      locationType: record.saveLocationType,
      wasDuplicate: false,
      usedFallback: gallerySave == null,
      savedPath: record.localSavedPath,
      galleryContentUri: record.galleryContentUri,
      failureReason: gallerySave == null ? fallbackReason : null,
      message: gallerySave == null
          ? 'Saved to app storage because gallery save was unavailable'
          : 'Saved to gallery',
    );
  }

  Future<void> deleteRecord(SavedMediaRecord record) async {
    await _fileStorageService.deleteFile(record.previewFilePath);
    if (record.localSavedPath != record.previewFilePath) {
      await _fileStorageService.deleteFile(record.localSavedPath);
    }
    if (record.saveLocationType == SaveLocationType.gallery &&
        (record.galleryContentUri?.isNotEmpty ?? false)) {
      try {
        await _gallerySaveService.deleteImage(record.galleryContentUri!);
      } catch (_) {
        debugPrint(
          '[xviewer][save] Failed to delete gallery asset: ${record.galleryContentUri}',
        );
      }
    }
    await _repository.delete(record.recordId);
  }

  Future<String> getStorageDirectoryDescription() async {
    final privateDir = await _fileStorageService.getBaseDirectoryPath();
    if (!_shouldTryGallerySave()) {
      return privateDir;
    }
    return 'Gallery: Pictures/Xviewer, Preview cache: $privateDir';
  }

  Future<void> openGalleryApp() {
    return _gallerySaveService.openGalleryApp();
  }

  bool _shouldTryGallerySave() {
    return Platform.isAndroid;
  }

  Future<void> _ensureGalleryPermissionIfNeeded() async {
    if (!Platform.isAndroid) {
      throw const SaveImageException(
        SaveFailureReason.unsupportedPlatform,
        'Gallery save is not supported on this platform',
      );
    }

    final sdkInt = await _gallerySaveService.getAndroidSdkInt();
    if (sdkInt == null || sdkInt >= 29) {
      return;
    }

    final status = await Permission.storage.request();
    if (!status.isGranted) {
      throw const SaveImageException(
        SaveFailureReason.permissionDenied,
        'Storage permission was denied',
      );
    }
  }

  Future<String> _savePreviewCopy(DownloadedImage image) {
    return _fileStorageService.saveBytes(
      bytes: image.bytes,
      fileName: image.fileName,
    );
  }

  Future<String> _savePreviewCopyOrRollback({
    required DownloadedImage image,
    String? galleryContentUri,
  }) async {
    try {
      return await _savePreviewCopy(image);
    } catch (error) {
      if (galleryContentUri != null && galleryContentUri.isNotEmpty) {
        try {
          await _gallerySaveService.deleteImage(galleryContentUri);
        } catch (_) {
          debugPrint(
            '[xviewer][save] Failed to rollback gallery asset: $galleryContentUri',
          );
        }
      }
      throw SaveImageException(
        SaveFailureReason.writeFailed,
        'Failed to persist saved image locally',
        details: error,
      );
    }
  }

  String _buildFileName({required MediaPost post, required PostImage image}) {
    final baseName = '${post.postId}_${image.mediaKey}';
    final sanitized = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return '$sanitized.jpg';
  }
}

class SaveImageException extends AppException {
  const SaveImageException(this.reason, super.message, {super.details});

  final SaveFailureReason reason;
}
