import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/ui/live_academic.dart';
import 'package:sai_approved_mobile/ui/printing.dart';

void main() {
  testWidgets('printed finance statement identifies invoices and distinguishes cancelled fees', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LiveFinanceScreen(loader: () async => [
      {'id': 'invoice-a', 'student_name': 'Ali', 'admission_no': 'SAI-1', 'group_name': 'Tuition', 'due_date': '2099-01-01', 'status': 'partial', 'balance': 20},
      {'id': 'invoice-b', 'student_name': 'Sara', 'admission_no': 'SAI-2', 'group_name': 'Tuition', 'due_date': '2099-01-01', 'status': 'cancelled', 'balance': 0},
    ]))));
    await tester.pumpAndSettle();
    final report = tester.widget<PrintAction>(find.byType(PrintAction)).report;
    expect(report.columns.map((column) => column.title), contains('الحالة'));
    expect(report.rows[0][0], contains('invoice-a'));
    expect(report.rows[0][0], contains('SAI-1'));
    expect(report.rows[0][3], 'مدفوع جزئياً');
    expect(report.rows[1][3], 'ملغى');
    expect(report.subtitle, contains('المستحق: 20.00'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'finance search and overdue filters update the printed balance scope',
    (tester) async {
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 2))
          .toIso8601String()
          .split('T')
          .first;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveFinanceScreen(
              loader: () async => [
                {
                  'group_name': 'Tuition',
                  'student_name': 'Ali',
                  'admission_no': 'SAI-123',
                  'class_id': 'class-a',
                  'due_date': yesterday,
                  'status': 'partial',
                  'balance': 60.01,
                },
                {
                  'group_name': 'Tuition',
                  'student_name': 'Sara',
                  'admission_no': 'SAI-456',
                  'class_id': 'class-b',
                  'due_date': '2099-01-01',
                  'status': 'unpaid',
                  'balance': 20,
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('المستحق: 80.01'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'SAI-123');
      await tester.pumpAndSettle();
      expect(find.textContaining('المستحق: 60.01'), findsOneWidget);
      expect(find.textContaining('Sara'), findsNothing);
      expect(find.textContaining('Ali'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'finance displays the outstanding balance rather than the original fee',
    (tester) async {
      final pending = Completer<List<Map<String, dynamic>>>();
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LiveFinanceScreen(loader: () => pending.future)),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete([
        {
          'group_name': 'الرسوم',
          'student_name': 'طالب',
          'due_date': '2026-11-15',
          'status': 'partial',
          'balance': 60,
        },
      ]);
      await tester.pumpAndSettle();
      expect(find.textContaining('المتبقي: 60'), findsOneWidget);
      expect(find.textContaining('مدفوع جزئياً'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('finance shows an error when loading fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveFinanceScreen(
            loader: () async => throw StateError('unavailable'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('تعذر تحميل الرسوم المسموح بها لهذا الحساب.'),
      findsOneWidget,
    );
  });
}
