import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FileStorageService {
  Future<String> saveBytes({
    required Uint8List bytes,
    required String fileName,
    String? accountFolderName,
  }) async {
    final directory = await _ensureImageDirectory(
      accountFolderName: accountFolderName,
    );
    final filePath = p.join(directory.path, fileName);
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

  Future<String> getBaseDirectoryPath({String? accountFolderName}) async {
    final directory = await _ensureImageDirectory(
      accountFolderName: accountFolderName,
    );
    return directory.path;
  }

  Future<Directory> _ensureImageDirectory({String? accountFolderName}) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final pathSegments = <String>[baseDir.path, 'saved_images'];
    final normalizedFolderName = accountFolderName?.trim();
    if (normalizedFolderName != null && normalizedFolderName.isNotEmpty) {
      pathSegments.add(normalizedFolderName);
    }
    final imageDir = Directory(p.joinAll(pathSegments));
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir;
  }
}
