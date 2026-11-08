import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase.dart';
import 'recovery_flow.dart';

const String resetPasswordRedirect =
    String.fromEnvironment('RESET_REDIRECT_URL');

class SupabaseRecoveryGateway implements RecoveryGateway {
  const SupabaseRecoveryGateway();

  @override
  Future<void> requestCode(String email) async {
    try {
      await db.auth.resetPasswordForEmail(email,
          redirectTo:
              resetPasswordRedirect.isEmpty ? null : resetPasswordRedirect);
    } on AuthException catch (e) {
      throw RecoveryRejected(_read(e));
    } catch (_) {
      throw const RecoveryRejected(
          'تعذّر إرسال البريد. تحقق من الاتصال ثم أعد المحاولة.');
    }
  }

  @override
  Future<void> verifyCode(
      {required String email, required String token}) async {
    try {
      final res = await db.auth
          .verifyOTP(email: email, token: token, type: OtpType.recovery);
      if (res.session == null) {
        throw const RecoveryRejected(
            'الرمز غير صالح أو انتهت صلاحيته — اطلب رمزاً جديداً.');
      }
    } on AuthException catch (e) {
      throw RecoveryRejected(_read(e));
    } on RecoveryRejected {
      rethrow;
    } catch (_) {
      throw const RecoveryRejected(
          'تعذّر التحقق من الرمز. تحقق من الاتصال ثم أعد المحاولة.');
    }
  }

  @override
  Future<void> setPassword(String password) async {
    try {
      final res = await db.auth.updateUser(UserAttributes(password: password));
      if (res.user == null) {
        throw const RecoveryRejected(
            'لم يُحفظ كلمة المرور. أعد المحاولة أو اطلب رمزاً جديداً.');
      }
    } on AuthException catch (e) {
      throw RecoveryRejected(_read(e));
    } on RecoveryRejected {
      rethrow;
    } catch (_) {
      throw const RecoveryRejected(
          'تعذّر حفظ كلمة المرور. تحقق من الاتصال ثم أعد المحاولة.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await db.auth.signOut();
    } catch (_) {
      try {
        await db.auth.signOut();
      } catch (_) {}
    }
    if (db.auth.currentSession != null) {
      throw const RecoveryRejected(
          'تم تغيير كلمة المرور، لكن تعذّر إنهاء الجلسة على هذا الجهاز. أعد المحاولة الآن.');
    }
  }

  String _read(AuthException e) {
    final text = e.message.toLowerCase();
    if (text.contains('expired') || text.contains('invalid')) {
      return 'الرمز غير صالح أو انتهت صلاحيته — اطلب رمزاً جديداً.';
    }
    if (text.contains('rate limit') || text.contains('too many')) {
      return 'طلبات كثيرة على هذا البريد. انتظر دقيقة ثم أعد المحاولة.';
    }
    if (text.contains('same password') ||
        text.contains('different from the old')) {
      return 'كلمة المرور الجديدة يجب أن تختلف عن القديمة.';
    }
    if (text.contains('weak') || text.contains('at least')) {
      return 'كلمة المرور ضعيفة — استخدم $recoveryMinPasswordLength أحرف أو أكثر.';
    }
    return e.message;
  }
}
