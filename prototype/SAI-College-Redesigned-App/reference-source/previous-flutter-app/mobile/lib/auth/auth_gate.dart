import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase.dart';
import '../shell/app_shell.dart';
import 'login_page.dart';
import 'profile.dart';
import 'recovery_flow.dart';
import 'recovery_page.dart';
import 'recovery_pending_store.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _sub;
  final RecoveryPendingSignOutStore _pendingStore =
      const PrefsRecoveryPendingSignOutStore();
  Profile? _profile;
  bool _loading = true;
  String? _error;
  PendingSignOut? _pending;
  bool _checkingPending = true;

  @override
  void initState() {
    super.initState();
    _sub = db.auth.onAuthStateChange.listen((state) {
      final signedIn = state.session != null;
      if (!signedIn) {
        setState(() {
          _profile = null;
          _loading = false;
        });
      } else {
        unawaited(_load());
        unawaited(_checkPending());
      }
    });
    unawaited(_load());
    unawaited(_checkPending());
  }

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    final user = db.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _profile = null;
          _loading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final profile = await loadProfile(user);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _error = profile == null
            ? 'لا يوجد ملف مستخدم لهذا الحساب — راجع إدارة المدرسة.'
            : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل الملف الشخصي: $e';
        _loading = false;
      });
    }
  }

  Future<void> _checkPending() async {
    if (db.auth.currentSession == null) {
      if (mounted) {
        setState(() {
          _pending = null;
          _checkingPending = false;
        });
      }
      return;
    }
    PendingSignOut? pending;
    try {
      pending = await _pendingStore.read();
    } catch (_) {
      pending = null;
    }
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _checkingPending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (db.auth.currentSession == null) return const LoginPage();
    if (_pending != null) {
      return RecoveryPage(
          resumePending: true,
          onFinished: () {
            setState(() => _pending = null);
            unawaited(_checkPending());
          });
    }
    if (_checkingPending || _loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_profile == null) {
      return Scaffold(
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 40),
                        const SizedBox(height: 12),
                        Text(_error ?? 'تعذّر قراءة الملف الشخصي',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: () => unawaited(_load()),
                            child: const Text('إعادة المحاولة')),
                        TextButton(
                            onPressed: () => unawaited(db.auth.signOut()),
                            child: const Text('تسجيل الخروج')),
                      ]))));
    }
    if (!_profile!.active) {
      return const Scaffold(
          body: Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('الحساب موقوف. تواصل مع إدارة المدرسة.',
                      textAlign: TextAlign.center))));
    }
    return AppShell(profile: _profile!);
  }
}
