import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_school/auth/login_page.dart';
import 'package:sai_school/main.dart';

void main() {
  test('YSMS theme uses Cairo and the SAI burgundy and gold palette', () {
    final theme = ysmsTheme();
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Cairo');
    expect(theme.colorScheme.primary, ysmsJade);
    expect(theme.colorScheme.secondary, ysmsCinnabar);
    expect(theme.scaffoldBackgroundColor, ysmsPaper);
  });

  testWidgets('credential entry presents one authorized portal message',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ysmsTheme(),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: LoginPage(),
      ),
    ));
    expect(find.text('كلية ساي'), findsOneWidget);
    expect(find.text('سجّل الدخول لفتح بوابتك المصرح بها فقط.'), findsOneWidget);
    expect(find.text('دخول آمن'), findsOneWidget);
    expect(find.text('عرض حسابات المعاينة'), findsNothing);
  });
}
