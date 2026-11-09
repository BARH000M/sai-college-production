import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_college_mobile/design_system/design_system.dart';

Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('SaiSearchField shows its hint and reports typed text', (tester) async {
    String? typed;
    await tester.pumpWidget(
      host(SaiSearchField(hintText: 'ابحث عن صف', onChanged: (value) => typed = value)),
    );

    expect(find.text('ابحث عن صف'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'HSK 2');
    expect(typed, 'HSK 2');
  });

  testWidgets('SaiFilterChips renders counts and emits the tapped value', (tester) async {
    String? selected;
    await tester.pumpWidget(
      host(
        SaiFilterChips(
          selectedValue: 'all',
          onSelected: (value) => selected = value,
          options: const [
            SaiFilterOption(value: 'all', label: 'الكل', count: 9),
            SaiFilterOption(value: 'open', label: 'مفتوح', count: 3),
          ],
        ),
      ),
    );

    expect(find.text('الكل'), findsOneWidget);
    expect(find.text('مفتوح'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('مفتوح'));
    await tester.pump();

    expect(selected, 'open');
  });

  testWidgets('SaiCard renders content and handles taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(SaiCard(onTap: () => taps += 1, child: const Text('بطاقة'))),
    );

    expect(find.text('بطاقة'), findsOneWidget);

    await tester.tap(find.text('بطاقة'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('SaiCard without onTap is not tappable', (tester) async {
    await tester.pumpWidget(host(const SaiCard(child: Text('ثابت'))));

    expect(
      find.descendant(of: find.byType(SaiCard), matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(find.text('ثابت'), findsOneWidget);
  });

  testWidgets('SaiStatStrip shows every figure and label', (tester) async {
    await tester.pumpWidget(
      host(
        const SaiStatStrip(
          items: [
            SaiStatItem(label: 'الصفوف', value: '12'),
            SaiStatItem(label: 'الطلاب', value: '240'),
          ],
        ),
      ),
    );

    expect(find.text('الصفوف'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('الطلاب'), findsOneWidget);
    expect(find.text('240'), findsOneWidget);
  });

  testWidgets('SaiDetailRow shows both label and value', (tester) async {
    await tester.pumpWidget(
      host(const SaiDetailRow(label: 'الفرع', value: 'الفرع الرئيسي')),
    );

    expect(find.text('الفرع'), findsOneWidget);
    expect(find.text('الفرع الرئيسي'), findsOneWidget);
  });

  testWidgets('SaiBottomActionBar swaps to the busy label and blocks taps', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      host(
        SaiBottomActionBar(
          primaryLabel: 'حفظ',
          onPrimary: () => pressed += 1,
          busy: true,
        ),
      ),
    );

    expect(find.text('جارٍ...'), findsOneWidget);
    expect(find.text('حفظ'), findsNothing);

    await tester.tap(find.text('جارٍ...'), warnIfMissed: false);
    await tester.pump();

    expect(pressed, 0);
  });

  testWidgets('SaiBottomActionBar runs the primary action when idle', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      host(
        SaiBottomActionBar(
          primaryLabel: 'حفظ',
          onPrimary: () => pressed += 1,
          secondaryLabel: 'إلغاء',
          onSecondary: () {},
        ),
      ),
    );

    expect(find.text('إلغاء'), findsOneWidget);

    await tester.tap(find.text('حفظ'));
    await tester.pump();

    expect(pressed, 1);
  });

  testWidgets('SaiSectionTitle renders its title and trailing widget', (tester) async {
    await tester.pumpWidget(
      host(
        const SaiSectionTitle(
          title: 'عمليات سريعة',
          trailing: Icon(Icons.add),
        ),
      ),
    );

    expect(find.text('عمليات سريعة'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('SaiPageBody lays out its children', (tester) async {
    await tester.pumpWidget(
      host(
        const SizedBox(
          height: 300,
          child: SaiPageBody(
            children: [Text('السطر الأول'), Text('السطر الثاني')],
          ),
        ),
      ),
    );

    expect(find.text('السطر الأول'), findsOneWidget);
    expect(find.text('السطر الثاني'), findsOneWidget);
  });
}