/// Environment-specific configuration. Overridden at build time with
/// `--dart-define=API_BASE_URL=https://api.example.com/api/v1`, matching
/// the backend's mandate that config is never hardcoded per environment.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );
}
