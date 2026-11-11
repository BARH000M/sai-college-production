import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/login_page.dart';
import '../features/auth/password_recovery_page.dart';
import '../features/home/app_shell.dart';
import 'app_identity.dart';
import 'auth_repository.dart';
import 'sai_theme.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthRepository _repository;
  late final StreamSubscription<AuthState> _subscription;
  User? _user;
  AppIdentity? _identity;
  Object? _error;
  bool _loading = false;
  bool _passwordRecovery = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _repository = AuthRepository(Supabase.instance.client);
    _user = _repository.currentUser;
    if (_user != null) unawaited(_loadIdentity(_user!));
    _subscription = _repository.authChanges.listen(_onAuthChanged);
  }

  void _onAuthChanged(AuthState state) {
    final user = state.session?.user;
    if (state.event == AuthChangeEvent.passwordRecovery && user != null) {
      setState(() {
        _user = user;
        _identity = null;
        _error = null;
        _loading = false;
        _passwordRecovery = true;
      });
      return;
    }
    if (_passwordRecovery && user != null) {
      setState(() => _user = user);
      return;
    }
    if (user == null) {
      _loadGeneration++;
      if (!mounted) return;
      setState(() {
        _user = null;
        _identity = null;
        _error = null;
        _loading = false;
        _passwordRecovery = false;
      });
      return;
    }
    if (_user?.id != user.id || _identity == null) {
      setState(() {
        _user = user;
        _identity = null;
      });
      unawaited(_loadIdentity(user));
    }
  }

  Future<void> _loadIdentity(User user) async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final identity = await _repository.loadIdentity(user);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _identity = identity;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const LoginPage();
    if (_passwordRecovery) {
      return PasswordRecoveryPage(
        onCompleted: () {
          setState(() => _passwordRecovery = false);
          if (_user != null) unawaited(_loadIdentity(_user!));
        },
        onCancel: () => unawaited(_repository.signOut()),
      );
    }
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_identity != null) return AppShell(identity: _identity!);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_off_outlined, size: 48, color: SaiColors.red),
                  const SizedBox(height: 16),
                  Text(
                    _error is IdentityLoadException
                        ? (_error as IdentityLoadException).message
                        : 'تعذّر تحميل بيانات الحساب. تحقق من الاتصال وحاول مجددًا.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(height: 1.8),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => unawaited(_loadIdentity(_user!)),
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                  TextButton(
                    onPressed: () => unawaited(_repository.signOut()),
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
