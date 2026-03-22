import '../models/saved_media_record.dart';

abstract interface class SavedMediaRepository {
  Future<List<SavedMediaRecord>> getAll();
  Future<SavedMediaRecord?> findByMediaKey(String mediaKey);
  Future<void> save(SavedMediaRecord record);
  Future<void> delete(String recordId);
}
