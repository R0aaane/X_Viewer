import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'link_launcher_service.dart';

final linkLauncherServiceProvider = Provider<LinkLauncherService>(
  (ref) => LinkLauncherService(),
);
