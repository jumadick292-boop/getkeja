import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_configuredBaseUrl.trim().isEmpty) {
      // In non-release modes, default to localhost so Flutter tests and local
      // development work without explicitly passing --dart-define. Release
      // builds still require an explicit HTTPS backend URL.
      if (!kReleaseMode) {
        return 'http://localhost:4000';
      }
      throw StateError(
        'Set API_BASE_URL to the running backend URL when building the app.',
      );
    }
    final value = _configuredBaseUrl.trim();
    final uri = Uri.parse(value);
    if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      throw StateError('API_BASE_URL must be an absolute HTTP(S) backend URL.');
    }
    if (kReleaseMode && uri.scheme != 'https') {
      throw StateError(
        'Set API_BASE_URL to an HTTPS endpoint for release builds.',
      );
    }
    return value.replaceFirst(RegExp(r'/+$'), '');
  }

  static String get authBaseUrl => '$baseUrl/api/v1/auth';

  static void validateReleaseConfig() {
    // Reading baseUrl validates that an explicit backend address was supplied.
    baseUrl;
  }
}
