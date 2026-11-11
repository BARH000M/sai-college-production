import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sai_college_mobile/features/academics/class_form_sheet.dart';
import 'package:sai_college_mobile/features/academics/class_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MemoryAuthStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async => null;

  @override
  Future<void> removeItem({required String key}) async {}

  @override
  Future<void> setItem({required String key, required String value}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<http.Request> requests;
  var failLookups = false;

  setUp(() async {
    requests = [];
    failLookups = false;
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-public-key',
      debug: false,
      accessToken: () async => null,
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _MemoryAuthStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (failLookups) {
          return http.Response('{"message":"lookup failed"}', 403,
              request: request, headers: {'content-type': 'application/json'});
        }
        final Object body;
        if (request.url.path.contains('/functions/')) {
          body = {
            'teachers': [
              {
                'userId': 'teacher-1',
                'fullName': 'Teacher One',
                'email': 'teacher@example.com'
              }
            ]
          };
        } else {
          final branch = request.url.path.endsWith('/branches');
          body = [
            {
              'id': branch ? 'branch-1' : 'session-1',
              'name': branch ? 'Branch One' : 'Session One',
              'is_active': true
            },
            {
              'id': branch ? 'branch-2' : 'session-2',
              'name': branch ? 'Branch Two' : 'Session Two',
              'is_active': true
            },
          ];
        }
        return http.Response(jsonEncode(body), 200,
            request: request, headers: {'content-type': 'application/json'});
      }),
    );
  });

  tearDown(() async => Supabase.instance.dispose());

  Future<void> openForm(WidgetTester tester, {SaiClass? existing}) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ClassFormSheet(existing: existing)),
      ));
      // PostgREST decodes responses in an isolate, outside the fake test clock.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    if (!failLookups) {
      expect(find.textContaining('تعذّر تحميل'), findsNothing,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .join('\n'));
    }
  }

  testWidgets('new class loads lookup and teacher options with defaults',
      (tester) async {
    await openForm(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Branch One'), findsOneWidget);
    expect(find.text('Session One'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
    final branch =
        requests.singleWhere((r) => r.url.path.endsWith('/branches'));
    expect(branch.url.queryParameters['is_active'], 'eq.true');
    expect(branch.url.queryParameters['order'], 'name.desc.nullslast');
    final session =
        requests.singleWhere((r) => r.url.path.endsWith('/academic_sessions'));
    expect(session.url.queryParameters['order'], 'starts_on.desc.nullslast');
    final teacher =
        requests.singleWhere((r) => r.url.path.contains('/functions/'));
    expect(jsonDecode(teacher.body), {'action': 'teacher-overview'});
  });

  testWidgets('editing preserves values and does not replace selected lookups',
      (tester) async {
    await openForm(tester,
        existing: const SaiClass(
          id: 'class-1',
          name: 'Existing Class',
          program: 'Existing Program',
          capacity: 30,
          enrolled: 5,
          isActive: false,
          branchId: 'branch-2',
          sessionId: 'session-2',
          teacherId: 'teacher-1',
          teacherName: 'Old Teacher Name',
        ));
    expect(tester.takeException(), isNull);
    expect(find.text('Existing Class'), findsOneWidget);
    expect(find.text('Existing Program'), findsOneWidget);
    expect(find.text('Branch Two'), findsOneWidget);
    expect(find.text('Session Two'), findsOneWidget);
    expect(find.text('Teacher One'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'Changed Class');
    await tester.pump();
    expect(find.text('Changed Class'), findsOneWidget);
  });

  testWidgets('failed lookups keep save disabled and display retry',
      (tester) async {
    failLookups = true;
    await openForm(tester);
    expect(tester.takeException(), isNull);
    expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull);
    expect(find.textContaining('lookup failed'), findsOneWidget);
  });
}
