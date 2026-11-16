import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/core/access.dart';
import 'package:sai_approved_mobile/data/admissions_repository.dart';
import 'package:sai_approved_mobile/ui/live_admissions.dart';

class _FakeAdmissionsRepository implements AdmissionsData {
  String currentStatus = 'new';
  String? savedStatus;
  String? enrolledId;
  String? linkedUserId;
  List<Map<String, dynamic>> linkableAccounts = [];

  @override
  Future<List<Map<String, dynamic>>> loadBranches() async => [
    {'id': 'branch-1', 'name': 'الفرع الرئيسي'},
  ];

  @override
  Future<List<Map<String, dynamic>>> loadEnquiries({
    required String branchId,
    required int offset,
    String? status,
  }) async => status != null && status != currentStatus
      ? []
      : [
          {
            'id': 'enquiry-1',
            'application_no': 'SAI-APP-1042',
            'applicant_full_name': 'Applicant One',
            'guardian_name': 'Guardian One',
            'phone': '777123456',
            'email': 'applicant@example.test',
            'preferred_program': 'Chinese',
            'preferred_level': 'Beginner',
            'notes': 'Please call',
            'status': currentStatus,
            'created_at': '2026-11-14T08:00:00Z',
          },
        ];

  @override
  Future<void> updateStatus(String enquiryId, String status) async {
    savedStatus = status;
    currentStatus = status;
  }

  @override
  Future<Map<String, dynamic>> enroll(String enquiryId) async {
    enrolledId = enquiryId;
    currentStatus = 'enrolled';
    return {'student_id': 'student-1', 'admission_no': 'SAI-APP-1042'};
  }

  @override
  Future<List<Map<String, dynamic>>> loadLinkableAccounts() async =>
      linkableAccounts;

  @override
  Future<void> linkStudentAccount(String studentId, String userId) async {
    linkedUserId = userId;
  }
}

void main() {
  testWidgets('live admissions screen fits narrow and wide layouts', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [320.0, 850.0]) {
      final repository = _FakeAdmissionsRepository();
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: Scaffold(
            body: LiveAdmissionsScreen(
              roles: {Role.receptionist},
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Applicant One'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('enrollment requires acceptance and uses the conversion action', (
    tester,
  ) async {
    final repository = _FakeAdmissionsRepository();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Scaffold(
          body: LiveAdmissionsScreen(
            roles: {Role.admin},
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('تحديث الحالة'));
    await tester.pumpAndSettle();
    expect(find.byType(SimpleDialog), findsOneWidget);
    expect(find.text('مقبول'), findsOneWidget);
    expect(find.text('مسجل'), findsNothing);

    await tester.tap(find.text('مقبول'));
    await tester.pumpAndSettle();
    expect(repository.savedStatus, 'accepted');
    expect(find.text('إنشاء سجل طالب'), findsOneWidget);

    await tester.tap(find.text('إنشاء سجل طالب'));
    await tester.pumpAndSettle();
    expect(find.text('تأكيد التسجيل'), findsOneWidget);
    await tester.tap(find.text('تأكيد التسجيل'));
    await tester.pumpAndSettle();
    expect(repository.enrolledId, 'enquiry-1');
    expect(find.textContaining('مسجل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enrollment can link an existing account without creating one', (
    tester,
  ) async {
    final repository = _FakeAdmissionsRepository()
      ..linkableAccounts = [
        {
          'id': 'user-1',
          'fullName': 'Student Account',
          'email': 'student@example.test',
          'roles': ['student'],
          'linkedStudentId': null,
        },
      ];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Scaffold(
          body: LiveAdmissionsScreen(
            roles: {Role.admin},
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('تحديث الحالة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مقبول'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إنشاء سجل طالب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد التسجيل'));
    await tester.pumpAndSettle();

    expect(find.text('ربط حساب قائم'), findsOneWidget);
    expect(find.text('student@example.test'), findsOneWidget);
    await tester.tap(find.text('student@example.test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ربط الحساب المحدد'));
    await tester.pumpAndSettle();

    expect(repository.enrolledId, 'enquiry-1');
    expect(repository.linkedUserId, 'user-1');
    expect(tester.takeException(), isNull);
  });
}
