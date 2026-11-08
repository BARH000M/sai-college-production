import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/sai_theme.dart';

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({super.key, required this.onCompleted, required this.onCancel});

  final VoidCallback onCompleted;
  final VoidCallback onCancel;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _password.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث كلمة المرور.')),
      );
      widget.onCompleted();
    } on AuthException {
      if (mounted) setState(() => _error = 'تعذّر تحديث كلمة المرور. اطلب رابطًا جديدًا وحاول مجددًا.');
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر الاتصال بالخادم. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استعادة كلمة المرور'),
        leading: IconButton(onPressed: widget.onCancel, icon: const Icon(Icons.close)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.lock_reset_outlined, color: SaiColors.red, size: 42),
                        const SizedBox(height: 12),
                        Text('اختر كلمة مرور جديدة', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
                          validator: (value) => (value ?? '').length < 8 ? 'استخدم 8 أحرف على الأقل' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmation,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'),
                          validator: (value) => value != _password.text ? 'كلمتا المرور غير متطابقتين' : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: SaiColors.deepRed)),
                        ],
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _busy ? null : _save,
                          child: _busy
                              ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('حفظ كلمة المرور'),
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
