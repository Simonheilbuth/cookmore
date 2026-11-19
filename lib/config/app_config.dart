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

  /// URL of the Supabase project used for cloud backup, e.g.
  /// "https://abcd1234.supabase.co". Empty means cloud backup is off.
  ///
  /// Supplied at build time from supabase.json (not committed to Git):
  /// `flutter run --dart-define-from-file=supabase.json`
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase "anon" (publishable) key. It identifies the project and is
  /// meant to be used in apps; access to data is protected by Row Level
  /// Security in the database, not by keeping this key secret.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True when both Supabase values are set and the URL uses HTTPS.
  static bool get isSupabaseConfigured =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;

  /// Maximum time to wait for a network request before giving up.
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Maximum number of ingredients in one "What can I cook?" search.
  /// Each ingredient costs one API call, so the number is limited.
  static const int maxSearchIngredients = 5;

  /// Number of recently viewed recipes kept for offline reading.
  static const int recipeCacheLimit = 30;
}
