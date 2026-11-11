import 'dart:convert';

import '../core/access.dart';
import 'curriculum.dart';
import 'demo_workspace.dart';

typedef RecordField = ({String label, String value});

RecordField field(String label, String value) => (label: label, value: value);

const roleLabels = {
  Role.super_admin: 'المشرف العام',
  Role.admin: 'الإدارة',
  Role.teacher: 'المعلّم',
  Role.accountant: 'المحاسب',
  Role.receptionist: 'القبول والتسجيل',
  Role.librarian: 'أمين المكتبة',
  Role.student: 'الطالب',
  Role.parent: 'ولي الأمر',
  Role.content_editor: 'محرّر المحتوى',
};

const previewNames = {
  Role.super_admin: 'مروان عبدالله',
  Role.admin: 'ريم أحمد',
  Role.teacher: 'مريم صالح',
  Role.accountant: 'نبيل يحيى',
  Role.receptionist: 'سارة محمد',
  Role.librarian: 'عادل حسن',
  Role.student: 'خالد فيصل اليافعي',
  Role.parent: 'فيصل اليافعي',
  Role.content_editor: 'أسماء علي',
};

class CollegeEntry {
  const CollegeEntry(
    this.id,
    this.title,
    this.summary,
    this.status,
    this.fields,
  );
  final String id, title, summary, status;
  final List<RecordField> fields;
}

class DemoAction {
  const DemoAction(this.label, this.status, {this.input});
  final String label, status;
  final String? input;
}

class DemoSchool {
  static const studentId = 'demo-007';
  static const studentName = 'خالد فيصل اليافعي';
  static const studentNumber = 'SAI-2026-007';
  static const studentClass = 'demo-sai1';
  static const paid = 'مسددة';
  static const unpaid = 'مستحقة';
  static const present = 'حاضر';
  static const absent = 'غائب';
  static const late = 'متأخر';
  static const unmarked = 'لم يسجل';
  static const submitted = 'تم التسليم';
  static const reviewed = 'تمت المراجعة';

  static const classes = <Map<String, dynamic>>[
    {
      'id': 'demo-p0',
      'name': 'التمهيدي أ',
      'program': 'P0 • الأصوات والتحية',
      'capacity': 16,
    },
    {
      'id': 'demo-a0',
      'name': 'الأساسي أ',
      'program': 'A0 • التعارف والأسرة',
      'capacity': 18,
    },
    {
      'id': studentClass,
      'name': 'المحادثة ب',
      'program': 'SAI1 • المحادثة اليومية',
      'capacity': 20,
    },
    {
      'id': 'demo-sai2',
      'name': 'التطبيقات أ',
      'program': 'SAI2 • قواعد وتطبيقات',
      'capacity': 20,
    },
  ];

  static const students = <Map<String, String>>[
    {
      'id': studentId,
      'full_name': studentName,
      'admission_no': studentNumber,
      'class_id': studentClass,
    },
    {
      'id': 'demo-006',
      'full_name': 'ليلى محمد العمري',
      'admission_no': 'SAI-2026-006',
      'class_id': studentClass,
    },
    {
      'id': 'demo-005',
      'full_name': 'عمر حسن الصبري',
      'admission_no': 'SAI-2026-005',
      'class_id': studentClass,
    },
    {
      'id': 'demo-004',
      'full_name': 'هدى منصور',
      'admission_no': 'SAI-2026-004',
      'class_id': 'demo-sai2',
    },
    {
      'id': 'demo-003',
      'full_name': 'بدر أمين',
      'admission_no': 'SAI-2026-003',
      'class_id': 'demo-sai2',
    },
    {
      'id': 'demo-002',
      'full_name': 'أحمد ياسر',
      'admission_no': 'SAI-2026-002',
      'class_id': 'demo-a0',
    },
    {
      'id': 'demo-001',
      'full_name': 'ندى إبراهيم',
      'admission_no': 'SAI-2026-001',
      'class_id': 'demo-p0',
    },
  ];

  static bool administrator(Set<Role> roles) =>
      roles.contains(Role.super_admin) || roles.contains(Role.admin);

  static bool familyView(Set<Role> roles) =>
      !administrator(roles) &&
      !roles.contains(Role.teacher) &&
      (roles.contains(Role.student) || roles.contains(Role.parent));

  static List<Map<String, dynamic>> visibleClasses(Set<Role> roles) => [
    for (final row in classes)
      if (administrator(roles) ||
          roles.contains(Role.receptionist) ||
          (roles.contains(Role.teacher) &&
              ['demo-sai1', 'demo-sai2'].contains(row['id'])) ||
          (familyView(roles) && row['id'] == studentClass))
        row,
  ];

  static List<Map<String, dynamic>> visibleStudents(
    String classId,
    Set<Role> roles,
  ) {
    if (!visibleClasses(roles).any((row) => row['id'] == classId)) return [];
    final ownOnly = familyView(roles) && !roles.contains(Role.receptionist);
    return [
      for (final row in students)
        if (row['class_id'] == classId && (!ownOnly || row['id'] == studentId))
          row,
    ];
  }

  static String attendanceKey(String date, String id) => 'attendance.$date.$id';

  static String dateLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String attendance(DemoWorkspace demo, DateTime date, String student) =>
      demo.value(
        attendanceKey(dateLabel(date), student),
        dateLabel(date) == dateLabel(DateTime.now()) && student == studentId
            ? present
            : unmarked,
      );

  static String _recordKey(DemoWorkspace demo, PageId page, CollegeEntry row) =>
      '${page.name}.${page == PageId.notifications ? '${demo.role.name}.' : ''}${row.id}';

  static Map<String, dynamic> _record(
    DemoWorkspace demo,
    PageId page,
    CollegeEntry row,
  ) {
    final value = demo.value(_recordKey(demo, page, row));
    if (value.isEmpty) return {};
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException {
      return {};
    }
  }

  static String status(DemoWorkspace demo, PageId page, CollegeEntry row) =>
      (_record(demo, page, row)['status'] as String?) ?? row.status;

  static String detail(DemoWorkspace demo, PageId page, CollegeEntry row) =>
      (_record(demo, page, row)['detail'] as String?) ?? '';

  static Future<void> update(
    DemoWorkspace demo,
    PageId page,
    CollegeEntry row,
    String status, {
    String? note,
  }) => demo.save(
    _recordKey(demo, page, row),
    jsonEncode({'status': status, 'detail': note ?? detail(demo, page, row)}),
  );

  static List<CollegeEntry> records(
    PageId page,
    Set<Role> roles,
    DemoWorkspace demo,
  ) {
    if (!Access.allows(roles, page)) return [];
    final own = familyView(roles);
    return switch (page) {
      PageId.admissions => [
        CollegeEntry(
          'A-001',
          'هدى عبدالله',
          'طلب الالتحاق بالمستوى الأساسي',
          'طلب جديد',
          [
            field('رقم الطلب', 'ADM-001'),
            field('البرنامج', 'A0 • المجموعة المسائية'),
            field('المستندات', 'استمارة مكتملة'),
          ],
        ),
        CollegeEntry(
          'A-002',
          'عبدالرحمن حسين',
          'طلب الالتحاق بالمستوى التمهيدي',
          'قيد المراجعة',
          [
            field('رقم الطلب', 'ADM-002'),
            field('البرنامج', 'P0 • المجموعة الصباحية'),
            field('المستندات', 'استمارة مكتملة'),
          ],
        ),
        CollegeEntry('A-003', 'نورة أحمد', 'اختبار تحديد مستوى', 'مقبول', [
          field('رقم الطلب', 'ADM-003'),
          field('البرنامج', 'SAI1'),
          field('نتيجة المقابلة', 'المحادثة اليومية'),
        ]),
      ],
      PageId.finance => [
        _invoice(
          'INV-007',
          studentName,
          'رسوم المحادثة اليومية',
          '25,000 ر.ي',
          unpaid,
        ),
        _invoice('INV-008', studentName, 'رسوم التسجيل', '5,000 ر.ي', paid),
        if (!own || Access.manages(roles, page)) ...[
          _invoice(
            'INV-006',
            'ليلى محمد العمري',
            'رسوم المحادثة اليومية',
            '25,000 ر.ي',
            paid,
          ),
          _invoice(
            'INV-005',
            'عمر حسن الصبري',
            'رسوم المحادثة اليومية',
            '25,000 ر.ي',
            unpaid,
          ),
        ],
      ],
      PageId.staff => [
        for (final row in [
          ('S-01', 'مريم صالح', 'معلمة اللغة الصينية', 'الأكاديمي'),
          ('S-02', 'نبيل يحيى', 'محاسب', 'المالية'),
          ('S-03', 'سارة محمد', 'مسؤولة التسجيل', 'القبول'),
          ('S-04', 'عادل حسن', 'أمين المكتبة', 'المكتبة'),
        ])
          CollegeEntry(row.$1, row.$2, row.$3, 'على رأس العمل', [
            field('الرقم الوظيفي', row.$1),
            field('القسم', row.$4),
          ]),
      ],
      PageId.library => [
        for (final row in [
          (
            'B-01',
            'مدخل إلى نطق الصينية',
            'اللغة الصينية • التمهيدي',
            'متاح',
            'صينية / عربية',
          ),
          (
            'B-02',
            'محادثات يومية 中文会话',
            'اللغة الصينية • SAI1',
            'معار',
            'صينية / عربية',
          ),
          (
            'B-03',
            'دليل مفردات الأسرة',
            'اللغة الصينية • الأساسي',
            'متاح',
            'صينية / عربية',
          ),
          (
            'B-04',
            'الثقافة الصينية في الحياة اليومية',
            'الثقافة والقراءة',
            'متاح',
            'عربية',
          ),
        ])
          CollegeEntry(row.$1, row.$2, row.$3, row.$4, [
            field('رقم الفهرس', row.$1),
            field('لغة المورد', row.$5),
          ]),
      ],
      PageId.exams => [
        CollegeEntry('E-01', 'اختبار المفردات', studentName, '82 / 100', [
          field('المقرر', 'SAI1 • المحادثة اليومية'),
          field('نوع الاختبار', 'مفردات وقراءة'),
        ]),
        CollegeEntry(
          'E-02',
          'تقييم المحادثة الشفهية',
          studentName,
          'بانتظار الدرجة',
          [
            field('المقرر', 'SAI1 • المحادثة اليومية'),
            field('نوع الاختبار', 'تحدث'),
          ],
        ),
        if (!own)
          CollegeEntry(
            'E-03',
            'تقييم المحادثة الشفهية',
            'ليلى محمد العمري',
            '88 / 100',
            [
              field('المقرر', 'SAI1 • المحادثة اليومية'),
              field('نوع الاختبار', 'تحدث'),
            ],
          ),
      ],
      PageId.schedule => [
        for (final row in [
          (
            'T-01',
            'السبت',
            'المحادثة اليومية',
            '16:00 – 17:00',
            'قاعة ٢',
            'SAI1',
          ),
          (
            'T-02',
            'الاثنين',
            'مفردات السوق',
            '16:00 – 17:00',
            'قاعة ٢',
            'SAI1',
          ),
          (
            'T-03',
            'الأربعاء',
            'القراءة والاستماع',
            '16:00 – 17:00',
            'مختبر اللغة',
            'SAI1',
          ),
          (
            'T-04',
            'الأحد',
            'التطبيقات العملية',
            '17:00 – 18:00',
            'قاعة ٣',
            'SAI2',
          ),
        ])
          if (!own || row.$6 == 'SAI1')
            CollegeEntry(
              row.$1,
              row.$3,
              '${row.$2} • ${row.$4}',
              'حصة مجدولة',
              [
                field('المستوى', row.$6),
                field('المكان', row.$5),
                field('المعلّمة', 'مريم صالح'),
              ],
            ),
      ],
      PageId.assignments => [
        CollegeEntry('W-01', 'عرّف بنفسك', 'SAI1 • واجب كتابة', 'مفتوح', [
          field('المطلوب', 'اكتب جملتين بالصينية عن اسمك وبلدك.'),
          field('الطالب', studentName),
        ]),
        CollegeEntry('W-02', 'حوار في السوق', 'SAI1 • واجب محادثة', 'مفتوح', [
          field('المطلوب', 'اكتب سؤالاً عن السعر وإجابة مناسبة.'),
          field('الطالب', studentName),
        ]),
        CollegeEntry(
          'W-03',
          'صف هوايتك',
          'SAI1 • واجب قراءة وكتابة',
          reviewed,
          [
            field('المطلوب', 'اكتب جملة باستخدام 喜欢.'),
            field('الطالب', studentName),
          ],
        ),
      ],
      PageId.content => [
        for (final course in courses)
          CollegeEntry(
            'C-${course.code}',
            course.lessons.first.title,
            '${course.code} • ملف درس',
            course.code == 'SAI1' ? 'قيد المراجعة' : 'مسودة',
            [
              field('معرّف الدرس', course.lessons.first.id),
              field('هدف الدرس', course.lessons.first.tip),
              field('المحرّر', 'أسماء علي'),
            ],
          ),
      ],
      PageId.users => [
        for (final role in Role.values)
          CollegeEntry(
            'U-${role.name}',
            previewNames[role]!,
            roleLabels[role]!,
            'نشط',
            [
              field('الدور', roleLabels[role]!),
              field('نوع السجل', 'حساب تمثيلي للتجربة'),
            ],
          ),
      ],
      PageId.reports => [
        if (administrator(roles))
          CollegeEntry('R-01', 'ملخص التسجيل', 'الطلاب والشعب والقبول', 'محدّث', [
            field('الطلاب', '${students.length}'),
            field('الشعب', '${classes.length}'),
            field(
              'الطلبات المقبولة',
              '${records(PageId.admissions, roles, demo).where((row) => status(demo, PageId.admissions, row) == 'مقبول').length}',
            ),
          ]),
        CollegeEntry('R-02', 'ملخص التحصيل', 'حالة الفواتير التجريبية', 'محدّث', [
          field(
            'المسددة',
            '${records(PageId.finance, roles, demo).where((row) => status(demo, PageId.finance, row) == paid).length}',
          ),
          field(
            'المستحقة',
            '${records(PageId.finance, roles, demo).where((row) => status(demo, PageId.finance, row) == unpaid).length}',
          ),
        ]),
      ],
      PageId.notifications => [
        CollegeEntry('N-01', 'أهلاً بك في كلية ساي', 'إعلانات الكلية', 'جديد', [
          field('الرسالة', 'تفضل بزيارة أنظمة الكلية للاطلاع على أدوات حسابك.'),
        ]),
        if (Access.allows(roles, PageId.schedule))
          CollegeEntry('N-02', 'الجدول الأسبوعي متاح', 'الأكاديمية', 'جديد', [
            field(
              'الرسالة',
              'يمكنك مراجعة مواعيد المحاضرات وقاعاتها من صفحة الجدول.',
            ),
          ]),
        if (Access.allows(roles, PageId.finance))
          CollegeEntry('N-03', 'مراجعة الرسوم', 'المالية', 'جديد', [
            field('الرسالة', 'تظهر الفواتير المستحقة في قسم الرسوم والمالية.'),
          ]),
        if (Access.allows(roles, PageId.assignments))
          CollegeEntry('N-04', 'واجب المحادثة', 'الأكاديمية', 'جديد', [
            field('الرسالة', 'واجب حوار السوق متاح في قسم الواجبات.'),
          ]),
        if (Access.allows(roles, PageId.content))
          CollegeEntry('N-05', 'مراجعة درس جديد', 'المحتوى', 'جديد', [
            field('الرسالة', 'توجد مواد قيد المراجعة في استوديو المحتوى.'),
          ]),
      ],
      _ => const [],
    };
  }

  static CollegeEntry _invoice(
    String id,
    String name,
    String title,
    String amount,
    String status,
  ) => CollegeEntry(id, title, name, status, [
    field('الفاتورة', id),
    field('المبلغ', amount),
    field('الطالب', name),
  ]);

  static DemoAction? action(PageId page, Set<Role> roles, String status) {
    if (page == PageId.notifications && status == 'جديد') {
      return const DemoAction('تمييز كمقروء', 'مقروء');
    }
    if (!Access.manages(roles, page)) {
      return switch (page) {
        PageId.assignments
            when roles.contains(Role.student) && status == 'مفتوح' =>
          const DemoAction('تسليم الواجب', submitted, input: 'اكتب إجابتك'),
        PageId.library when roles.contains(Role.student) && status == 'متاح' =>
          const DemoAction('طلب حجز', 'محجوز'),
        _ => null,
      };
    }
    return switch (page) {
      PageId.admissions when status == 'طلب جديد' => const DemoAction(
        'بدء المراجعة',
        'قيد المراجعة',
      ),
      PageId.admissions when status == 'قيد المراجعة' => const DemoAction(
        'قبول الطلب',
        'مقبول',
      ),
      PageId.finance when status == unpaid => const DemoAction(
        'تسجيل سداد تجريبي',
        paid,
      ),
      PageId.staff when status == 'على رأس العمل' => const DemoAction(
        'تسجيل إجازة تجريبية',
        'في إجازة',
      ),
      PageId.staff => const DemoAction('إنهاء الإجازة', 'على رأس العمل'),
      PageId.library when status == 'معار' => const DemoAction(
        'تسجيل الإرجاع',
        'متاح',
      ),
      PageId.library => const DemoAction('تسجيل الإعارة', 'معار'),
      PageId.exams => const DemoAction(
        'حفظ الدرجة',
        '',
        input: 'الدرجة من 100',
      ),
      PageId.assignments when status == submitted => const DemoAction(
        'اعتماد المراجعة',
        reviewed,
      ),
      PageId.content when status == 'مسودة' => const DemoAction(
        'إرسال للمراجعة',
        'قيد المراجعة',
      ),
      PageId.content when status == 'قيد المراجعة' && administrator(roles) =>
        const DemoAction('اعتماد المادة التجريبية', 'معتمد'),
      PageId.users when status == 'نشط' => const DemoAction(
        'تعطيل الحساب التجريبي',
        'موقوف',
      ),
      PageId.users => const DemoAction('تفعيل الحساب التجريبي', 'نشط'),
      _ => null,
    };
  }
}
