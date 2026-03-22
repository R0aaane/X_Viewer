import 'package:hive_flutter/hive_flutter.dart';

import 'constants/storage_keys.dart';

Future<void> bootstrap() async {
  await Hive.initFlutter();
  await Hive.openBox<Map<dynamic, dynamic>>(StorageKeys.savedMediaBox);
}
