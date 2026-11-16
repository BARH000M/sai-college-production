import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/ui/live_academic.dart';

void main() {
  testWidgets('personal attendance shows loading and records on narrow screens', (tester) async {
    final pending = Completer<List<Map<String, dynamic>>>();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LiveAttendanceScreen(personalOnly: true, loader: () => pending.future)),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete([
      {'student_name': 'طالب', 'attendance_date': '2026-11-14', 'status': 'present', 'note': 'ملاحظة'},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('طالب'), findsOneWidget);
    expect(find.textContaining('حاضر'), findsOneWidget);
    expect(find.textContaining('ملاحظة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('attendance distinguishes empty and failed requests', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LiveAttendanceScreen(loader: () async => [])),
    ));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد سجلات حضور مرئية لهذا الحساب حتى الآن.'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LiveAttendanceScreen(
        key: const ValueKey('error'),
        loader: () async => throw StateError('unavailable'),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحميل سجلات الحضور. تحقق من اتصال الحساب وصلاحياته.'), findsOneWidget);
  });
}
