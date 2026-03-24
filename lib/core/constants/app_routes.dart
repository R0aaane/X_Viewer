abstract final class AppRoutes {
  static const login = '/';
  static const timeline = '/timeline';
  static const saved = '/saved';
  static const savedDetail = '/saved/:recordId';

  static String savedDetailPath(String recordId) {
    return '/saved/${Uri.encodeComponent(recordId)}';
  }
}
