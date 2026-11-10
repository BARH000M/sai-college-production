import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/access.dart';

/// The same public.sai_system_settings table as the web settings editor.
/// RLS is authoritative; this UI is only a convenience, not a permission check.
class LiveSystemSettingsScreen extends StatefulWidget {
  const LiveSystemSettingsScreen({super.key, required this.roles});
  final Set<Role> roles;

  @override
  State<LiveSystemSettingsScreen> createState() => _LiveSystemSettingsScreenState();
}

class _SettingsSection {
  const _SettingsSection(this.id, this.name, this.keys, {this.superOnly = false});
  final String id, name;
  final Map<String, String> keys;
  final bool superOnly;
}

const _sections = <_SettingsSection>[
  _SettingsSection('general', 'الإعداد العام', {'college_name':'اسم الكلية','website_url':'الموقع','contact_email':'البريد','contact_phone':'الهاتف','address':'العنوان'}),
  _SettingsSection('sessions', 'إعداد الجلسة', {'default_session_id':'الجلسة الافتراضية','registration_open':'التسجيل مفتوح؟'}),
  _SettingsSection('notifications', 'الإشعارات', {'push_enabled':'الإشعارات','digest_enabled':'الملخص','quiet_hours':'ساعات الهدوء'}),
  _SettingsSection('sms', 'الرسائل القصيرة', {'enabled':'تفضيل التشغيل','provider_name':'المزود','sender_name':'المرسل'}),
  _SettingsSection('whatsapp', 'واتساب', {'enabled':'تفضيل التشغيل','business_number':'رقم العمل','template_namespace':'القوالب'}),
  _SettingsSection('email', 'البريد الإلكتروني', {'enabled':'تفضيل التشغيل','sender_address':'بريد المرسل','sender_name':'اسم المرسل'}),
  _SettingsSection('payments', 'طرق الدفع', {'default_currency':'العملة','invoice_prefix':'بادئة الفاتورة','enabled_methods':'وسائل الدفع'}),
  _SettingsSection('printing', 'الطباعة', {'paper_size':'الورق','header_text':'الترويسة','footer_text':'التذييل'}),
  _SettingsSection('cms', 'إعداد CMS', {'site_title':'عنوان الموقع','default_locale':'اللغة','public_notice':'إعلان عام'}),
  _SettingsSection('backups', 'سياسة النسخ الاحتياطي', {'retention_days':'أيام الاحتفاظ','alert_email':'بريد التنبيه'}, superOnly: true),
  _SettingsSection('languages', 'اللغات', {'default_locale':'اللغة الأساسية','enabled_locales':'اللغات','timezone':'المنطقة الزمنية'}),
  _SettingsSection('currencies', 'العملات', {'base_currency':'العملة الأساسية','enabled_currencies':'العملات'}),
  _SettingsSection('extensions', 'الإضافات والوحدات', {'enabled_module_ids':'الوحدات','enabled_plugin_ids':'الإضافات'}, superOnly: true),
  _SettingsSection('custom_fields', 'الحقول المخصصة', {'student_form_schema':'نموذج الطالب','admissions_form_schema':'نموذج القبول'}),
  _SettingsSection('verification', 'التحقق', {'certificate_verification_enabled':'التحقق من الشهادات','guardian_check_required':'التحقق من ولي الأمر'}, superOnly: true),
  _SettingsSection('updates', 'التحديثات', {'release_channel':'قناة الإصدار','maintenance_notice':'إشعار الصيانة'}, superOnly: true),
];

class _LiveSystemSettingsScreenState extends State<LiveSystemSettingsScreen> {
  late Future<List<Map<String, dynamic>>> data;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  bool get admin => widget.roles.contains(Role.super_admin) || widget.roles.contains(Role.admin);
  bool get superAdmin => widget.roles.contains(Role.super_admin);

  void _reload() {
    data = Supabase.instance.client.from('sai_system_settings')
        .select('category,setting_key,value_text,updated_at')
        .order('category');
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save(_SettingsSection section, String key, String initial) async {
    final controller = TextEditingController(text: initial);
    try {
      final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(section.keys[key] ?? key),
          content: TextField(controller: controller, maxLength: 2000, maxLines: 3,
              decoration: const InputDecoration(helperText: 'لا تُدخل كلمات مرور أو مفاتيح اتصال سرية.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('حفظ')),
          ],
        ),
      );
      if (value == null || !mounted) return;
      const toggles = {
        'enabled','push_enabled','digest_enabled','registration_open',
        'certificate_verification_enabled','guardian_check_required',
      };
      if (toggles.contains(key) && value != 'true' && value != 'false') {
        _message('اكتب true أو false لهذه القيمة.');
        return;
      }
      final result = await Supabase.instance.client.from('sai_system_settings')
          .upsert({'category':section.id,'setting_key':key,'value_text':value},
              onConflict:'category,setting_key').select('setting_key');
      if (!mounted) return;
      if (result.isEmpty) {
        _message('لم تسمح صلاحيات قاعدة البيانات بالتعديل.');
        return;
      }
      setState(_reload);
      _message('تم الحفظ في Supabase بنجاح.');
    } on PostgrestException catch (e) {
      if (mounted) _message('رفض الخادم التغيير: ${e.message}');
    } catch (_) {
      if (mounted) _message('تعذر تحديث الإعداد؛ تحقق من الاتصال والصلاحيات.');
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!admin) {
      return const Center(child: Text('إعدادات النظام متاحة للإدارة فقط.'));
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: data,
      builder: (context,snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min,children:[
            const Text('تعذر تحميل إعدادات النظام من قاعدة البيانات.'),
            FilledButton(onPressed:()=>setState(_reload),child:const Text('إعادة المحاولة')),
          ]));
        }
        final rows = snapshot.data ?? const <Map<String,dynamic>>[];
        final values = <String,String>{
          for (final row in rows)
            '${row['category']}.${row['setting_key']}': (row['value_text'] ?? '').toString(),
        };
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Text('إعدادات Yemen SAI · قاعدة بيانات موحدة',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
          const SizedBox(height:8),
          const Text('الإعدادات غير السرية فقط. ضبط SMTP أو SMS أو WhatsApp لا يعني أن خدمة الإرسال مفعلة؛ يلزم تكامل خادم مستقل.'),
          const SizedBox(height:12),
          for (final section in _sections)
            if (!section.superOnly || superAdmin)
              ExpansionTile(title:Text(section.name),children: [
                for (final entry in section.keys.entries)
                  ListTile(
                    title:Text(entry.value),
                    subtitle:Text(values['${section.id}.${entry.key}']?.isNotEmpty == true
                      ? values['${section.id}.${entry.key}']! : 'غير مضبوط'),
                    trailing: superAdmin ? const Icon(Icons.edit_outlined) : const Icon(Icons.lock_outline),
                    onTap: superAdmin ? ()=>_save(section,entry.key,values['${section.id}.${entry.key}'] ?? '') : null,
                  ),
              ]),
          const SizedBox(height:20),
          const Text('إدارة المستخدمين والأدوار ونسخ البيانات الاحتياطية وحظر عناوين IP تحتاج إجراءات خادم مستقلة؛ لا يتم تنفيذها من حقول الإعدادات.'),
        ]);
      },
    );
  }
}
