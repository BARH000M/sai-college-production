/// Central application configuration.
///
/// The designated backend for Yemen SAI Educational College is baked in as the
/// default URL, so a build only needs to supply the public publishable key. Both
/// values can still be overridden at build time:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://aeryusbrulqdxjdynwfh.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>
/// ```
///
/// Only the public publishable key may ever be supplied here. The service_role
/// key must never be compiled into the mobile application.
abstract final class AppConfig {
  /// Designated Supabase project for production.
  static const String designatedSupabaseUrl =
      'https://aeryusbrulqdxjdynwfh.supabase.co';

  /// Effective API URL: the build-time override when present, otherwise the
  /// designated project.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: designatedSupabaseUrl,
  );

  /// Public publishable key, supplied at build time only.
  ///
  /// Supabase renamed the browser-safe "anon" key to "publishable" key; this
  /// reads the current name first.
  static const String supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Legacy `anon` key name, read only as a fallback so existing build
  /// scripts and CI definitions keep working.
  static const String legacySupabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Effective public key: the publishable key when supplied, otherwise the
  /// legacy anon key.
  static String get supabaseKey {
    final publishable = supabasePublishableKey.trim();
    return publishable.isNotEmpty ? publishable : legacySupabaseAnonKey.trim();
  }

  /// Deep link used for password recovery e-mails.
  static const String passwordResetRedirect = 'saicollege://auth/callback';

  /// True when a URL and a public key are both available.
  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseKey.isNotEmpty;

  /// True when the build is pointing at the designated production project.
  static bool get isDesignatedBackend =>
      supabaseUrl.trim() == designatedSupabaseUrl;
}