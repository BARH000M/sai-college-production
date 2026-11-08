import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_school/features/shared/data_state.dart';

void main() {
  testWidgets('API failures remain visible instead of becoming zeros',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: DataStateView(
          loading: false,
          error: 'فشل الاتصال بالخادم',
          onRetry: () async {
            retries++;
          },
          child: const Text('0'),
        ),
      ),
    ));
    expect(find.text('فشل الاتصال بالخادم'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(tester.getTopLeft(find.byType(DataStateView)).dx, isNotNull);
    await tester.tap(find.text('إعادة المحاولة'));
    expect(retries, 1);
  });

  testWidgets('loading does not reveal stale content', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: DataStateView(
            loading: true,
            error: null,
            onRetry: () async {},
            child: const Text('بيانات قديمة'))));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('بيانات قديمة'), findsNothing);
  });
}
