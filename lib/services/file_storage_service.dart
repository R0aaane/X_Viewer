import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FileStorageService {
  FileStorageService(this._dio);

  final Dio _dio;

  Future<String> saveImage({
    required String imageUrl,
    required String fileName,
  }) async {
    final directory = await _ensureImageDirectory();
    final filePath = p.join(directory.path, fileName);
    final response = await _dio.get<List<int>>(
      imageUrl,
      options: Options(responseType: ResponseType.bytes),
    );

    final bytes = Uint8List.fromList(response.data ?? const []);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String> getBaseDirectoryPath() async {
    final directory = await _ensureImageDirectory();
    return directory.path;
  }

  Future<Directory> _ensureImageDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(baseDir.path, 'saved_images'));
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir;
  }
}
