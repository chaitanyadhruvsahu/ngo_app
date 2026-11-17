import 'package:flutter/foundation.dart';

/// Defaults to the web app's origin; separate development APIs can be
/// supplied with --dart-define=API_BASE_URL=...
class AppConfig {
  AppConfig._();

  static const _configuredUrl = String.fromEnvironment('API_BASE_URL');
  static String get apiBaseUrl => _configuredUrl.isNotEmpty
      ? _configuredUrl
      : kIsWeb ? '${Uri.base.origin}/api/v1' : 'http://localhost:8000/api/v1';
}
