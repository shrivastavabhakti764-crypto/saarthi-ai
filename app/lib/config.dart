class AppConfig {
  /// Render pe deployed backend. Laptop pe test karna ho toh:
  /// flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://saarthi-ai-t46i.onrender.com',
  );
}