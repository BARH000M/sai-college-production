import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/core/access.dart';
import 'package:sai_approved_mobile/data/admissions_repository.dart';
import 'package:sai_approved_mobile/ui/live_admissions.dart';

class _FakeAdmissionsRepository implements AdmissionsData {
  String currentStatus = 'new';
  String? savedStatus;
  String? enrolledId;

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
}
