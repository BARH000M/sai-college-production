import 'package:shared_preferences/shared_preferences.dart';
import 'recovery_flow.dart';

class PrefsRecoveryCooldownStore implements RecoveryCooldownStore {
  const PrefsRecoveryCooldownStore();
  static const String _prefix = 'recovery.resend.';
  static const Duration _maxAge = Duration(hours: 6);
  String _key(String email) => '$_prefix${email.trim().toLowerCase()}';

  @override
  Future<DateTime?> readSentAt(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final millis = prefs.getInt(_key(email));
      if (millis == null) return null;
      final at = DateTime.fromMillisecondsSinceEpoch(millis);
      if (DateTime.now().difference(at) > _maxAge) {
        await prefs.remove(_key(email));
        return null;
      }
      return at.isAfter(DateTime.now()) ? DateTime.now() : at;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeSentAt(String email, DateTime at) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key(email), at.millisecondsSinceEpoch);
    } catch (_) {}
  }

  @override
  Future<void> clearSentAt(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(email));
    } catch (_) {}
  }
}
