import 'package:supabase_flutter/supabase_flutter.dart';

/// A failure carrying an Arabic message safe to show in the UI, plus a
/// log-safe detail string that never goes on screen.
final class AppException implements Exception {
  const AppException(this.message, {this.detail, this.code});

  /// Message shown to the user.
  final String message;

  /// Diagnostic detail for logging only.
  final String? detail;

  /// Database or platform code, when known (for example `42501`).
  final String? code;

  @override
  String toString() => detail == null ? message : '$message ($detail)';
}

const String _defaultMessage =
    'تعذّر إكمال العملية. تحقق من الاتصال وصلاحيات حسابك ثم أعد المحاولة.';

/// Translates an arbitrary thrown object into an [AppException].
///
/// Row level security rejections, unique violations and authentication
/// failures get a specific Arabic message; everything else falls back to a
/// generic one so no raw Postgres text reaches the user.
AppException mapSupabaseError(Object error, {String? fallback}) {
  if (error is AppException) return error;

  if (error is PostgrestException) {
    final message = error.message.toLowerCase();
    final code = error.code;

    if (code == '42501' || message.contains('row-level security')) {
      return AppException(
        'لا تملك صلاحية تنفيذ هذه العملية على هذه البيانات.',
        detail: error.message,
        code: code,
      );
    }
    if (code == '23505' || message.contains('duplicate key')) {
      return AppException(
        'هذا السجل موجود مسبقًا. راجع البيانات ثم أعد المحاولة.',
        detail: error.message,
        code: code,
      );
    }
    if (code == '23503' || message.contains('foreign key')) {
      return AppException(
        'لا يمكن إتمام العملية لارتباط هذا السجل بسجلات أخرى.',
        detail: error.message,
        code: code,
      );
    }
    if (code == '23502' || message.contains('null value')) {
      return AppException(
        'هناك حقل مطلوب لم يُعبأ. أكمل الحقول ثم أعد المحاولة.',
        detail: error.message,
        code: code,
      );
    }
    return AppException(fallback ?? _defaultMessage, detail: error.message, code: code);
  }

  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return AppException('البريد الإلكتروني أو كلمة المرور غير صحيحة.',
          detail: error.message);
    }
    if (message.contains('email not confirmed')) {
      return AppException('أكّد بريدك الإلكتروني أولًا أو تواصل مع إدارة الكلية.',
          detail: error.message);
    }
    return AppException('تعذّر إكمال عملية الحساب. حاول مجددًا.', detail: error.message);
  }

  return AppException(fallback ?? _defaultMessage, detail: error.toString());
}