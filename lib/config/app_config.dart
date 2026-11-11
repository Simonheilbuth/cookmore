/// Central configuration for CookMore.
///
/// Values can be overridden at build time with `--dart-define`, so nothing
/// environment-specific or secret has to be hardcoded in the source code.
///
/// Example:
/// ```
/// flutter run --dart-define=MEALDB_API_KEY=your_premium_key
/// ```
class AppConfig {
  AppConfig._();

  /// Base URL of TheMealDB. Must use HTTPS.
  static const String mealDbBaseUrl = String.fromEnvironment(
    'MEALDB_BASE_URL',
    defaultValue: 'https://www.themealdb.com/api/json/v1',
  );

  /// API key for TheMealDB.
  ///
  /// "1" is TheMealDB's public test key for development and education.
  /// It is not a secret. A private premium key must be supplied with
  /// `--dart-define` and never committed to Git.
  static const String mealDbApiKey = String.fromEnvironment(
    'MEALDB_API_KEY',
    defaultValue: '1',
  );

  /// Maximum time to wait for a network request before giving up.
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Maximum number of ingredients in one "What can I cook?" search.
  /// Each ingredient costs one API call, so the number is limited.
  static const int maxSearchIngredients = 5;

  /// Number of recently viewed recipes kept for offline reading.
  static const int recipeCacheLimit = 30;
}
