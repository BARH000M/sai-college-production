import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth_gate.dart';
import 'core/sai_theme.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    runApp(const SaiCollegeApp(configurationReady: false));
    return;
  }

  try {
    await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
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
      theme: saiTheme,
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
          ? const AuthGate()
          : ConfigurationRequiredPage(error: startupError),
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
                  Image.asset('assets/images/sai-logo.png', width: 72, height: 72),
                  const SizedBox(height: 24),
                  Text('إعداد الاتصال مطلوب', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  const Text(
                    'مرّر رابط Supabase ومفتاح anon العام عند تشغيل التطبيق. لا تضع كلمة مرور قاعدة البيانات أو service_role key في التطبيق.',
                    style: TextStyle(height: 1.8, color: SaiColors.muted),
                  ),
                  const SizedBox(height: 18),
                  const SelectableText(
                    'flutter run --dart-define=SUPABASE_URL=https://PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=PUBLIC_ANON_KEY',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.7),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    const Text('تعذّر بدء اتصال Supabase. تحقق من الإعدادات ثم أعد التشغيل.'),
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
