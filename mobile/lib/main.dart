import 'core/access.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/repository.dart';
import 'ui/components.dart';
import 'ui/screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
  if (!previewMode) {
    if (publicKey.isEmpty || publicKey == 'PASTE_PUBLIC_KEY_HERE') {
      startupError =
          'أضف SUPABASE_PUBLIC_KEY في config/live.json ثم أعد البناء.';
    } else if (publicKey.startsWith('sb_secret_')) {
      startupError = 'استخدم المفتاح العام فقط، وليس المفتاح السري.';
    } else {
      try {
        // ignore: deprecated_member_use
        await Supabase.initialize(url: backendUrl, anonKey: publicKey);
      } catch (_) {
        startupError = 'تعذر تهيئة الاتصال. تحقق من المفتاح واتصال الإنترنت.';
      }
    }
  }
  runApp(SaiApp(startupError: startupError));
}

class SaiApp extends StatelessWidget {
  const SaiApp({super.key, this.startupError});
  final String? startupError;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SAI College',
    theme: saiTheme(),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: startupError != null
        ? Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: EmptyPanel(startupError!),
                ),
              ),
            ),
          )
        : const AuthGate(),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool previewSignedIn = false;
  @override
  Widget build(BuildContext context) {
    if (previewMode) {
      return previewSignedIn
          ? CollegeShell(
              account: Account('خالد فيصل اليافعي', {
                Role.super_admin,
              }, 'preview@sai.local'),
              onSignOut: () => setState(() => previewSignedIn = false),
            )
          : LoginScreen(
              onPreview: () => setState(() => previewSignedIn = true),
            );
    }
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) return const LoginScreen();
        return AccountLoader(key: ValueKey(session.user.id));
      },
    );
  }
}

class AccountLoader extends StatefulWidget {
  const AccountLoader({super.key});
  @override
  State<AccountLoader> createState() => _AccountLoaderState();
}

class _AccountLoaderState extends State<AccountLoader> {
  late Future<Account> future = Repository().account();
  @override
  Widget build(BuildContext context) => FutureBuilder<Account>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError || snapshot.data!.roles.isEmpty) {
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  EmptyPanel(
                    snapshot.hasError
                        ? 'تعذر تحميل الصلاحيات. تحقق من سياسات user_roles و profiles.'
                        : 'لم يتم تعيين دور لحسابك. تواصل مع الإدارة.',
                    retry: () =>
                        setState(() => future = Repository().account()),
                  ),
                  TextButton(
                    onPressed: () => Supabase.instance.client.auth.signOut(),
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return CollegeShell(
        account: snapshot.data!,
        onSignOut: () => Supabase.instance.client.auth.signOut(),
      );
    },
  );
}
