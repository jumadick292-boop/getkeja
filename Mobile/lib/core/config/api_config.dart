import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    final value = _configuredBaseUrl.isNotEmpty
        ? _configuredBaseUrl
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => 'http://10.0.2.2:4000',
            TargetPlatform.iOS => 'http://127.0.0.1:4000',
            _ => 'http://localhost:4000',
          };
    final uri = Uri.parse(value);
    if (kReleaseMode && uri.scheme != 'https') {
      throw StateError(
        'Set API_BASE_URL to an HTTPS endpoint for release builds.',
      );
    }
    return value.replaceFirst(RegExp(r'/+$'), '');
  }
}
