import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

ApiException _wrap(Object e) {
  if (e is PostgrestException) {
    final cleaned = e.message.replaceFirst(RegExp(r'^PT\d+:\s*'), '');
    return ApiException(cleaned, code: e.code);
  }
  if (e is ApiException) return e;
  return ApiException(
      'تعذّر الوصول إلى الخادم. تحقق من الاتصال وأعد المحاولة.');
}

class FeePayment {
  const FeePayment(
      {required this.id,
      required this.studentId,
      required this.studentName,
      required this.amount,
      required this.paidOn,
      required this.financeEntryId});
  final int id;
  final int studentId;
  final String studentName;
  final double amount;
  final String paidOn;
  final int? financeEntryId;
  bool get posted => financeEntryId != null;
  factory FeePayment.fromRow(Map<String, dynamic> row) {
    final student = row['school_students'];
    final name = student is Map<String, dynamic>
        ? (student['full_name'] as String?)
        : null;
    return FeePayment(
      id: (row['id'] as num).toInt(),
      studentId: (row['student_id'] as num).toInt(),
      studentName: name ?? 'طالب #${row['student_id']}',
      amount: (row['amount'] as num).toDouble(),
      paidOn: row['paid_on'] as String,
      financeEntryId: (row['finance_entry_id'] as num?)?.toInt(),
    );
  }
}

class FinanceAccount {
  const FinanceAccount(
      {required this.id,
      required this.name,
      required this.currency,
      required this.active});
  final int id;
  final String name;
  final String currency;
  final bool active;
  factory FinanceAccount.fromRow(Map<String, dynamic> row) => FinanceAccount(
        id: (row['id'] as num).toInt(),
        name: row['name'] as String,
        currency: row['currency'] as String,
        active: row['is_active'] as bool? ?? false,
      );
}

class CourseSummary {
  const CourseSummary(
      {required this.id,
      required this.title,
      required this.status,
      required this.lessonCount});
  final int id;
  final String title;
  final String status;
  final int lessonCount;
}

class CorpusHit {
  const CorpusHit(
      {required this.title, required this.body, required this.similarity});
  final String title;
  final String body;
  final double similarity;
}

class SchoolApi {
  SchoolApi([SupabaseClient? client]) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get _db => _client ?? db;
  Future<OwnerOverview>? _ownerCache;

  Future<int> tenantId() async {
    try {
      final value = await _db.rpc('school_tenant');
      if (value is num) return value.toInt();
      throw ApiException('لا توجد مؤسسة مرتبطة بهذا الحساب.');
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<String?> role() async {
    try {
      final value = await _db.rpc('school_role');
      return value is String ? value : null;
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<List<FeePayment>> feePayments({bool onlyUnposted = false}) async {
    try {
      var query = _db.from('school_fee_payments').select(
          'id, student_id, amount, paid_on, finance_entry_id, school_students(full_name)');
      if (onlyUnposted) query = query.filter('finance_entry_id', 'is', null);
      final rows = await query.order('paid_on', ascending: true).limit(2000);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(FeePayment.fromRow)
          .toList();
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<List<FinanceAccount>> accounts() async {
    try {
      final rows = await _db
          .from('school_finance_accounts')
          .select('id, name, currency, is_active')
          .eq('is_active', true)
          .order('id');
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(FinanceAccount.fromRow)
          .toList();
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<int> postFeePayment(
      {required int paymentId,
      required int accountId,
      required String category}) async {
    try {
      final result = await _db.rpc('school_post_fee_payment_finance', params: {
        'p_payment_id': paymentId,
        'p_account_id': accountId,
        'p_category': category,
        'p_note': null,
      });
      final payload = (result as Map).cast<String, dynamic>();
      final entry = payload['finance_entry_id'];
      if (entry is num) return entry.toInt();
      throw ApiException('استجاب الخادم بلا رقم قيد — لم يُعتمد الترحيل.');
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<List<CourseSummary>> courses() async {
    try {
      final rows = await _db
          .from('school_courses')
          .select('id, title, status, school_course_lessons(id)')
          .order('created_at', ascending: false)
          .limit(300);
      return (rows as List).cast<Map<String, dynamic>>().map((row) {
        final lessons = row['school_course_lessons'];
        return CourseSummary(
            id: (row['id'] as num).toInt(),
            title: row['title'] as String,
            status: row['status'] as String? ?? 'draft',
            lessonCount: lessons is List ? lessons.length : 0);
      }).toList();
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<List<CorpusHit>> searchCorpus(String query, {int limit = 5}) async {
    final term = query.trim();
    if (term.length < 2) return const [];
    try {
      final schoolId = await tenantId();
      final rows = await _db.rpc('match_lesson_content_text',
          params: {'p_school_id': schoolId, 'p_query': term, 'p_limit': limit});
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map((row) => CorpusHit(
                title: row['title'] as String? ?? '',
                body: row['body'] as String? ?? '',
                similarity: (row['similarity'] as num?)?.toDouble() ?? 0,
              ))
          .toList();
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<TeacherWorkspace> teacherWorkspace(int? teacherId) async {
    if (teacherId == null) {
      throw ApiException(
          'هذا الحساب غير مرتبط بسجل معلم. اطلب من الإدارة ربطه.');
    }
    try {
      final slotsRows = await _db
          .from('school_timetable')
          .select(
              'id, class_id, day_of_week, period_no, subject, teacher_id, room')
          .eq('teacher_id', teacherId)
          .order('period_no')
          .limit(300);
      final headedRows = await _db
          .from('school_classes')
          .select('id, name, section, capacity, room, academic_year')
          .eq('class_teacher_id', teacherId)
          .order('id');
      final classRows = await _db
          .from('school_classes')
          .select('id, name, section, capacity, room, academic_year')
          .order('id');
      final classes = (classRows as List)
          .cast<Map<String, dynamic>>()
          .map(SchoolClass.fromRow)
          .toList();
      final byId = {for (final item in classes) item.id: item};
      final assignedIds = <int>{
        ...(slotsRows as List).map((row) => (row['class_id'] as num).toInt()),
        ...(headedRows as List).map((row) => (row['id'] as num).toInt()),
      };
      final assigned = assignedIds
          .map((id) => byId[id])
          .whereType<SchoolClass>()
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      if (assigned.isEmpty) {
        return TeacherWorkspace(
            classes: const [],
            slots: (slotsRows as List)
                .cast<Map<String, dynamic>>()
                .map(TimetableSlot.fromRow)
                .toList(),
            students: const [],
            attendance: const [],
            assignments: const []);
      }
      final ids = assigned.map((item) => item.id).toList();
      final studentRows = await _db
          .from('school_students')
          .select('id, full_name, admission_no, class_id, status')
          .inFilter('class_id', ids)
          .order('full_name')
          .limit(2000);
      final students = (studentRows as List)
          .cast<Map<String, dynamic>>()
          .map(StudentRecord.fromRow)
          .toList();
      final studentIds = students.map((item) => item.id).toSet();
      final since = _date(DateTime.now().subtract(const Duration(days: 89)));
      final attendanceRows = await _db
          .from('school_attendance')
          .select('id, student_id, att_date, status')
          .gte('att_date', since)
          .order('att_date', ascending: false)
          .limit(8000);
      final attendance = (attendanceRows as List)
          .cast<Map<String, dynamic>>()
          .map(AttendanceRecord.fromRow)
          .where((item) => studentIds.contains(item.studentId))
          .toList();
      final assignmentRows = await _db
          .from('school_assignments')
          .select(
              'id, class_id, teacher_id, subject, title, description, assigned_on, due_date, max_marks')
          .inFilter('class_id', ids)
          .order('assigned_on', ascending: false)
          .limit(300);
      return TeacherWorkspace(
        classes: assigned,
        slots: (slotsRows as List)
            .cast<Map<String, dynamic>>()
            .map(TimetableSlot.fromRow)
            .toList(),
        students: students,
        attendance: attendance,
        assignments: (assignmentRows as List)
            .cast<Map<String, dynamic>>()
            .map(AssignmentRecord.fromRow)
            .toList(),
      );
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<void> markStudentAttendance({
    required int studentId,
    required String date,
    required String status,
  }) async {
    const allowed = {'present', 'late', 'absent', 'excused'};
    if (!allowed.contains(status)) throw ApiException('حالة الحضور غير صالحة.');
    try {
      await _db.from('school_attendance').upsert({
        'student_id': studentId,
        'att_date': date,
        'status': status,
      }, onConflict: 'student_id,att_date');
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<void> createAssignment({
    required int classId,
    required int teacherId,
    required String title,
    required String subject,
    required String description,
    required String dueDate,
    required int maxMarks,
  }) async {
    if (title.trim().isEmpty || subject.trim().isEmpty) {
      throw ApiException('عنوان الواجب والمادة مطلوبان.');
    }
    if (maxMarks <= 0) {
      throw ApiException('الدرجة العظمى يجب أن تكون أكبر من صفر.');
    }
    try {
      await _db.from('school_assignments').insert({
        'class_id': classId,
        'teacher_id': teacherId,
        'title': title.trim(),
        'subject': subject.trim(),
        'description': description.trim().isEmpty ? null : description.trim(),
        'due_date': dueDate,
        'max_marks': maxMarks,
        'created_by': _db.auth.currentUser?.id,
      });
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<List<StudentRecord>> linkedStudents(
      {int? studentId, bool parent = false}) async {
    try {
      final ids = <int>{if (studentId != null) studentId};
      if (parent) ids.addAll(await childIds());
      if (ids.isEmpty) return const [];
      final rows = await _db
          .from('school_students')
          .select('id, full_name, admission_no, class_id, status')
          .inFilter('id', ids.toList())
          .order('full_name');
      final students = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(StudentRecord.fromRow)
          .toList();
      if (students.isEmpty) {
        throw ApiException(
            'تعذّر الوصول إلى ملف الطالب المرتبط. راجع ربط الحساب وصلاحيات المؤسسة.');
      }
      return students;
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<List<AttendanceRecord>> studentAttendance(int studentId) async {
    try {
      final rows = await _db
          .from('school_attendance')
          .select('id, student_id, att_date, status')
          .eq('student_id', studentId)
          .order('att_date', ascending: false)
          .limit(90);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(AttendanceRecord.fromRow)
          .toList();
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<List<AssignmentRecord>> classAssignments(int? classId) async {
    if (classId == null) return const [];
    try {
      final rows = await _db
          .from('school_assignments')
          .select(
              'id, class_id, teacher_id, subject, title, description, assigned_on, due_date, max_marks')
          .eq('class_id', classId)
          .order('due_date', ascending: false)
          .limit(200);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(AssignmentRecord.fromRow)
          .toList();
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<List<PublishedResult>> publishedResults(int studentId) async {
    try {
      final student = await _db
          .from('school_students')
          .select('id, class_id')
          .eq('id', studentId)
          .maybeSingle();
      final classId = (student?['class_id'] as num?)?.toInt();
      if (classId == null) return const [];
      final examRows = await _db
          .from('school_exams')
          .select('id, subject, term, exam_date, max_marks')
          .eq('class_id', classId)
          .order('exam_date', ascending: false)
          .limit(200);
      final exams = (examRows as List).cast<Map<String, dynamic>>();
      if (exams.isEmpty) return const [];
      final examIds = exams.map((row) => (row['id'] as num).toInt()).toList();
      final publicationRows = await _db
          .from('school_exam_publications')
          .select('exam_id, is_published')
          .inFilter('exam_id', examIds)
          .eq('is_published', true);
      final publishedIds = (publicationRows as List)
          .map((row) => (row['exam_id'] as num).toInt())
          .toSet();
      if (publishedIds.isEmpty) return const [];
      // Do not even request draft marks: publication is resolved first.
      final markRows = await _db
          .from('school_exam_marks')
          .select('exam_id, marks')
          .eq('student_id', studentId)
          .inFilter('exam_id', publishedIds.toList());
      final marks = <int, num?>{
        for (final row in (markRows as List))
          (row['exam_id'] as num).toInt(): row['marks'] as num?
      };
      return exams
          .where((row) => publishedIds.contains((row['id'] as num).toInt()))
          .map((row) =>
              PublishedResult.fromRow(row, marks[(row['id'] as num).toInt()]))
          .toList();
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<EmployeeWorkspace> employeeWorkspace() async {
    try {
      final employeeId = await myEmployeeId();
      if (employeeId == null) {
        throw ApiException(
            'هذا الحساب غير مرتبط بملف موظف نشط. اطلب من الإدارة ربطه.');
      }
      final employeeRow = await _db
          .from('school_employees')
          .select(
              'id, employee_no, full_name, employment_type, status, hire_date')
          .eq('id', employeeId)
          .maybeSingle();
      if (employeeRow == null) {
        throw ApiException('تعذّر الوصول إلى ملفك الوظيفي.');
      }
      final attendanceRows = await _db
          .from('school_hr_attendance')
          .select(
              'id, employee_id, att_date, status, check_in, check_out, worked_hours, note')
          .eq('employee_id', employeeId)
          .order('att_date', ascending: false)
          .limit(120);
      final leaveRows = await _db
          .from('school_hr_leaves')
          .select(
              'id, employee_id, kind, start_date, end_date, days, paid, reason, status, decided_by_name, decision_note')
          .eq('employee_id', employeeId)
          .order('created_at', ascending: false)
          .limit(100);
      return EmployeeWorkspace(
        employee: EmployeeRecord.fromRow(employeeRow),
        attendance: (attendanceRows as List)
            .cast<Map<String, dynamic>>()
            .map(StaffAttendanceRecord.fromRow)
            .toList(),
        leaves: (leaveRows as List)
            .cast<Map<String, dynamic>>()
            .map(LeaveRecord.fromRow)
            .toList(),
      );
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<NotificationData> notifications(String userId) async {
    try {
      final messageRows = await _db
          .from('school_messages')
          .select(
              'id, sender_id, sender_name, subject, body, status, read_at, created_at')
          .eq('recipient_id', userId)
          .eq('status', 'sent')
          .order('created_at', ascending: false)
          .limit(100);
      final announcementRows = await _db
          .from('school_announcements')
          .select(
              'id, title, body, audience, sent_at, created_at, created_by_name')
          .eq('status', 'sent')
          .order('created_at', ascending: false)
          .limit(100);
      final eventRows = await _db
          .from('school_events')
          .select('id, title, event_date, kind')
          .order('event_date', ascending: false)
          .limit(100);
      return NotificationData(
        messages: (messageRows as List)
            .cast<Map<String, dynamic>>()
            .map(MessageRecord.fromRow)
            .toList(),
        announcements: (announcementRows as List)
            .cast<Map<String, dynamic>>()
            .map(AnnouncementRecord.fromRow)
            .toList(),
        events: (eventRows as List)
            .cast<Map<String, dynamic>>()
            .map(EventRecord.fromRow)
            .toList(),
      );
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<void> markMessageRead(int id, String userId) async {
    try {
      final row = await _db
          .from('school_messages')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id)
          .eq('recipient_id', userId)
          .select('id')
          .maybeSingle();
      if (row == null) {
        throw ApiException(
            'لم يُحدَّث سجل القراءة؛ تحقق من الصلاحية وأعد المحاولة.');
      }
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<void> signOut() => _db.auth.signOut();

  Future<int> countRows(String table, {String? column, Object? equals}) async {
    try {
      var query = _db.from(table).select('id');
      if (column != null && equals != null) query = query.eq(column, equals);
      final response = await query.count(CountOption.exact);
      return response.count;
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<int> unpostedFeeCount() async {
    try {
      final response = await _db
          .from('school_fee_payments')
          .select('id')
          .filter('finance_entry_id', 'is', null)
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<double> unpostedFeeValue() async {
    try {
      final rows = await _db
          .from('school_fee_payments')
          .select('amount')
          .filter('finance_entry_id', 'is', null)
          .limit(5000);
      return (rows as List).cast<Map<String, dynamic>>().fold<double>(
          0, (sum, row) => sum + (row['amount'] as num).toDouble());
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<double> ledgerNet() async {
    try {
      final result = await _db.rpc('school_finance_summary');
      final payload = (result as Map).cast<String, dynamic>();
      final net = payload['net'];
      return net is num ? net.toDouble() : 0;
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<int> pendingFinanceApprovals() async {
    try {
      final response = await _db
          .from('school_finance_entries')
          .select('id')
          .eq('status', 'pending')
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<List<int>> childIds() async {
    try {
      final result = await _db.rpc('school_child_ids');
      if (result is! List) return const [];
      return result.whereType<num>().map((v) => v.toInt()).toList();
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<int?> myStudentId() async {
    try {
      final result = await _db.rpc('school_student_id');
      return result is num ? result.toInt() : null;
    } catch (_) {
      return null;
    }
  }

  Future<int?> myEmployeeId() async {
    try {
      final result = await _db.rpc('school_my_employee_id');
      return result is num ? result.toInt() : null;
    } catch (_) {
      return null;
    }
  }

  Future<OwnerOverview> ownerOverview() => _ownerCache ??= _loadOwnerOverview();

  Future<OwnerOverview> _loadOwnerOverview() async {
    try {
      final rows = await _db.rpc('owner_school_overview');
      final list = (rows as List).cast<Map<String, dynamic>>();
      var students = 0, teachers = 0, classes = 0, users = 0;
      for (final row in list) {
        students += (row['student_count'] as num?)?.toInt() ?? 0;
        teachers += (row['teacher_count'] as num?)?.toInt() ?? 0;
        classes += (row['class_count'] as num?)?.toInt() ?? 0;
        users += (row['user_count'] as num?)?.toInt() ?? 0;
      }
      return OwnerOverview(
          schools: list.length,
          students: students,
          teachers: teachers,
          classes: classes,
          users: users);
    } catch (e) {
      _ownerCache = null;
      throw _wrap(e);
    }
  }

  Future<int> enrolledCourseCount() async {
    try {
      final response = await _db
          .from('school_course_enrollments')
          .select('id')
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<SchoolBranding?> branding() async {
    try {
      final rows = await _db
          .from('schools')
          .select(
              'name, primary_color, accent_color, logo_url, currency, academic_year')
          .limit(1);
      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) return null;
      return SchoolBranding.fromRow(list.first);
    } catch (e) {
      throw _wrap(e);
    }
  }
}

class OwnerOverview {
  const OwnerOverview(
      {required this.schools,
      required this.students,
      required this.teachers,
      required this.classes,
      required this.users});
  final int schools;
  final int students;
  final int teachers;
  final int classes;
  final int users;
}

class SchoolBranding {
  const SchoolBranding(
      {required this.name,
      this.primaryColor,
      this.accentColor,
      this.logoUrl,
      this.currency = 'YER',
      this.academicYear});
  final String name;
  final int? primaryColor;
  final int? accentColor;
  final String? logoUrl;
  final String currency;
  final String? academicYear;

  static int? _hex(Object? raw) {
    if (raw is! String) return null;
    final cleaned = raw.trim().replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    return value == null ? null : 0xFF000000 | value;
  }

  factory SchoolBranding.fromRow(Map<String, dynamic> row) => SchoolBranding(
        name: (row['name'] as String?) ?? 'المؤسسة التعليمية',
        primaryColor: _hex(row['primary_color']),
        accentColor: _hex(row['accent_color']),
        logoUrl: row['logo_url'] as String?,
        currency: (row['currency'] as String?) ?? 'YER',
        academicYear: row['academic_year'] as String?,
      );
}

String _date(DateTime value) =>
    value.toUtc().toIso8601String().substring(0, 10);

int _int(Map<String, dynamic> row, String key) => (row[key] as num).toInt();

class SchoolClass {
  const SchoolClass(
      {required this.id,
      required this.name,
      this.section,
      this.capacity,
      this.room,
      this.academicYear});
  final int id;
  final String name;
  final String? section;
  final int? capacity;
  final String? room;
  final String? academicYear;
  String get label =>
      '$name${section == null || section!.isEmpty ? '' : ' — $section'}';
  factory SchoolClass.fromRow(Map<String, dynamic> row) => SchoolClass(
        id: _int(row, 'id'),
        name: row['name'] as String? ?? 'فصل',
        section: row['section'] as String?,
        capacity: (row['capacity'] as num?)?.toInt(),
        room: row['room'] as String?,
        academicYear: row['academic_year'] as String?,
      );
}

class TimetableSlot {
  const TimetableSlot(
      {required this.id,
      required this.classId,
      required this.dayOfWeek,
      required this.periodNo,
      this.subject,
      this.room});
  final int id;
  final int classId;
  final int dayOfWeek;
  final int periodNo;
  final String? subject;
  final String? room;
  factory TimetableSlot.fromRow(Map<String, dynamic> row) => TimetableSlot(
        id: _int(row, 'id'),
        classId: _int(row, 'class_id'),
        dayOfWeek: _int(row, 'day_of_week'),
        periodNo: _int(row, 'period_no'),
        subject: row['subject'] as String?,
        room: row['room'] as String?,
      );
}

class StudentRecord {
  const StudentRecord(
      {required this.id,
      required this.fullName,
      this.admissionNo,
      this.classId,
      this.status});
  final int id;
  final String fullName;
  final String? admissionNo;
  final int? classId;
  final String? status;
  factory StudentRecord.fromRow(Map<String, dynamic> row) => StudentRecord(
        id: _int(row, 'id'),
        fullName: row['full_name'] as String? ?? 'طالب',
        admissionNo: row['admission_no'] as String?,
        classId: (row['class_id'] as num?)?.toInt(),
        status: row['status'] as String?,
      );
}

class AttendanceRecord {
  const AttendanceRecord(
      {required this.id,
      required this.studentId,
      required this.date,
      required this.status});
  final int id;
  final int studentId;
  final String date;
  final String status;
  factory AttendanceRecord.fromRow(Map<String, dynamic> row) =>
      AttendanceRecord(
        id: _int(row, 'id'),
        studentId: _int(row, 'student_id'),
        date: row['att_date'] as String,
        status: row['status'] as String? ?? 'present',
      );
}

class AssignmentRecord {
  const AssignmentRecord(
      {required this.id,
      required this.classId,
      this.teacherId,
      required this.subject,
      required this.title,
      this.description,
      required this.assignedOn,
      required this.dueDate,
      required this.maxMarks});
  final int id;
  final int classId;
  final int? teacherId;
  final String subject;
  final String title;
  final String? description;
  final String assignedOn;
  final String dueDate;
  final int maxMarks;
  factory AssignmentRecord.fromRow(Map<String, dynamic> row) =>
      AssignmentRecord(
        id: _int(row, 'id'),
        classId: _int(row, 'class_id'),
        teacherId: (row['teacher_id'] as num?)?.toInt(),
        subject: row['subject'] as String? ?? '',
        title: row['title'] as String? ?? '',
        description: row['description'] as String?,
        assignedOn: row['assigned_on'] as String,
        dueDate: row['due_date'] as String,
        maxMarks: (row['max_marks'] as num?)?.toInt() ?? 10,
      );
}

class TeacherWorkspace {
  const TeacherWorkspace(
      {required this.classes,
      required this.slots,
      required this.students,
      required this.attendance,
      required this.assignments});
  final List<SchoolClass> classes;
  final List<TimetableSlot> slots;
  final List<StudentRecord> students;
  final List<AttendanceRecord> attendance;
  final List<AssignmentRecord> assignments;
  List<StudentRecord> studentsOf(int classId) =>
      students.where((item) => item.classId == classId).toList();
}

class PublishedResult {
  const PublishedResult(
      {required this.examId,
      required this.subject,
      this.term,
      required this.examDate,
      required this.maxMarks,
      this.marks});
  final int examId;
  final String subject;
  final String? term;
  final String examDate;
  final int maxMarks;
  final num? marks;
  int? get percent =>
      marks == null || maxMarks <= 0 ? null : (100 * marks! / maxMarks).round();
  factory PublishedResult.fromRow(Map<String, dynamic> row, num? marks) =>
      PublishedResult(
        examId: _int(row, 'id'),
        subject: row['subject'] as String? ?? 'اختبار',
        term: row['term'] as String?,
        examDate: row['exam_date'] as String,
        maxMarks: (row['max_marks'] as num?)?.toInt() ?? 100,
        marks: marks,
      );
}

class EmployeeRecord {
  const EmployeeRecord(
      {required this.id,
      required this.employeeNo,
      required this.fullName,
      required this.employmentType,
      required this.status,
      required this.hireDate});
  final int id;
  final String employeeNo;
  final String fullName;
  final String employmentType;
  final String status;
  final String hireDate;
  factory EmployeeRecord.fromRow(Map<String, dynamic> row) => EmployeeRecord(
        id: _int(row, 'id'),
        employeeNo: row['employee_no'] as String? ?? '—',
        fullName: row['full_name'] as String? ?? 'موظف',
        employmentType: row['employment_type'] as String? ?? '',
        status: row['status'] as String? ?? '',
        hireDate: row['hire_date'] as String? ?? '',
      );
}

class StaffAttendanceRecord {
  const StaffAttendanceRecord(
      {required this.id,
      required this.date,
      required this.status,
      this.checkIn,
      this.checkOut,
      this.workedHours,
      this.note});
  final int id;
  final String date;
  final String status;
  final String? checkIn;
  final String? checkOut;
  final num? workedHours;
  final String? note;
  factory StaffAttendanceRecord.fromRow(Map<String, dynamic> row) =>
      StaffAttendanceRecord(
        id: _int(row, 'id'),
        date: row['att_date'] as String,
        status: row['status'] as String? ?? '',
        checkIn: row['check_in'] as String?,
        checkOut: row['check_out'] as String?,
        workedHours: row['worked_hours'] as num?,
        note: row['note'] as String?,
      );
}

class LeaveRecord {
  const LeaveRecord(
      {required this.id,
      required this.kind,
      required this.startDate,
      required this.endDate,
      required this.days,
      required this.paid,
      required this.status,
      this.reason,
      this.decisionNote});
  final int id;
  final String kind;
  final String startDate;
  final String endDate;
  final num days;
  final bool paid;
  final String status;
  final String? reason;
  final String? decisionNote;
  factory LeaveRecord.fromRow(Map<String, dynamic> row) => LeaveRecord(
        id: _int(row, 'id'),
        kind: row['kind'] as String? ?? 'other',
        startDate: row['start_date'] as String,
        endDate: row['end_date'] as String,
        days: row['days'] as num? ?? 0,
        paid: row['paid'] as bool? ?? false,
        status: row['status'] as String? ?? 'pending',
        reason: row['reason'] as String?,
        decisionNote: row['decision_note'] as String?,
      );
}

class EmployeeWorkspace {
  const EmployeeWorkspace(
      {required this.employee, required this.attendance, required this.leaves});
  final EmployeeRecord employee;
  final List<StaffAttendanceRecord> attendance;
  final List<LeaveRecord> leaves;
}

class MessageRecord {
  const MessageRecord(
      {required this.id,
      required this.subject,
      required this.body,
      required this.createdAt,
      this.senderName,
      this.readAt});
  final int id;
  final String subject;
  final String body;
  final String createdAt;
  final String? senderName;
  final String? readAt;
  factory MessageRecord.fromRow(Map<String, dynamic> row) => MessageRecord(
        id: _int(row, 'id'),
        subject: row['subject'] as String? ?? '',
        body: row['body'] as String? ?? '',
        createdAt: row['created_at'] as String,
        senderName: row['sender_name'] as String?,
        readAt: row['read_at'] as String?,
      );
}

class AnnouncementRecord {
  const AnnouncementRecord(
      {required this.id,
      required this.title,
      required this.body,
      required this.createdAt,
      this.author});
  final int id;
  final String title;
  final String body;
  final String createdAt;
  final String? author;
  factory AnnouncementRecord.fromRow(Map<String, dynamic> row) =>
      AnnouncementRecord(
        id: _int(row, 'id'),
        title: row['title'] as String? ?? '',
        body: row['body'] as String? ?? '',
        createdAt: (row['sent_at'] ?? row['created_at']) as String,
        author: row['created_by_name'] as String?,
      );
}

class EventRecord {
  const EventRecord(
      {required this.id, required this.title, required this.date, this.kind});
  final int id;
  final String title;
  final String date;
  final String? kind;
  factory EventRecord.fromRow(Map<String, dynamic> row) => EventRecord(
        id: _int(row, 'id'),
        title: row['title'] as String? ?? '',
        date: row['event_date'] as String,
        kind: row['kind'] as String?,
      );
}

class NotificationData {
  const NotificationData(
      {required this.messages,
      required this.announcements,
      required this.events});
  final List<MessageRecord> messages;
  final List<AnnouncementRecord> announcements;
  final List<EventRecord> events;
}
