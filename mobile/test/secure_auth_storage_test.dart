import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sai_approved_mobile/data/secure_auth_storage.dart';

void main() {
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      storageNamespace: 'yemen_sai_auth_v1',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'migrates existing session and PKCE verifier to secure storage',
    () async {
      const session =
          '{"access_token":"test-access","refresh_token":"test-refresh"}';
      const verifier = 'test-pkce-verifier';
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('sai-production-auth', session);
      await preferences.setString(
        'supabase.auth.token-code-verifier',
        verifier,
      );

      final authStorage = SecureAuthStorage();
      await authStorage.initialize();

      expect(await authStorage.accessToken(), session);
      expect(await authStorage.hasAccessToken(), isTrue);
      expect(await secureStorage.read(key: 'sai-production-auth-v1'), session);
      expect(
        await secureStorage.read(
          key: 'sai-production-auth-v1:pkce:supabase.auth.token-code-verifier',
        ),
        verifier,
      );
      expect(preferences.containsKey('sai-production-auth'), isFalse);
      expect(
        preferences.containsKey('supabase.auth.token-code-verifier'),
        isFalse,
      );
    },
  );

  test(
    'secure session wins over legacy data and logout removes both copies',
    () async {
      const currentSession = '{"access_token":"current"}';
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'sai-production-auth',
        '{"access_token":"legacy"}',
      );
      await secureStorage.write(
        key: 'sai-production-auth-v1',
        value: currentSession,
      );

      final authStorage = SecureAuthStorage();
      await authStorage.initialize();
      expect(await authStorage.accessToken(), currentSession);
      expect(preferences.containsKey('sai-production-auth'), isFalse);

      await authStorage.removePersistedSession();
      expect(await authStorage.hasAccessToken(), isFalse);
      expect(preferences.containsKey('sai-production-auth'), isFalse);
    },
  );

  test('PKCE values use secure storage and are removed by their key', () async {
    final authStorage = SecureAuthStorage();
    const key = 'supabase.auth.token-code-verifier';
    await authStorage.setItem(key: key, value: 'test-verifier');

    expect(await authStorage.getItem(key: key), 'test-verifier');
    expect(
      await secureStorage.read(key: 'sai-production-auth-v1:pkce:$key'),
      'test-verifier',
    );
    await authStorage.removeItem(key: key);
    expect(await authStorage.getItem(key: key), isNull);
  });
}
