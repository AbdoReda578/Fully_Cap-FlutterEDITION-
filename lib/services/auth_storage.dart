import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const String _tokenKey = 'med_reminder_api_token';

  AuthStorage({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);

    // Cleanup legacy storage (migration from older builds).
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<String?> readToken() async {
    final secureToken = await _secureStorage.read(key: _tokenKey);
    if (secureToken != null && secureToken.isNotEmpty) {
      return secureToken;
    }

    // Migration path: older builds stored token in SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_tokenKey);
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await _secureStorage.write(key: _tokenKey, value: legacyToken);
      await prefs.remove(_tokenKey);
      return legacyToken;
    }

    return null;
  }

  Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);

    // Cleanup legacy storage (migration from older builds).
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
