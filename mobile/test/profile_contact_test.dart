import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sai_approved_mobile/core/access.dart';
import 'package:sai_approved_mobile/data/profile_repository.dart';
import 'package:sai_approved_mobile/ui/profile_screen.dart';

class FakeProfileRepository extends ProfileRepository {
  ContactProfile? profile = const ContactProfile(
    fullName: 'اسم أصلي',
    locale: 'ar',
  );
  bool failLoad = false, failSave = false;
  int saves = 0;
  Completer<void>? pending;
  @override
  Future<ContactProfile?> load() async {
    if (failLoad) throw Exception('offline');
    return profile;
  }

  @override
  Future<ContactProfile> save(String name, String phone, String locale) async {
    saves++;
    if (pending != null) await pending!.future;
    if (failSave) throw Exception('denied');
    profile = ContactProfile(
      fullName: name.trim(),
      phone: phone.trim(),
      locale: locale,
    );
    return profile!;
  }
}

Future<void> mount(WidgetTester tester, FakeProfileRepository repo) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProfileScreen(
          email: 'own@example.test',
          roleNames: const ['طالب'],
          repository: repo,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  final button = find.text('حفظ التغييرات');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  test('contact writes permit only three fields and reject invalid input', () {
    expect(ProfileRepository.validatedValues('  اسم جديد ', '', 'ar'), {
      'full_name': 'اسم جديد',
      'phone': null,
      'preferred_locale': 'ar',
    });
    for (final value in ['x', List.filled(121, '中').join(), 'Name\nInjected']) {
      expect(
        () => ProfileRepository.validatedValues(value, '', 'ar'),
        throwsFormatException,
      );
    }
    expect(
      () => ProfileRepository.validatedValues('اسم جديد', '+()---', 'ar'),
      throwsFormatException,
    );
    expect(
      () => ProfileRepository.validatedValues('اسم جديد', '', 'xx'),
      throwsFormatException,
    );
    for (final role in Role.values) {
      expect(Access.allows({role}, PageId.profile), isTrue);
    }
  });
  test(
    'repository scopes HTTP PATCH to authenticated identity and confirms returned row',
    () async {
      final calls = <http.Request>[];
      final client = SupabaseClient(
        'https://aeryusbrulqdxjdynwfh.supabase.co',
        'sb_publishable_test',
        httpClient: MockClient((request) async {
          calls.add(request);
          if (request.url.path.endsWith('/token')) {
            return http.Response(
              jsonEncode({
                'access_token': 'test-access',
                'token_type': 'bearer',
                'expires_in': 3600,
                'refresh_token': 'test-refresh',
                'user': {
                  'id': 'own',
                  'aud': 'authenticated',
                  'role': 'authenticated',
                  'email': 'own@example.test',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            jsonEncode({
              'full_name': 'اسم جديد',
              'phone': null,
              'preferred_locale': 'ar',
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      await client.auth.signInWithPassword(
        email: 'own@example.test',
        password: 'synthetic-test-only',
      );
      final repo = ProfileRepository(client: client);
      final profile = await repo.save('اسم جديد', '', 'ar');
      final patch = calls.singleWhere((r) => r.method == 'PATCH');
      expect(patch.url.queryParameters['id'], 'eq.own');
      expect(jsonDecode(patch.body), {
        'full_name': 'اسم جديد',
        'phone': null,
        'preferred_locale': 'ar',
      });
      expect(profile.fullName, 'اسم جديد');
      await client.dispose();
    },
  );
  testWidgets(
    'narrow and wide RTL profiles save and reload actual repository values',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 1000.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        final repo = FakeProfileRepository();
        await mount(tester, repo);
        expect(
          Directionality.of(tester.element(find.byType(ListView))),
          TextDirection.rtl,
        );
        await tester.enterText(find.byType(TextField).first, 'اسم جديد');
        await save(tester);
        expect(repo.saves, 1);
        expect(find.text('تم حفظ ملفك الشخصي.'), findsOneWidget);
        await tester.ensureVisible(find.text('إعادة تحميل البيانات'));
        await tester.tap(find.text('إعادة تحميل البيانات'));
        await tester.pumpAndSettle();
        expect(find.text('اسم جديد'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
  testWidgets(
    'load retry, missing profile and failed save preserve truthful states',
    (tester) async {
      final repo = FakeProfileRepository()..failLoad = true;
      await mount(tester, repo);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      repo.failLoad = false;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      repo.failSave = true;
      await tester.enterText(find.byType(TextField).first, 'اسم جديد');
      await save(tester);
      expect(find.text('تم حفظ ملفك الشخصي.'), findsNothing);
      expect(find.text('اسم جديد'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await mount(tester, FakeProfileRepository()..profile = null);
      expect(find.byType(TextField), findsNothing);
    },
  );
  testWidgets(
    'invalid names stay editable and pending saves prevent duplicate requests',
    (tester) async {
      final repo = FakeProfileRepository();
      await mount(tester, repo);
      await tester.enterText(find.byType(TextField).first, '');
      await save(tester);
      expect(repo.saves, 0);
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.enterText(find.byType(TextField).first, 'اسم جديد');
      repo.pending = Completer<void>();
      await tester.ensureVisible(find.text('حفظ التغييرات'));
      await tester.tap(find.text('حفظ التغييرات'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
      expect(repo.saves, 1);
      repo.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('تم حفظ ملفك الشخصي.'), findsOneWidget);
    },
  );
}
