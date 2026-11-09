import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sai_college_mobile/design_system/design_system.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تسجيل الدخول. تحقق من البريد وكلمة المرور.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'أدخل بريدك الإلكتروني أولاً');
      return;
    }
    try {
      await Supabase.instance.client.auth
          .resetPasswordForEmail(_email.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال رابط إعادة التعيين إن كان الحساب موجوداً'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'تعذر إرسال رابط الاستعادة');
    }
  }

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
                children: [
                  const SaiLogo(size: 92),
                  const SizedBox(height: 16),
                  Text(
                    'كلية ساي التعليمية اليمنية الصينية',
                    textAlign: TextAlign.center,
                    style: SaiTextStyles.screenTitle.copyWith(fontSize: 20),
                  ),
                  const Text(
                    '也门赛艾教育学院',
                    style: TextStyle(color: SaiColors.gold, fontSize: 12),
                  ),
                  const SizedBox(height: 28),
                  SaiCard(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('تسجيل الدخول',
                              style: SaiTextStyles.screenTitle
                                  .copyWith(fontSize: 22)),
                          const SizedBox(height: 2),
                          const Text('ادخل إلى بوابتك الأكاديمية بأمان',
                              style: SaiTextStyles.caption),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              prefixIcon:
                                  Icon(Icons.mail_outline, size: 19),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            obscureText: _obscure,
                            onSubmitted: (_) => _signIn(),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon:
                                  const Icon(Icons.lock_outline, size: 19),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              onPressed: _resetPassword,
                              child: const Text('نسيت كلمة المرور؟'),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _error!,
                              style: const TextStyle(
                                  color: SaiColors.danger, fontSize: 11.5),
                            ),
                          ],
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: _busy ? null : _signIn,
                            child: _busy
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('دخول إلى النظام'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Yemen SAI Educational College',
                    style: SaiTextStyles.caption,
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