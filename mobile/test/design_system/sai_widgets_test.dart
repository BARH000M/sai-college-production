import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_college_mobile/design_system/widgets/sai_section_card.dart';
import 'package:sai_college_mobile/design_system/widgets/sai_async_state.dart';

void main() {
  testWidgets('section card displays title and content', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body:
      SaiSectionCard(title: 'الصفوف', child: Text('المحتوى')))));
    expect(find.text('الصفوف'), findsOneWidget);
    expect(find.text('المحتوى'), findsOneWidget);
  });
  testWidgets('error state offers retry', (tester) async {
    var called = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      SaiAsyncState(loading: false, error: 'خطأ', onRetry: () { called = true; },
        child: const Text('data')))));
    await tester.tap(find.text('إعادة المحاولة'));
    expect(called, isTrue);
  });
}
