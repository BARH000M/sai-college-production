import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sai_approved_mobile/core/access.dart';
import 'package:sai_approved_mobile/data/finance_repository.dart';
import 'package:sai_approved_mobile/ui/finance_detail.dart';

class Ledger extends FinanceRepository {
  Ledger() : super(SupabaseClient('http://localhost', 'test', authOptions: const AuthClientOptions(autoRefreshToken: false)));
  num balance = 60;
  bool available = true;
  final adjustments = <String>[];
  Map<String, dynamic>? savedRefund;
  String? refundedPayment;
  @override
  Future<Map<String, dynamic>?> pending() async => null;
  @override
  Future<Map<String, dynamic>?> pendingRefund() async => savedRefund;
  @override
  Future<String> refund(String payment, String amount, String method, String reference, String reason) async {
    refundedPayment = payment;
    savedRefund = null;
    return 'refund-id';
  }
  @override
  Future<List<Map<String, dynamic>>> rows(String name, [Map<String, dynamic>? params]) async =>
      name == 'sai_finance_assignments'
          ? (available ? [{'id': 'invoice', 'balance': balance, 'status': 'partial'}] : [])
          : [];
  @override
  Future<void> adjust(String action, String id, String reason) async {
    adjustments.add(action);
    balance = 0;
  }
}

void main() {
  Future<void> open(WidgetTester tester, Ledger ledger, Set<Role> roles) async {
    await tester.pumpWidget(MaterialApp(home: FinanceDetail(
      repository: ledger, roles: roles,
      assignment: const {'id': 'invoice', 'balance': 100, 'status': 'unpaid',
        'student_name': 'طالب', 'group_name': 'رسوم', 'final_amount': 100},
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('invoice refresh replaces opening balance and fails closed if access is lost', (tester) async {
    final ledger = Ledger();
    await open(tester, ledger, {Role.student});
    expect(find.textContaining('الرصيد الحالي: 60'), findsOneWidget);
    expect(find.text('إعفاء الرصيد'), findsNothing);
    expect(find.text('تسجيل الدفعة'), findsNothing);
    ledger.balance = 20;
    await tester.tap(find.text('تحديث السجل'));
    await tester.pumpAndSettle();
    expect(find.textContaining('الرصيد الحالي: 20'), findsOneWidget);
    ledger.available = false;
    await tester.tap(find.text('تحديث السجل'));
    await tester.pumpAndSettle();
    expect(find.textContaining('الفاتورة لم تعد متاحة'), findsOneWidget);
    expect(find.textContaining('الرصيد الحالي:'), findsNothing);
  });

  testWidgets('accountant waiver refreshes the invoice while admin has no waiver', (tester) async {
    final ledger = Ledger();
    await open(tester, ledger, {Role.admin});
    expect(find.text('إعفاء الرصيد'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await open(tester, ledger, {Role.accountant});
    await tester.ensureVisible(find.text('إعفاء الرصيد'));
    await tester.tap(find.text('إعفاء الرصيد'));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'إعفاء معتمد');
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(ledger.adjustments, ['waive']);
    await tester.ensureVisible(find.textContaining('الرصيد الحالي: 0'));
    expect(find.textContaining('الرصيد الحالي: 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved refund blocks payment and super admin can recover a payment from another invoice', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ledger = Ledger()..savedRefund = {'wanted_payment': 'other-payment'};
    await open(tester, ledger, {Role.super_admin});
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'تسجيل الدفعة')).onPressed, isNull);
    await tester.ensureVisible(find.text('إعادة محاولة الاسترداد'));
    await tester.tap(find.text('إعادة محاولة الاسترداد'));
    await tester.pumpAndSettle();
    expect(ledger.refundedPayment, 'other-payment');
    expect(find.text('إعادة محاولة الاسترداد'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
