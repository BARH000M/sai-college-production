import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'components.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onPreview});
  final Future<void> Function()? onPreview;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false;
  bool hidden = true;
  String? message;
  bool get demo => widget.onPreview != null;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || (!demo && !form.currentState!.validate())) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (demo) {
        await widget.onPreview!();
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on AuthException {
      if (mounted) {
        setState(
          () => message = 'تعذر تسجيل الدخول. تحقق من البريد وكلمة المرور.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = demo
              ? 'تعذر حفظ المعاينة على الجهاز.'
              : 'تعذر الاتصال. تحقق من الإنترنت وحاول مجدداً.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
    final address = email.text.trim();
    if (!address.contains('@')) {
      setState(() => message = 'أدخل بريداً إلكترونياً صحيحاً أولاً.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(address);
      if (mounted) {
        setState(
          () => message = 'إذا كان البريد مسجلاً فستصلك رسالة الاستعادة.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => message = 'تعذر إرسال الرسالة. حاول لاحقاً.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BrandBody(
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SaiHeader(height: 193, child: Center(child: Brand())),
            const ReferenceArt(rect: ReferenceArt.campus, height: 156),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Transform.translate(
                    offset: const Offset(0, -20),
                    child: SaiCard(
                      padding: 20,
                      child: Form(
                        key: form,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                demo ? 'معاينة التطبيق' : 'تسجيل الدخول',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: darkRed,
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (demo)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 18),
                                  child: Text(
                                    'استكشف واجهات الكلية والدروس والبيانات التوضيحية من خلال حسابات المعاينة.',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else ...[
                                TextFormField(
                                  controller: email,
                                  keyboardType: TextInputType.emailAddress,
                                  textDirection: TextDirection.ltr,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  autofillHints: const [AutofillHints.username],
                                  decoration: const InputDecoration(
                                    hintText: 'البريد الإلكتروني',
                                    prefixIcon: Icon(Icons.mail_outline),
                                  ),
                                  validator: (value) =>
                                      value != null &&
                                          value.trim().contains('@')
                                      ? null
                                      : 'أدخل بريداً صحيحاً',
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: password,
                                  obscureText: hidden,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  decoration: InputDecoration(
                                    hintText: 'كلمة المرور',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: hidden
                                          ? 'إظهار كلمة المرور'
                                          : 'إخفاء كلمة المرور',
                                      onPressed: () =>
                                          setState(() => hidden = !hidden),
                                      icon: Icon(
                                        hidden
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) =>
                                      value != null && value.isNotEmpty
                                      ? null
                                      : 'أدخل كلمة المرور',
                                  onFieldSubmitted: (_) => submit(),
                                ),
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: TextButton(
                                    onPressed: busy ? null : resetPassword,
                                    child: const Text('نسيت كلمة المرور؟'),
                                  ),
                                ),
                              ],
                              if (message != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    message!,
                                    style: const TextStyle(color: darkRed),
                                  ),
                                ),
                              RedButton(
                                busy
                                    ? 'جارٍ التحميل…'
                                    : (demo
                                          ? 'دخول المعاينة'
                                          : 'دخول إلى النظام'),
                                onPressed: busy ? null : submit,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                demo
                                    ? 'معاينة • بيانات توضيحية'
                                    : 'كلية ساي التعليمية',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
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
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    ),
  );
}
