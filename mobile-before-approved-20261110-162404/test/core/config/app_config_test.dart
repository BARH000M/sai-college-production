import 'package:flutter_test/flutter_test.dart';
import 'package:sai_college_mobile/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('designated backend points at the production project', () {
      expect(
        AppConfig.designatedSupabaseUrl,
        'https://aeryusbrulqdxjdynwfh.supabase.co',
      );
    });

    test('falls back to the designated project when no override is supplied', () {
      expect(AppConfig.supabaseUrl, AppConfig.designatedSupabaseUrl);
    });

    test('isDesignatedBackend reflects the effective url', () {
      expect(
        AppConfig.isDesignatedBackend,
        AppConfig.supabaseUrl.trim() == AppConfig.designatedSupabaseUrl,
      );
    });

    test('isConfigured requires both a url and a public key', () {
      expect(
        AppConfig.isConfigured,
        AppConfig.supabaseUrl.trim().isNotEmpty &&
            AppConfig.supabaseKey.isNotEmpty,
      );
    });

    test('the publishable key takes precedence over the legacy anon key', () {
      expect(
        AppConfig.supabaseKey,
        AppConfig.supabasePublishableKey.trim().isNotEmpty
            ? AppConfig.supabasePublishableKey.trim()
            : AppConfig.legacySupabaseAnonKey.trim(),
      );
    });

    test('password reset redirect is a stable deep link', () {
      expect(AppConfig.passwordResetRedirect, 'saicollege://auth/callback');
    });
  });
}