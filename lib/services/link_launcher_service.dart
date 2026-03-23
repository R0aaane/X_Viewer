import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/errors/app_exception.dart';

class LinkLauncherService {
  Future<void> openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw const AppException('Invalid URL format');
    }

    debugPrint('[xviewer][flutter] Opening external URL: $url');

    final canLaunch = await canLaunchUrl(uri);
    if (!canLaunch) {
      throw const AppException('Could not open original post');
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
