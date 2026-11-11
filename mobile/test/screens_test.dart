import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/core/access.dart';
import 'package:sai_approved_mobile/data/demo_school.dart';
import 'package:sai_approved_mobile/data/demo_workspace.dart';
import 'package:sai_approved_mobile/main.dart';
import 'package:sai_approved_mobile/ui/learning_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [320.0, 390.0, 850.0]) {
    testWidgets('Preview login, four levels and a lesson fit at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final demo = DemoWorkspace(await SharedPreferences.getInstance());
      addTearDown(demo.dispose);
      await tester.pumpWidget(SaiApp(demo: demo));
      await tester.pumpAndSettle();
      expect(find.text('معاينة التطبيق'), findsOneWidget);
      await tester.tap(find.text('دخول المعاينة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('المقررات'));
      await tester.pumpAndSettle();
      expect(find.byType(LevelBadge), findsNWidgets(4));
      await tester.tap(find.text('المستوى الأساسي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ما اسمك؟'));
      await tester.pumpAndSettle();
      expect(find.text('我叫小明，你呢？'), findsOneWidget);
      expect(find.byTooltip('معاينة وطباعة'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Preview persists across a new app launch and clears on logout', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final first = DemoWorkspace(preferences);
    addTearDown(first.dispose);
    await tester.pumpWidget(SaiApp(demo: first));
    await tester.pumpAndSettle();
    await tester.tap(find.text('دخول المعاينة'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('تبديل حساب المعاينة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ولي الأمر'));
    await tester.pumpAndSettle();
    expect(first.role, Role.parent);
    await tester.pumpWidget(const SizedBox.shrink());

    final reopened = DemoWorkspace(preferences);
    addTearDown(reopened.dispose);
    await tester.pumpWidget(SaiApp(demo: reopened));
    await tester.pumpAndSettle();
    expect(find.text('معاينة التطبيق'), findsNothing);
    expect(find.textContaining('فيصل اليافعي'), findsOneWidget);
    expect(find.text('المقررات'), findsNothing);
    await tester.tap(find.byTooltip('القائمة'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('تسجيل الخروج'),
      160,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();
    expect(find.text('معاينة التطبيق'), findsOneWidget);
    expect(reopened.signedIn, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'Parent sees linked student only, and payment changes are shared across demo roles',
    () async {
      final demo = DemoWorkspace(await SharedPreferences.getInstance());
      addTearDown(demo.dispose);
      const parent = {Role.parent};
      const accountant = {Role.accountant};
      expect(
        DemoSchool.visibleStudents(
          DemoSchool.studentClass,
          parent,
        ).map((row) => row['id']),
        [DemoSchool.studentId],
      );
      final parentInvoices = DemoSchool.records(PageId.finance, parent, demo);
      expect(parentInvoices.map((row) => row.id), ['INV-007', 'INV-008']);
      final invoice = DemoSchool.records(
        PageId.finance,
        accountant,
        demo,
      ).first;
      expect(
        DemoSchool.action(PageId.finance, parent, DemoSchool.unpaid),
        isNull,
      );
      expect(
        DemoSchool.action(
          PageId.finance,
          accountant,
          DemoSchool.unpaid,
        )?.status,
        DemoSchool.paid,
      );
      await DemoSchool.update(demo, PageId.finance, invoice, DemoSchool.paid);
      expect(
        DemoSchool.status(demo, PageId.finance, parentInvoices.first),
        DemoSchool.paid,
      );
      expect(Access.allows({Role.admin}, PageId.users), isFalse);
      expect(Access.allows({Role.super_admin}, PageId.users), isTrue);
    },
  );
}
