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

    test('isConfigured requires both a url and an anon key', () {
      expect(
        AppConfig.isConfigured,
        AppConfig.supabaseUrl.trim().isNotEmpty &&
            AppConfig.supabaseAnonKey.trim().isNotEmpty,
      );
    });

    test('password reset redirect is a stable deep link', () {
      expect(AppConfig.passwordResetRedirect, 'saicollege://auth/callback');
    });
  });
}