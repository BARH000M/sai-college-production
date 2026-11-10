import '../core/access.dart';

/// This registry is shared by the navigation, online listings and permissions.
/// Only the modules with a [table] read from Supabase.  Existing server tables
/// remain authoritative; this client never creates shadow/local copies.
class ModuleField {
  const ModuleField(this.key, this.label, {this.numeric = false});
  final String key;
  final String label;
  final bool numeric;
}

class ModuleSpec {
  const ModuleSpec({
    required this.page,
    required this.table,
    required this.title,
    this.subtitle = '',
    this.writable = false,
    this.fields = const [],
  });
  final PageId page;
  final String table;
  final String title;
  final String subtitle;
  /// This only enables client controls. All actual permissions are server RLS.
  final bool writable;
  final List<ModuleField> fields;
}

const onlineModules = <PageId, ModuleSpec>{
  PageId.assignments: ModuleSpec(
    page: PageId.assignments,
    table: 'learning_homework',
    title: 'الواجبات المنزلية',
    subtitle: 'الواجبات المنشورة والمواعيد، من قاعدة بيانات الكلية',
  ),
  PageId.library: ModuleSpec(
    page: PageId.library,
    table: 'library_items',
    title: 'المكتبة والإعارة',
    subtitle: 'فهرس الكتب ومخزون النسخ المتاحة',
  ),
  PageId.content: ModuleSpec(
    page: PageId.content,
    table: 'learning_lessons',
    title: 'محتوى الدروس',
    subtitle: 'سجلات الدروس المنشورة من النظام نفسه',
  ),
  PageId.notifications: ModuleSpec(
    page: PageId.notifications,
    table: 'announcements',
    title: 'إعلانات الكلية',
    subtitle: 'الإعلانات التي تسمح لك صلاحيات الخادم بعرضها',
  ),
  PageId.downloads: ModuleSpec(
    page: PageId.downloads,
    table: 'sai_download_resources',
    title: 'مركز التحميل',
    subtitle: 'الملفات والموارد التعليمية والإدارية',
    writable: true,
    fields: [ModuleField('category', 'التصنيف'), ModuleField('storage_path', 'مسار الملف في التخزين الآمن')],
  ),
  PageId.inventory: ModuleSpec(
    page: PageId.inventory,
    table: 'sai_inventory_items',
    title: 'المخزون',
    subtitle: 'الأصناف والكميات وأكواد المستودعات',
    writable: true,
    fields: [ModuleField('sku', 'رمز الصنف'), ModuleField('quantity', 'الكمية', numeric: true), ModuleField('warehouse', 'المخزن')],
  ),
  PageId.transport: ModuleSpec(
    page: PageId.transport,
    table: 'sai_transport_routes',
    title: 'النقل',
    subtitle: 'المركبات والخطوط والسعة',
    writable: true,
    fields: [ModuleField('vehicle', 'المركبة'), ModuleField('capacity', 'السعة', numeric: true), ModuleField('driver_name', 'السائق')],
  ),
  PageId.portfolio: ModuleSpec(
    page: PageId.portfolio,
    table: 'sai_student_portfolios',
    title: 'ملف إنجاز الطالب',
    subtitle: 'الإنجازات والملفات التابعة للطالب',
    writable: true,
    fields: [ModuleField('student_id', 'معرّف الطالب UUID'), ModuleField('category', 'نوع الإنجاز')],
  ),
  PageId.housing: ModuleSpec(
    page: PageId.housing,
    table: 'sai_housing_rooms',
    title: 'السكن الطلابي',
    subtitle: 'المباني والغرف والطاقة الاستيعابية',
    writable: true,
    fields: [ModuleField('building', 'المبنى'), ModuleField('capacity', 'السعة', numeric: true)],
  ),
  PageId.certificates: ModuleSpec(
    page: PageId.certificates,
    table: 'sai_certificates',
    title: 'الشهادات',
    subtitle: 'مسودات وسجلات الشهادات الصادرة',
    writable: true,
    fields: [ModuleField('student_id', 'معرّف الطالب UUID'), ModuleField('serial_code', 'الرقم التسلسلي')],
  ),
  PageId.frontCms: ModuleSpec(
    page: PageId.frontCms,
    table: 'sai_cms_pages',
    title: 'Front CMS',
    subtitle: 'صفحات ومحتوى الموقع العام',
    writable: true,
    fields: [ModuleField('slug', 'الرابط المختصر'), ModuleField('body', 'المحتوى')],
  ),
  PageId.alumni: ModuleSpec(
    page: PageId.alumni,
    table: 'sai_alumni',
    title: 'الخريجون',
    subtitle: 'السجلات والملاحظات وسنة التخرج',
    writable: true,
    fields: [ModuleField('student_id', 'معرّف الطالب UUID'), ModuleField('graduation_year', 'سنة التخرج', numeric: true)],
  ),
};
