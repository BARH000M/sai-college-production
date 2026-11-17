import 'package:supabase_flutter/supabase_flutter.dart';

class ContactProfile {
  const ContactProfile({
    required this.fullName,
    this.phone,
    required this.locale,
  });
  final String fullName;
  final String? phone;
  final String locale;

  factory ContactProfile.fromJson(Map<String, dynamic> row) => ContactProfile(
    fullName: row['full_name'] as String,
    phone: row['phone'] as String?,
    locale: row['preferred_locale'] as String,
  );
}

/// Auth email and role/enrolment data never participate in contact updates.
class ProfileRepository {
  ProfileRepository({SupabaseClient? client}) : _injectedClient = client;
  final SupabaseClient? _injectedClient;
  SupabaseClient get client => _injectedClient ?? Supabase.instance.client;
  String get _userId =>
      client.auth.currentUser?.id ??
      (throw StateError('انتهت الجلسة. يرجى تسجيل الدخول.'));

  static Map<String, dynamic> validatedValues(
    String name,
    String phone,
    String locale,
  ) {
    final cleanName = name.trim();
    final cleanPhone = phone.trim();
    if (cleanName.runes.length < 2 ||
        cleanName.runes.length > 120 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(cleanName)) {
      throw const FormatException(
        'الاسم الكامل يجب أن يكون بين حرفين و١٢٠ حرفاً دون محارف تحكم.',
      );
    }
    final digits = cleanPhone.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (cleanPhone.isNotEmpty &&
        (!RegExp(r'^[+0-9][0-9 ()-]{5,31}$').hasMatch(cleanPhone) ||
            digits < 6 ||
            digits > 20)) {
      throw const FormatException(
        'رقم الهاتف غير صالح. استخدم أرقاماً مع رمز الدولة عند الحاجة.',
      );
    }
    if (locale != 'ar' && locale != 'en') {
      throw const FormatException('لغة التواصل غير مدعومة.');
    }
    return {
      'full_name': cleanName,
      'phone': cleanPhone.isEmpty ? null : cleanPhone,
      'preferred_locale': locale,
    };
  }

  Future<ContactProfile?> load() async {
    final row = await client
        .from('profiles')
        .select('full_name,phone,preferred_locale')
        .eq('id', _userId)
        .maybeSingle();
    return row == null ? null : ContactProfile.fromJson(row);
  }

  Future<ContactProfile> save(String name, String phone, String locale) async {
    final values = validatedValues(name, phone, locale);
    final row = await client
        .from('profiles')
        .update(values)
        .eq('id', _userId)
        .select('full_name,phone,preferred_locale')
        .maybeSingle();
    if (row == null) {
      throw StateError('لم يُحدّث الملف الشخصي؛ تحقق من صلاحية الحساب.');
    }
    return ContactProfile.fromJson(row);
  }
}
