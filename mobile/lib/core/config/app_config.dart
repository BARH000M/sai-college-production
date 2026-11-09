/// Central application configuration.
///
/// The designated backend for Yemen SAI Educational College is baked in as the
/// default URL, so a build only needs to supply the public anon key. Both values
/// can still be overridden at build time:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://aeryusbrulqdxjdynwfh.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=<anon key>
/// ```
///
/// Only the public anon key may ever be supplied here. The service_role key must
/// never be compiled into the mobile application.
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

  /// Public anon key, supplied at build time only.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Deep link used for password recovery e-mails.
  static const String passwordResetRedirect = 'saicollege://auth/callback';

  /// True when a URL and an anon key are both available.
  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  /// True when the build is pointing at the designated production project.
  static bool get isDesignatedBackend =>
      supabaseUrl.trim() == designatedSupabaseUrl;
}