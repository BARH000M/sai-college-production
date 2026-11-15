import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/ui/live_academic.dart';

void main() {
  testWidgets('finance displays the outstanding balance rather than the original fee', (tester) async {
    final pending = Completer<List<Map<String, dynamic>>>();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: LiveFinanceScreen(loader: () => pending.future),
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete([{
      'group_name': 'الرسوم', 'student_name': 'طالب', 'due_date': '2026-11-15',
      'status': 'partial', 'balance': 60,
    }]);
    await tester.pumpAndSettle();
    expect(find.textContaining('المتبقي: 60'), findsOneWidget);
    expect(find.textContaining('مدفوع جزئياً'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finance shows an error when loading fails', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: LiveFinanceScreen(loader: () async => throw StateError('unavailable')),
    )));
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحميل الرسوم المسموح بها لهذا الحساب.'), findsOneWidget);
  });
}
