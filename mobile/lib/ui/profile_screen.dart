import 'package:flutter/material.dart';
import '../data/profile_repository.dart';
import 'components.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.email,
    required this.roleNames,
    this.repository,
  });
  final String email;
  final List<String> roleNames;
  final ProfileRepository? repository;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileRepository repository =
      widget.repository ?? ProfileRepository();
  final name = TextEditingController();
  final phone = TextEditingController();
  bool loading = true, saving = false, missing = false, loadFailed = false;
  String locale = 'ar';
  String? error, success;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      loadFailed = false;
      error = null;
      success = null;
    });
    try {
      final profile = await repository.load();
      if (!mounted) return;
      if (profile != null) {
        name.text = profile.fullName;
        phone.text = profile.phone ?? '';
        locale = profile.locale;
      }
      setState(() {
        missing = profile == null;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          loadFailed = true;
          error = 'تعذر تحميل الملف الشخصي. تحقق من الاتصال وحاول مجدداً.';
        });
      }
    }
  }

  Future<void> save() async {
    if (saving) return;
    try {
      ProfileRepository.validatedValues(name.text, phone.text, locale);
    } on FormatException catch (e) {
      setState(() {
        error = e.message;
        success = null;
      });
      return;
    }
    setState(() {
      saving = true;
      error = null;
      success = null;
    });
    try {
      final saved = await repository.save(name.text, phone.text, locale);
      if (!mounted) return;
      name.text = saved.fullName;
      phone.text = saved.phone ?? '';
      setState(() {
        locale = saved.locale;
        success = 'تم حفظ ملفك الشخصي.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
              'لم تُحفظ التغييرات. تحقق من الاتصال وصلاحية الحساب ثم حاول مجدداً.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeading('ملفي الشخصي'),
        Text(widget.email, textDirection: TextDirection.ltr),
        Wrap(
          spacing: 8,
          children: [
            for (final role in widget.roleNames) Chip(label: Text(role)),
          ],
        ),
        const Text(
          'البريد الإلكتروني وأدوار الحساب للعرض فقط. لغة التواصل لا تغير لغة واجهة التطبيق.',
        ),
        const SizedBox(height: 16),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (missing)
          const Text(
            'الملف الشخصي غير موجود. أعد تسجيل الدخول لإكمال إعداد الحساب.',
          )
        else if (loadFailed) ...[
          Text(error!, semanticsLabel: error),
          TextButton(onPressed: load, child: const Text('إعادة المحاولة')),
        ] else ...[
          TextField(
            controller: name,
            enabled: !saving,
            maxLength: 120,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(labelText: 'الاسم الكامل'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phone,
            enabled: !saving,
            maxLength: 32,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(labelText: 'رقم الهاتف'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: ['ar', 'en'].contains(locale) ? locale : null,
            decoration: const InputDecoration(labelText: 'لغة التواصل'),
            items: const [
              DropdownMenuItem(value: 'ar', child: Text('العربية')),
              DropdownMenuItem(value: 'en', child: Text('English')),
            ],
            onChanged: saving
                ? null
                : (value) => setState(() {
                    locale = value ?? locale;
                  }),
          ),
          if (error != null)
            Semantics(
              liveRegion: true,
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          if (success != null)
            Semantics(liveRegion: true, child: Text(success!)),
          const SizedBox(height: 16),
          RedButton(
            saving ? 'جارٍ الحفظ...' : 'حفظ التغييرات',
            onPressed: saving ? null : save,
          ),
          TextButton(
            onPressed: saving ? null : load,
            child: const Text('إعادة تحميل البيانات'),
          ),
        ],
      ],
    ),
  );
}
