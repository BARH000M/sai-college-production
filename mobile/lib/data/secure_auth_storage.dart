import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecureAuthStorage extends LocalStorage implements GotrueAsyncStorage {
  SecureAuthStorage({
    FlutterSecureStorage? secureStorage,
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _secureStorage = secureStorage ?? _defaultSecureStorage,
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const _sessionKey = 'sai-production-auth-v1';
  static const _legacySessionKey = 'sai-production-auth';
  static const _legacyPkceKey = 'supabase.auth.token-code-verifier';
  static const _pkcePrefix = 'sai-production-auth-v1:pkce:';
  static const _defaultSecureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      storageNamespace: 'yemen_sai_auth_v1',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );

  final FlutterSecureStorage _secureStorage;
  final Future<SharedPreferences> Function() _preferencesLoader;
  Future<void>? _initialization;

  @override
  Future<void> initialize() => _initialization ??= _migrateLegacySession();

  Future<void> _migrateLegacySession() async {
    final preferences = await _preferencesLoader();
    try {
      final hasSecureSession = await _secureStorage.containsKey(
        key: _sessionKey,
      );
      final legacySession = preferences.getString(_legacySessionKey);
      final legacyPkce = preferences.getString(_legacyPkceKey);

      if (!hasSecureSession && legacySession != null) {
        await _secureStorage.write(key: _sessionKey, value: legacySession);
      }
      if (legacyPkce != null) {
        await _secureStorage.write(
          key: _pkceKey(_legacyPkceKey),
          value: legacyPkce,
        );
      }
    } catch (error, stackTrace) {
      await _removeLegacySession(preferences);
      Error.throwWithStackTrace(error, stackTrace);
    }

    await _removeLegacySession(preferences);
  }

  Future<void> _removeLegacySession(SharedPreferences preferences) async {
    await preferences.remove(_legacySessionKey);
    await preferences.remove(_legacyPkceKey);
  }

  String _pkceKey(String key) => '$_pkcePrefix$key';

  @override
  Future<bool> hasAccessToken() => _secureStorage.containsKey(key: _sessionKey);

  @override
  Future<String?> accessToken() => _secureStorage.read(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _secureStorage.write(key: _sessionKey, value: persistSessionString);
    await _removeLegacySession(await _preferencesLoader());
  }

  @override
  Future<void> removePersistedSession() async {
    await _secureStorage.delete(key: _sessionKey);
    await _removeLegacySession(await _preferencesLoader());
  }

  @override
  Future<String?> getItem({required String key}) =>
      _secureStorage.read(key: _pkceKey(key));

  @override
  Future<void> setItem({required String key, required String value}) =>
      _secureStorage.write(key: _pkceKey(key), value: value);

  @override
  Future<void> removeItem({required String key}) =>
      _secureStorage.delete(key: _pkceKey(key));
}
