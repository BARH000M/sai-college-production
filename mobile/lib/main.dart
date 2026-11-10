import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/demo_school.dart';
import 'data/demo_workspace.dart';
import 'data/repository.dart';
import 'ui/components.dart';
import 'ui/login_screen.dart';
import 'ui/screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
  DemoWorkspace? demo;
  if (previewMode) {
    try {
      demo = DemoWorkspace(await SharedPreferences.getInstance());
    } catch (_) {
      startupError = 'تعذر فتح بيانات المعاينة على هذا الجهاز.';
    }
  } else if (publicKey.isEmpty || publicKey == 'PASTE_PUBLIC_KEY_HERE') {
    startupError = 'أضف SUPABASE_PUBLIC_KEY في config/live.json ثم أعد البناء.';
  } else if (publicKey.startsWith('sb_secret_')) {
    startupError = 'استخدم المفتاح العام الخاص بتطبيقات المستخدمين.';
  } else {
    try {
      // initialize restores the SDK's saved session before we choose a screen.
      // ignore: deprecated_member_use
      await Supabase.initialize(url: backendUrl, anonKey: publicKey);
    } catch (_) {
      startupError = 'تعذر تهيئة الاتصال. تحقق من الإعدادات وحاول مجدداً.';
    }
  }
  runApp(SaiApp(startupError: startupError, demo: demo));
}

class SaiApp extends StatelessWidget {
  const SaiApp({super.key, this.startupError, this.demo});
  final String? startupError;
  final DemoWorkspace? demo;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Yemen SAI',
    theme: saiTheme(),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: startupError != null
        ? Scaffold(
            body: BrandBody(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: EmptyPanel(startupError!),
                ),
              ),
            ),
          )
        : demo != null
        ? PreviewGate(demo: demo!)
        : const AuthGate(),
  );
}

class PreviewGate extends StatelessWidget {
  const PreviewGate({super.key, required this.demo});
  final DemoWorkspace demo;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: demo,
    builder: (context, _) {
      if (!demo.signedIn) {
        return LoginScreen(onPreview: () => demo.setSignedIn(true));
      }
      final role = demo.role;
      return CollegeShell(
        key: ValueKey(role),
        account: Account(previewNames[role]!, {role}, ''),
        demo: demo,
        onSignOut: () => demo.setSignedIn(false),
      );
    },
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final GoTrueClient auth = Supabase.instance.client.auth;
  late String? userId;
  late final StreamSubscription<AuthState> subscription;

  @override
  void initState() {
    super.initState();
    userId = auth.currentSession?.user.id;
    subscription = auth.onAuthStateChange.listen(
      (_) {
        final next = auth.currentSession?.user.id;
        if (!mounted || next == userId) return;
        final previous = userId;
        setState(() => userId = next);
        if (previous != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
        }
      },
      onError: (Object _, StackTrace _) {
        // A connection error during refresh does not equal signing out.
        // The account loader shows a retry while the SDK retains the session.
      },
    );
  }

  @override
  void dispose() {
    unawaited(subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => userId == null
      ? const LoginScreen()
      : AccountLoader(key: ValueKey(userId));
}

class AccountLoader extends StatefulWidget {
  const AccountLoader({super.key});

  @override
  State<AccountLoader> createState() => _AccountLoaderState();
}

class _AccountLoaderState extends State<AccountLoader> {
  late Future<Account> future = load();
  StreamSubscription<List<Map<String, dynamic>>>? roleWatch;
  bool signingOut = false;

  @override
  void initState() {
    super.initState();
    final id = Supabase.instance.client.auth.currentUser?.id;
    if (id != null) {
      roleWatch = Supabase.instance.client
          .from('user_roles')
          .stream(primaryKey: ['user_id', 'role'])
          .eq('user_id', id)
          .listen((_) {
            if (mounted) setState(() => future = load());
          }, onError: (Object _, StackTrace _) {});
    }
  }

  @override
  void dispose() {
    if (roleWatch != null) unawaited(roleWatch!.cancel());
    super.dispose();
  }

  Future<Account> load() async {
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession?.isExpired == true) {
      await auth.refreshSession();
    }
    return Repository().account();
  }

  Future<void> signOut() =>
      Supabase.instance.client.auth.signOut(scope: SignOutScope.local);

  Future<void> signOutFromError() async {
    setState(() => signingOut = true);
    try {
      await signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر إتمام تسجيل الخروج. حاول مجدداً.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Account>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(
          body: BrandBody(child: Center(child: CircularProgressIndicator())),
        );
      }
      final account = snapshot.data;
      if (account == null || account.roles.isEmpty) {
        return Scaffold(
          body: BrandBody(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    EmptyPanel(
                      account == null
                          ? 'تعذر تحميل حسابك حالياً. تحقق من الاتصال ثم أعد المحاولة.'
                          : 'لم يُعيّن دور لهذا الحساب. يرجى مراجعة إدارة الكلية.',
                      retry: () => setState(() => future = load()),
                    ),
                    TextButton(
                      onPressed: signingOut ? null : signOutFromError,
                      child: const Text('تسجيل الخروج'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return CollegeShell(account: account, onSignOut: signOut);
    },
  );
}
