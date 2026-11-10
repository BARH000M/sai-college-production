import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase.dart';
import 'recovery_page.dart';
import 'recovery_pending_store.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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

  String _message(Object e) {
    if (e is AuthException) {
      final text = e.message.toLowerCase();
      if (text.contains('invalid login')) {
        return 'البريد أو كلمة المرور غير صحيحة.';
      }
      if (text.contains('email not confirmed')) {
        return 'البريد لم يُؤكَّد بعد — راجع بريدك أو إدارة المدرسة.';
      }
      if (text.contains('too many')) {
        return 'محاولات كثيرة. انتظر دقيقة ثم أعد المحاولة.';
      }
      return e.message;
    }
    return 'تعذّر تسجيل الدخول. تحقق من الاتصال.';
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'أدخل البريد وكلمة المرور.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await db.auth.signInWithPassword(email: email, password: password);
      await clearPendingSignOutAfterLogin();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(children: [
      const Positioned.fill(child: _HeritageBackground()),
      SafeArea(
          child: Center(
              child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Container(
                        height: 58,
                        width: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: const Color(0xFF8F2636),
                            border: Border.all(color: const Color(0xFFF3D9C8)),
                            borderRadius: BorderRadius.circular(16)),
                        child: const Text('SAI',
                            style:
                                TextStyle(color: Colors.white, fontSize: 18))),
                    const SizedBox(width: 12),
                    const Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('كلية ساي',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF8F2636))),
                          Text('التعليمية اليمنية الصينية',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF61716B)))
                        ]))
                  ]),
                  const SizedBox(height: 24),
                  const Text('也门赛艾教育学院',
                      style: TextStyle(
                          color: Color(0xFF8F2636),
                          letterSpacing: 4,
                          fontSize: 11)),
                  const SizedBox(height: 8),
                  Text('أهلاً بعودتك',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF8F2636))),
                  const SizedBox(height: 6),
                  const Text('سجّل الدخول لفتح بوابتك المصرح بها فقط.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF61716B))),
                  const SizedBox(height: 24),
                  TextField(
                      controller: _email,
                      textDirection: TextDirection.ltr,
                      autofillHints: const [AutofillHints.username],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s'))
                      ],
                      decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.mail_outline),
                          border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _password,
                      textDirection: TextDirection.ltr,
                      autofillHints: const [AutofillHints.password],
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => unawaited(_submit()),
                      decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure)))),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFDECEC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE7B4B4))),
                        child: Text(_error!,
                            style:
                                const TextStyle(fontSize: 12.5, height: 1.5))),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: _busy ? null : () => unawaited(_submit()),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('دخول آمن')),
                  const SizedBox(height: 4),
                  TextButton(
                      onPressed: _busy
                          ? null
                          : () => unawaited(Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const RecoveryPage()))),
                      child: const Text('نسيت كلمة المرور؟')),
                ])),
      )))
    ]));
  }
}

class _HeritageBackground extends StatelessWidget {
  const _HeritageBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _InkWashPainter());
  }
}

class _InkWashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFF7F5EF));
    final mountain = Paint()
      ..color = const Color(0xFF8F2636).withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.82)
      ..quadraticBezierTo(size.width * 0.18, size.height * 0.60,
          size.width * 0.38, size.height * 0.82)
      ..quadraticBezierTo(
          size.width * 0.64, size.height * 0.54, size.width, size.height * 0.80)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, mountain);
    final foreground = Paint()..color = const Color(0xFF8F2636);
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.93, size.width, size.height * 0.07),
        foreground);
    final seal = Paint()..color = const Color(0xFF8F2636);
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.16), 32, seal);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
