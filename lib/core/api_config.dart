import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  const ApiConfig._();

  static const String apiBaseUrlOverrideKey = 'api_base_url_override_v1';

  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String? _workingBaseUrl;

  // Override with:
  // flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3006
  static List<String> candidateBaseUrls() {
    final urls = <String>[];

    void addUrl(String value) {
      final normalized = value.trim().replaceAll(RegExp(r'/$'), '');
      if (normalized.isNotEmpty && !urls.contains(normalized)) {
        // Release builds must only ever talk to HTTPS backends.
        if (kReleaseMode) {
          final uri = Uri.tryParse(normalized);
          if (uri == null || uri.scheme.toLowerCase() != 'https') {
            return;
          }
        }
        urls.add(normalized);
      }
    }

    if (_workingBaseUrl != null) {
      addUrl(_workingBaseUrl!);
    }

    if (_envBaseUrl.isNotEmpty) {
      addUrl(_envBaseUrl);
    }

    if (!kReleaseMode) {
      // Common local targets (debug/dev only).
      addUrl('http://10.0.2.2:3006'); // Android emulator -> host machine
      addUrl('http://127.0.0.1:3006');
      addUrl('http://localhost:3006');
    }

    // On web, current origin can be used if API is served behind same host.
    if (kIsWeb) {
      addUrl(Uri.base.origin);
    }

    return urls;
  }

  static String? releaseConfigurationError() {
    if (!kReleaseMode) {
      return null;
    }

    if (_envBaseUrl.isEmpty) {
      return 'Missing API_BASE_URL. Release builds require '
          '--dart-define=API_BASE_URL=https://your-backend-host';
    }

    final uri = Uri.tryParse(_envBaseUrl.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'https') {
      return 'Invalid API_BASE_URL. Release builds require HTTPS.';
    }

    return null;
  }

  static Future<String?> loadSavedOverride() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(apiBaseUrlOverrideKey) ?? '').trim();
    return raw.isEmpty ? null : raw.replaceAll(RegExp(r'/$'), '');
  }

  static Future<void> saveOverride(String? baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = (baseUrl ?? '').trim().replaceAll(RegExp(r'/$'), '');
    if (normalized.isEmpty) {
      await prefs.remove(apiBaseUrlOverrideKey);
      return;
    }
    await prefs.setString(apiBaseUrlOverrideKey, normalized);
    rememberWorkingBaseUrl(normalized);
  }

  static void rememberWorkingBaseUrl(String baseUrl) {
    _workingBaseUrl = baseUrl;
  }
}
