<<<<<<< HEAD
import 'dart:async';import 'package:flutter/material.dart';import 'package:supabase_flutter/supabase_flutter.dart';import 'core/theme.dart';import 'models/roles.dart';import 'data/sai_repository.dart';import 'screens/login.dart';import 'screens/shell.dart';
const projectUrl='https://aeryusbrulqdxjdynwfh.supabase.co';
Future<void> main()async{WidgetsFlutterBinding.ensureInitialized();const key=String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY',defaultValue:String.fromEnvironment('SUPABASE_ANON_KEY'));if(key.isEmpty){runApp(MaterialApp(theme:saiTheme(),home:const Scaffold(body:Center(child:Padding(padding:EdgeInsets.all(24),child:Text('أضف مفتاح Supabase publishable عبر --dart-define=SUPABASE_PUBLISHABLE_KEY=...'))))));return;}await Supabase.initialize(url:projectUrl,anonKey:key);runApp(const SaiApp());}
class SaiApp extends StatelessWidget{const SaiApp({super.key});@override Widget build(BuildContext context)=>MaterialApp(title:'كلية ساي التعليمية اليمنية الصينية',debugShowCheckedModeBanner:false,theme:saiTheme(),locale:const Locale('ar'),builder:(context,child)=>Directionality(textDirection:TextDirection.rtl,child:child!),home:const AuthGate());}
class AuthGate extends StatefulWidget{const AuthGate({super.key});@override State<AuthGate> createState()=>_AuthGateState();}
class _AuthGateState extends State<AuthGate>{StreamSubscription<AuthState>? sub;User? user;@override void initState(){super.initState();final auth=Supabase.instance.client.auth;user=auth.currentUser;sub=auth.onAuthStateChange.listen((event){if(mounted)setState(()=>user=event.session?.user);},onError:(Object e,StackTrace st){if(mounted)ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content:Text('حدث خطأ في اتصال المصادقة')));});}@override void dispose(){sub?.cancel();super.dispose();}@override Widget build(BuildContext context)=>user==null?const LoginScreen():RoleGate(key:ValueKey(user!.id),userId:user!.id);}
class RoleGate extends StatefulWidget{const RoleGate({super.key,required this.userId});final String userId;@override State<RoleGate> createState()=>_RoleGateState();}
class _RoleGateState extends State<RoleGate>{late final repo=SaiRepository(Supabase.instance.client);late Future<Set<AppRole>> future;@override void initState(){super.initState();reload();}void reload()=>future=repo.roles(widget.userId);@override Widget build(BuildContext context)=>FutureBuilder<Set<AppRole>>(future:future,builder:(context,s){if(!s.hasData){if(s.hasError)return Scaffold(body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('تعذّر تحميل الأدوار. تحقق من صلاحيات RLS.'),TextButton(onPressed:()=>setState(reload),child:const Text('إعادة المحاولة')),TextButton(onPressed:()=>repo.db.auth.signOut(),child:const Text('خروج'))])));return const Scaffold(body:Center(child:CircularProgressIndicator()));}if(s.data!.isEmpty)return Scaffold(body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('ليس لهذا الحساب دور معتمد'),TextButton(onPressed:()=>setState(reload),child:const Text('تحديث')),TextButton(onPressed:()=>repo.db.auth.signOut(),child:const Text('خروج'))])));return AppShell(roles:s.data!,repo:repo);});}
=======
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth_gate.dart';
import 'core/config/app_config.dart';
import 'core/sai_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isConfigured) {
    runApp(const SaiCollegeApp(configurationReady: false));
    return;
  }

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
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
                    'flutter run --dart-define=SUPABASE_ANON_KEY=PUBLIC_ANON_KEY',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.7),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'الرابط الافتراضي: https://aeryusbrulqdxjdynwfh.supabase.co',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.7, color: SaiColors.muted),
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
>>>>>>> bc640511466543cbefcb2dd07ee62ea075188efe
