import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_school/auth/recovery_flow.dart';
import 'package:sai_school/auth/recovery_page.dart';

class _Recorder implements RecoveryGateway {
  final List<String> calls = <String>[];
  bool rejectVerification = false;
  bool rejectSignOut = false;
  int passwordWrites = 0;
  @override
  Future<void> requestCode(String email) async => calls.add('request');
  @override
  Future<void> verifyCode(
      {required String email, required String token}) async {
    if (rejectVerification) throw const RecoveryRejected('الرمز غير صحيح');
    calls.add('verify');
  }

  @override
  Future<void> setPassword(String password) async {
    passwordWrites += 1;
    calls.add('password');
  }

  @override
  Future<void> signOut() async {
    if (rejectSignOut) {
      throw const RecoveryRejected('تعذّر إنهاء الجلسة على هذا الجهاز');
    }
    calls.add('signout');
  }
}

final Finder _passwordLabel = find.text('كلمة المرور الجديدة');
final Finder _confirmLabel = find.text('تأكيد كلمة المرور');
final Finder _saveButton = find.text('حفظ كلمة المرور');

Future<RecoveryFlow> _pumpPage(WidgetTester tester, _Recorder gateway) async {
  final flow = RecoveryFlow(gateway: gateway, resendCooldown: Duration.zero);
  await tester.pumpWidget(MaterialApp(home: RecoveryPage(flow: flow)));
  await tester.pump();
  return flow;
}

Future<void> _sendCode(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'user@sai-college.com');
  await tester.tap(find.text('إرسال الرمز'));
  await tester.pump();
  await tester.pump();
}

Future<void> _enterCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.tap(find.text('تحقق من الرمز'));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('recovery screen never renders the password step early', () {
    testWidgets('on arrival there is no password field at all', (tester) async {
      await _pumpPage(tester, _Recorder());
      expect(_passwordLabel, findsNothing);
      expect(_confirmLabel, findsNothing);
      expect(_saveButton, findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });
    testWidgets(
        'sending a code moves to the code step, still no password field',
        (tester) async {
      final gateway = _Recorder();
      await _pumpPage(tester, gateway);
      await _sendCode(tester);
      expect(find.text('تحقق من الرمز'), findsOneWidget);
      expect(_passwordLabel, findsNothing);
      expect(_confirmLabel, findsNothing);
      expect(_saveButton, findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });
    testWidgets(
        'a rejected code shows an error and keeps the password step hidden',
        (tester) async {
      final gateway = _Recorder();
      await _pumpPage(tester, gateway);
      await _sendCode(tester);
      gateway.rejectVerification = true;
      await _enterCode(tester, '000000');
      expect(find.text('الرمز غير صحيح'), findsOneWidget);
      expect(_passwordLabel, findsNothing);
      expect(_saveButton, findsNothing);
      expect(gateway.passwordWrites, 0);
      expect(gateway.calls, <String>['request']);
      expect(find.text('تحقق من الرمز'), findsOneWidget);
    });
    testWidgets(
        'the password step appears only after a successful verification',
        (tester) async {
      final gateway = _Recorder();
      await _pumpPage(tester, gateway);
      await _sendCode(tester);
      expect(_passwordLabel, findsNothing);
      await _enterCode(tester, '123456');
      expect(_passwordLabel, findsOneWidget);
      expect(_confirmLabel, findsOneWidget);
      expect(_saveButton, findsOneWidget);
      expect(gateway.calls, <String>['request', 'verify']);
    });
    testWidgets('the save button writes nothing until the two fields match',
        (tester) async {
      final gateway = _Recorder();
      await _pumpPage(tester, gateway);
      await _sendCode(tester);
      await _enterCode(tester, '123456');
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), 'LongEnough#1');
      await tester.enterText(fields.at(1), 'Different#2');
      await tester.tap(_saveButton);
      await tester.pump();
      await tester.pump();
      expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
      expect(gateway.passwordWrites, 0);
      expect(_passwordLabel, findsOneWidget);
    });
    testWidgets('a successful save records exactly one password write',
        (tester) async {
      final gateway = _Recorder();
      await _pumpPage(tester, gateway);
      await _sendCode(tester);
      await _enterCode(tester, '123456');
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'LongEnough#1');
      await tester.enterText(fields.at(1), 'LongEnough#1');
      await tester.tap(_saveButton);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(
          gateway.calls, <String>['request', 'verify', 'password', 'signout']);
      expect(gateway.passwordWrites, 1);
      expect(find.text('تم تحديث كلمة المرور'), findsOneWidget);
    });
    testWidgets('a failed sign-out shows a retry, never the done screen',
        (tester) async {
      final gateway = _Recorder()..rejectSignOut = true;
      await _pumpPage(tester, gateway);
      await _sendCode(tester);
      await _enterCode(tester, '123456');
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'LongEnough#1');
      await tester.enterText(fields.at(1), 'LongEnough#1');
      await tester.tap(_saveButton);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(gateway.passwordWrites, 1);
      expect(find.text('تم تحديث كلمة المرور'), findsNothing);
      expect(find.text('إنهاء الجلسة الآن'), findsOneWidget);
      gateway.rejectSignOut = false;
      await tester.tap(find.text('إنهاء الجلسة الآن'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(gateway.passwordWrites, 1);
      expect(
          gateway.calls, <String>['request', 'verify', 'password', 'signout']);
      expect(find.text('تم تحديث كلمة المرور'), findsOneWidget);
    });
  });
}
