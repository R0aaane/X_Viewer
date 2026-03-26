import '../models/saved_media_record.dart';

abstract interface class SavedMediaRepository {
  Future<List<SavedMediaRecord>> getAll();
  Future<SavedMediaRecord?> findByRecordId(String recordId);
  Future<SavedMediaRecord?> findByMediaKey({
    required String mediaKey,
    String? ownerUserId,
  });
  Future<void> save(SavedMediaRecord record);
  Future<void> delete(String recordId);
}
