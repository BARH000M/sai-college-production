/// Shared interface strings.
///
/// The application ships Arabic first. These constants cover text repeated
/// across screens so a wording change lands in one place; screen-specific copy
/// still lives with its screen until the localization layer is introduced.
abstract final class AppStrings {
  static const String appNameAr = 'كلية ساي التعليمية اليمنية الصينية';
  static const String appNameZh = '世门赛艾教育学院';

  static const String retry = 'إعادة المحاولة';
  static const String cancel = 'إلغاء';
  static const String confirm = 'تأكيد';
  static const String save = 'حفظ';
  static const String close = 'إغلاق';
  static const String search = 'بحث';
  static const String busy = 'جارٍ...';
  static const String loading = 'جارٍ التحميل...';
  static const String noData = 'لا توجد بيانات';
  static const String signOut = 'تسجيل الخروج';

  static const String loadFailedTitle = 'تعذّر تحميل البيانات';
  static const String permissionDenied = 'لا تملك صلاحية تنفيذ هذه العملية.';
}