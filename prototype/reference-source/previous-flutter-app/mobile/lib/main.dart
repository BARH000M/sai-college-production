import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth/auth_gate.dart';
import 'core/supabase.dart';

// Legacy constant names retained for source/test compatibility.
const Color ysmsJade = Color(0xFF8F2636);
const Color ysmsCinnabar = Color(0xFFC69B4D);
const Color ysmsPaper = Color(0xFFF7F5EF);

ThemeData ysmsTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: ysmsJade).copyWith(
    primary: ysmsJade,
    onPrimary: Colors.white,
    secondary: ysmsCinnabar,
    surface: Colors.white,
    onSurface: const Color(0xFF332D2C),
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0xFFE9E3DA)),
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo',
    colorScheme: scheme,
    scaffoldBackgroundColor: ysmsPaper,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ysmsJade,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE9E3DA)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFCFBF8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: ysmsJade, width: 1.6),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFF6E7EA),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 76,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        backgroundColor: ysmsJade,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? configError;
  try {
    await initSupabase();
  } catch (e) {
    configError = e;
  }
  runApp(configError == null
      ? const SaiSchoolApp()
      : ConfigErrorApp(detail: '$configError'));
}

class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.detail});
  final String detail;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ysmsTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink()),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.settings_ethernet,
                      size: 40, color: Color(0xFF9A3412)),
                  const SizedBox(height: 14),
                  const Text('هذا الإصدار بلا إعداد خادم',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'لم تُمرَّر SUPABASE_URL و SUPABASE_ANON_KEY لحظة بناء التطبيق، لذلك لا يستطيع تسجيل الدخول. أعد البناء بعد ضبط الأسرار:',
                    style: TextStyle(fontSize: 13, height: 1.7),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F6F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE6E4DE)),
                    ),
                    child: const Text(
                      'flutter build apk --debug \\\n  --dart-define=SUPABASE_URL=... \\\n  --dart-define=SUPABASE_ANON_KEY=...',
                      style: TextStyle(
                          fontSize: 11, fontFamily: 'monospace', height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(detail,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B6B6B))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SaiSchoolApp extends StatelessWidget {
  const SaiSchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'كلية ساي',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ysmsTheme(),
      builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink()),
      home: const AuthGate(),
    );
  }
}
