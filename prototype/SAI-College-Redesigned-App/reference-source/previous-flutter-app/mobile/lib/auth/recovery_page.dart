import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'recovery_cooldown_store.dart';
import 'recovery_flow.dart';
import 'recovery_pending_store.dart';
import 'supabase_recovery_gateway.dart';

class RecoveryPage extends StatefulWidget {
  const RecoveryPage(
      {super.key, this.flow, this.resumePending = false, this.onFinished});
  final RecoveryFlow? flow;
  final bool resumePending;
  final VoidCallback? onFinished;
  @override
  State<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<RecoveryPage> {
  late final RecoveryFlow _flow = widget.flow ??
      RecoveryFlow(
        gateway: const SupabaseRecoveryGateway(),
        cooldownStore: const PrefsRecoveryCooldownStore(),
        pendingSignOutStore: const PrefsRecoveryPendingSignOutStore(),
      );
  final TextEditingController _email = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  Timer? _cooldownTicker;
  bool _resuming = false;

  @override
  void initState() {
    super.initState();
    if (widget.resumePending) {
      _resuming = true;
      unawaited(_resume());
    }
  }

  Future<void> _resume() async {
    await _flow.resumePendingSignOut();
    if (!mounted) return;
    setState(() => _resuming = false);
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String _message(Object e) {
    if (e is RecoveryRejected) return e.message;
    if (e is RecoveryStepError) {
      return 'ترتيب الخطوات غير صحيح — أعد المحاولة من البداية.';
    }
    return 'تعذّرت العملية. تحقق من الاتصال ثم أعد المحاولة.';
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startCooldownTicker() {
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_flow.canResend) {
        timer.cancel();
        _cooldownTicker = null;
      }
      setState(() {});
    });
  }

  int get _cooldownSeconds =>
      (_flow.resendRemaining.inMilliseconds / 1000).ceil();

  Future<void> _request() async {
    await _run(() => _flow.requestCode(_email.text));
    if (!mounted) return;
    if (!_flow.canResend) _startCooldownTicker();
  }

  Future<void> _resend() async {
    await _run(() => _flow.requestCode(_flow.email));
    if (!mounted) return;
    if (_error == null) _code.clear();
    if (!_flow.canResend) _startCooldownTicker();
  }

  Future<void> _verify() => _run(() => _flow.verifyCode(_code.text));

  Future<void> _save() async {
    if (_password.text != _confirm.text) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين');
      return;
    }
    await _run(() => _flow.submitPassword(_password.text));
  }

  Future<void> _finishSignOut() => _run(() => _flow.completeSignOut());

  @override
  Widget build(BuildContext context) {
    final step = _flow.step;
    if (_resuming) {
      return Scaffold(
          appBar: AppBar(title: const Text('استعادة كلمة المرور')),
          body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('استعادة كلمة المرور')),
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Progress(step: step),
                  const SizedBox(height: 18),
                  if (step == RecoveryStep.idle) ..._requestStep(context),
                  if (step == RecoveryStep.codeSent) ..._codeStep(context),
                  if (step == RecoveryStep.verified) ..._passwordStep(context),
                  if (step == RecoveryStep.passwordUpdated)
                    ..._signOutStep(context),
                  if (step == RecoveryStep.signedOut) ..._doneStep(context),
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
                ])),
      ))),
    );
  }

  List<Widget> _requestStep(BuildContext context) => <Widget>[
        Text('أدخل بريدك الإلكتروني',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text(
            'سنرسل رسالة تحتوي رابطاً يُفتح على الموقع، ورمزاً مكوّناً من أرقام يُستخدم هنا في التطبيق. أي من الطريقتين تكفي.',
            style: TextStyle(fontSize: 13, height: 1.7, color: Colors.black54)),
        const SizedBox(height: 20),
        TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            onSubmitted: (_) => unawaited(_request()),
            decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.mail_outline),
                border: OutlineInputBorder())),
        const SizedBox(height: 18),
        FilledButton(
            onPressed: (_busy || !_flow.canResend)
                ? null
                : () => unawaited(_request()),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_flow.canResend
                    ? 'إرسال الرمز'
                    : 'إعادة الإرسال بعد $_cooldownSeconds ثانية')),
        if (!_flow.canResend)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  'أُرسل رمز قبل قليل. الانتظار دقيقة واحدة يحمي حسابك من إيقاف الإرسال مؤقتاً — تحقّق من مجلد الرسائل غير المرغوبة أثناء الانتظار.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, height: 1.6, color: Colors.black45))),
      ];

  List<Widget> _codeStep(BuildContext context) => <Widget>[
        Text('أدخل الرمز', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
            'أرسلنا رسالة إلى ${_flow.email}. أدخل الأرقام من الرسالة، أو افتح الرابط نفسه على الموقع.',
            style: const TextStyle(
                fontSize: 13, height: 1.7, color: Colors.black54)),
        const SizedBox(height: 20),
        TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 8,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            onSubmitted: (_) => unawaited(_verify()),
            style: const TextStyle(
                fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
                labelText: 'رمز التحقق',
                hintText: '— — — — — —',
                border: OutlineInputBorder(),
                counterText: '')),
        const SizedBox(height: 18),
        FilledButton(
            onPressed: _busy ? null : () => unawaited(_verify()),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('تحقق من الرمز')),
        const SizedBox(height: 6),
        TextButton(
            onPressed:
                (_busy || !_flow.canResend) ? null : () => unawaited(_resend()),
            child: Text(
                _flow.canResend
                    ? 'لم يصل الرمز؟ أرسل مرة أخرى'
                    : 'إعادة الإرسال متاحة بعد $_cooldownSeconds ثانية',
                textAlign: TextAlign.center)),
        const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
                'طلبات كثيرة على العنوان نفسها تُوقف الإرسال مؤقتاً — تحقّق من مجلد الرسائل غير المرغوبة أولاً.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, height: 1.6, color: Colors.black45))),
      ];

  List<Widget> _passwordStep(BuildContext context) => <Widget>[
        Text('كلمة مرور جديدة',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('تم التحقق من الرمز. اختر كلمة مرور جديدة لحسابك.',
            style: TextStyle(fontSize: 13, height: 1.7, color: Colors.black54)),
        const SizedBox(height: 20),
        TextField(
            controller: _password,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
                labelText: 'كلمة المرور الجديدة',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure)))),
        const SizedBox(height: 12),
        TextField(
            controller: _confirm,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => unawaited(_save()),
            decoration: const InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder())),
        const SizedBox(height: 18),
        FilledButton(
            onPressed: _busy ? null : () => unawaited(_save()),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('حفظ كلمة المرور')),
      ];

  List<Widget> _signOutStep(BuildContext context) => <Widget>[
        const SizedBox(height: 8),
        const Icon(Icons.lock_person_outlined,
            size: 44, color: Color(0xFFB45309)),
        const SizedBox(height: 12),
        Text('كلمة المرور تغيّرت — بقي إنهاء الجلسة',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        const Text(
            'تم حفظ كلمة المرور، لكن هذا الجهاز ما زال يحمل جلسة استعادة. لن نعتبر العملية منتهية قبل أن تُغلق الجلسة فعلياً — اضغط الزر لإعادة المحاولة.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.7, color: Colors.black54)),
        if (widget.resumePending) ...[
          const SizedBox(height: 12),
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFDF6E7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE8D5A8))),
              child: Text(
                  'هذه محاولة استعادة لم تكتمل على هذا الجهاز${_flow.email.isEmpty ? '' : ' (${_flow.email})'}. أُغلقت العملية قبل إنهاء الجلسة، لذلك نكملها الآن بدل تجاهلها.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11.5, height: 1.7, color: Colors.black87))),
        ],
        const SizedBox(height: 20),
        FilledButton(
            onPressed: _busy ? null : () => unawaited(_finishSignOut()),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('إنهاء الجلسة الآن')),
      ];

  List<Widget> _doneStep(BuildContext context) => <Widget>[
        const SizedBox(height: 8),
        const Icon(Icons.verified_user_outlined,
            size: 44, color: Color(0xFF1F6F5C)),
        const SizedBox(height: 12),
        Text('تم تحديث كلمة المرور',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text(
            'تم إنهاء جلسة الاستعادة على هذا الجهاز نهائياً. سجّل الدخول بكلمة المرور الجديدة.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.7, color: Colors.black54)),
        const SizedBox(height: 20),
        FilledButton(
            onPressed:
                widget.onFinished ?? () => Navigator.of(context).maybePop(),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('العودة لتسجيل الدخول')),
      ];
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});
  final RecoveryStep step;
  @override
  Widget build(BuildContext context) {
    const order = <RecoveryStep>[
      RecoveryStep.idle,
      RecoveryStep.codeSent,
      RecoveryStep.verified
    ];
    final finished =
        step == RecoveryStep.passwordUpdated || step == RecoveryStep.signedOut;
    final current = finished ? order.length : order.indexOf(step);
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
        children: List<Widget>.generate(order.length, (i) {
      final reached = i <= current;
      return Expanded(
          child: Padding(
              padding: EdgeInsets.only(left: i == order.length - 1 ? 0 : 6),
              child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                      color: reached ? primary : const Color(0xFFE3E1DA),
                      borderRadius: BorderRadius.circular(2)))));
    }));
  }
}
