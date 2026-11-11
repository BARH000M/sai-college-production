import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/core/access.dart';
import 'package:sai_approved_mobile/data/repository.dart';
import 'package:sai_approved_mobile/ui/components.dart';
import 'package:sai_approved_mobile/ui/screens.dart';

Widget host(Widget child) => MaterialApp(
  theme: saiTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);
void main() {
  for (final width in [320.0, 390.0, 850.0]) {
    testWidgets('Login and dashboard fit width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(host(LoginScreen(onPreview: () {})));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        host(
          CollegeShell(
            account: Account('خالد فيصل', {Role.super_admin}, ''),
            onSignOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('المقررات والدروس').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Class roster and lesson preview render', (tester) async {
    await tester.pumpWidget(
      host(
        const RosterScreen(
          row: {
            'id': 'demo',
            'name': 'Grade 10 - B',
            'program': 'Chinese',
            'capacity': 28,
          },
          preview: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('خالد فيصل اليافعي'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      host(const Scaffold(body: LessonScreen(preview: true))),
    );
    await tester.pumpAndSettle();
    expect(find.text('介绍我的家人'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
