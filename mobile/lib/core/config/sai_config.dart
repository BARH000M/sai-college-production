class SaiConfig {
  const SaiConfig._();
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const bool isConfigured = bool.fromEnvironment('SAI_CONFIGURED', defaultValue: false);
  static bool get isExpectedBackend =>
      supabaseUrl == 'https://aeryusbrulqdxjdynwfh.supabase.co';
}
