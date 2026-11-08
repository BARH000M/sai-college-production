import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth_repository.dart';
import '../../core/sai_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AuthRepository _repository;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = AuthRepository(Supabase.instance.client);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _authError(error.message));
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر الاتصال بالخادم. تحقق من الإنترنت وحاول مجددًا.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'اكتب بريدك الإلكتروني أولًا لإرسال رابط الاستعادة.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('إذا كان البريد مسجلًا، سيصلك رابط استعادة كلمة المرور.')),
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _authError(error.message));
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر إرسال الرابط الآن. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _authError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'أكد بريدك الإلكتروني أولًا، أو تواصل مع إدارة الكلية.';
    }
    return 'تعذّر تسجيل الدخول. تحقق من بيانات الحساب وحاول مجددًا.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Image.asset('assets/images/sai-logo.png', width: 64, height: 64),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'كلية ساي التعليمية اليمنية الصينية',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: SaiColors.red, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Text('تسجيل الدخول', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: SaiColors.navy,
                          fontWeight: FontWeight.w700,
                        )),
                        const SizedBox(height: 8),
                        const Text(
                          'استخدم الحساب الذي أنشأته إدارة الكلية.',
                          style: TextStyle(color: SaiColors.muted, height: 1.7),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty || !email.contains('@')) return 'أدخل بريدًا إلكترونيًا صحيحًا';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          onFieldSubmitted: (_) {
                            if (!_busy) _signIn();
                          },
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                          ),
                          validator: (value) => (value ?? '').isEmpty ? 'أدخل كلمة المرور' : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(_error!, style: const TextStyle(color: SaiColors.deepRed, height: 1.6)),
                        ],
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _busy ? null : _signIn,
                          child: _busy
                              ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('دخول إلى النظام'),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: _busy ? null : _sendReset,
                            child: const Text('نسيت كلمة المرور؟'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
