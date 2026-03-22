import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/storage_keys.dart';

class AuthPersistenceService {
  Future<void> saveSession(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.authSession, username);
  }

  Future<String?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageKeys.authSession);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.authSession);
  }
}
