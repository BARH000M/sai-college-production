import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth_gate.dart' as modular;
import 'core/config/app_config.dart';
import 'core/sai_theme.dart';
import 'core/theme.dart' as alternate_theme;
import 'data/sai_repository.dart';
import 'models/roles.dart' as alternate;
import 'screens/login.dart';
import 'screens/shell.dart' as alternate;

const _useAlternateShell = bool.fromEnvironment('SAI_USE_ALTERNATE_SHELL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final key = AppConfig.supabaseKey;
  if (AppConfig.supabaseUrl.trim().isEmpty || key.isEmpty) {
    runApp(const SaiCollegeApp(configurationReady: false));
    return;
  }

  try {
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: key);
    runApp(const SaiCollegeApp(configurationReady: true));
  } catch (error) {
    runApp(SaiCollegeApp(configurationReady: false, startupError: error));
  }
}

class SaiCollegeApp extends StatelessWidget {
  const SaiCollegeApp({
    super.key,
    required this.configurationReady,
    this.startupError,
  });

  final bool configurationReady;
  final Object? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'كلية ساي',
      debugShowCheckedModeBanner: false,
      theme: _useAlternateShell ? alternate_theme.saiTheme() : saiTheme,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: configurationReady
          ? (_useAlternateShell
              ? const _AlternateAuthGate()
              : const modular.AuthGate())
          : ConfigurationRequiredPage(error: startupError),
    );
  }
}

class _AlternateAuthGate extends StatefulWidget {
  const _AlternateAuthGate();

  @override
  State<_AlternateAuthGate> createState() => _AlternateAuthGateState();
}

class _AlternateAuthGateState extends State<_AlternateAuthGate> {
  late final StreamSubscription<AuthState> _subscription;
  User? _user;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    _user = auth.currentUser;
    _subscription = auth.onAuthStateChange.listen(
      (event) {
        if (mounted) {
          setState(() {
            _user = event.session?.user;
            _error = null;
          });
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (mounted) setState(() => _error = error);
      },
    );
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return const Scaffold(
        body: Center(child: Text('حدث خطأ في اتصال المصادقة')),
      );
    }
    final user = _user;
    return user == null
        ? const LoginScreen()
        : _AlternateRoleGate(key: ValueKey(user.id), userId: user.id);
  }
}

class _AlternateRoleGate extends StatefulWidget {
  const _AlternateRoleGate({super.key, required this.userId});

  final String userId;

  @override
  State<_AlternateRoleGate> createState() => _AlternateRoleGateState();
}

class _AlternateRoleGateState extends State<_AlternateRoleGate> {
  late final _repository = SaiRepository(Supabase.instance.client);
  late Future<Set<alternate.AppRole>> _roles;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _roles = _repository.roles(widget.userId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Set<alternate.AppRole>>(
      future: _roles,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || snapshot.data!.isEmpty) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.hasError
                        ? 'تعذّر تحميل الأدوار. تحقق من صلاحيات RLS.'
                        : 'ليس لهذا الحساب دور معتمد',
                  ),
                  TextButton(
                    onPressed: () => setState(_reload),
                    child: Text(snapshot.hasError ? 'إعادة المحاولة' : 'تحديث'),
                  ),
                  TextButton(
                    onPressed: () => _repository.db.auth.signOut(),
                    child: const Text('خروج'),
                  ),
                ],
              ),
            ),
          );
        }
        return alternate.AppShell(roles: snapshot.data!, repo: _repository);
      },
    );
  }
}

class ConfigurationRequiredPage extends StatelessWidget {
  const ConfigurationRequiredPage({super.key, this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/images/sai-logo.png',
                      width: 72, height: 72),
                  const SizedBox(height: 24),
                  Text('إعداد الاتصال مطلوب',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  const Text(
                    'مرّر مفتاح Supabase العام عند تشغيل التطبيق. لا تضع كلمة مرور قاعدة البيانات أو service_role key في التطبيق.',
                    style: TextStyle(height: 1.8, color: SaiColors.muted),
                  ),
                  const SizedBox(height: 18),
                  const SelectableText(
                    'flutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=PUBLIC_KEY',
                    style: TextStyle(
                        fontFamily: 'monospace', fontSize: 12, height: 1.7),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'اسم SUPABASE_ANON_KEY القديم ما زال مقبولاً كمفتاح احتياطي. لتشغيل الواجهة البديلة استخدم --dart-define=SAI_USE_ALTERNATE_SHELL=true.',
                    style: TextStyle(
                        fontSize: 11, height: 1.7, color: SaiColors.muted),
                  ),
                  const Text(
                    'الرابط الافتراضي: https://aeryusbrulqdxjdynwfh.supabase.co',
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.7,
                        color: SaiColors.muted),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    const Text(
                        'تعذّر بدء اتصال Supabase. تحقق من الإعدادات ثم أعد التشغيل.'),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
