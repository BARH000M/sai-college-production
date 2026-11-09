import 'package:shared_preferences/shared_preferences.dart';
import 'recovery_flow.dart';

class PrefsRecoveryPendingSignOutStore implements RecoveryPendingSignOutStore {
  const PrefsRecoveryPendingSignOutStore();
  static const String _emailKey = 'recovery.pending-signout.email';
  static const String _atKey = 'recovery.pending-signout.at';

  @override
  Future<PendingSignOut?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_emailKey);
      if (email == null || email.trim().isEmpty) return null;
      final at = prefs.getInt(_atKey);
      return PendingSignOut(
          email: email,
          changedAt: at == null
              ? DateTime.fromMillisecondsSinceEpoch(0)
              : DateTime.fromMillisecondsSinceEpoch(at));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(PendingSignOut value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_atKey, value.changedAt.millisecondsSinceEpoch);
      await prefs.setString(_emailKey, value.email);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_emailKey);
      await prefs.remove(_atKey);
    } catch (_) {}
  }
}

Future<void> clearPendingSignOutAfterLogin() async {
  await const PrefsRecoveryPendingSignOutStore().clear();
}
