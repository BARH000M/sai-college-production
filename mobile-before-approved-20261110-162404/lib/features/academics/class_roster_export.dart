import 'package:flutter/services.dart';

import 'class_models.dart';

const _monthNames = <String>[
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// One row of the printed roster. The attendance fields are real totals for the
/// current month, aggregated from the attendance records of this class.
class RosterStudent {
  const RosterStudent({
    required this.admissionNo,
    required this.fullName,
    this.presentDays = 0,
    this.absentDays = 0,
    this.lateDays = 0,
    this.excusedDays = 0,
  });

  final String admissionNo;
  final String fullName;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int excusedDays;

  /// Every day that carries a recorded status for this student this month.
  int get recordedDays => presentDays + absentDays + lateDays + excusedDays;

  /// A student counts as attending when present or late.
  int get attendedDays => presentDays + lateDays;

  int get attendancePercent =>
      recordedDays == 0 ? 0 : ((attendedDays / recordedDays) * 100).round();

  String get attendanceShort => recordedDays == 0 ? '—' : '$attendedDays/$recordedDays';

  String get attendanceCell =>
      recordedDays == 0 ? '—' : '$attendedDays/$recordedDays ($attendancePercent%)';
}

/// Class-wide attendance rate for the month, or null when nothing is recorded.
int? classAttendancePercent(List<RosterStudent> students) {
  var recorded = 0;
  var attended = 0;
  for (final student in students) {
    recorded += student.recordedDays;
    attended += student.attendedDays;
  }
  if (recorded == 0) return null;
  return ((attended / recorded) * 100).round();
}

String monthLabel(DateTime value) => '${_monthNames[value.month - 1]} ${value.year}';

String _two(int value) => value.toString().padLeft(2, '0');

String _stamp(DateTime value) =>
    '${value.year}/${_two(value.month)}/${_two(value.day)} — ${_two(value.hour)}:${_two(value.minute)}';

const _divider = '──────────────────────────────────';

/// Builds the plain-text version of the class roster sheet so it can be shared
/// through WhatsApp, email or copied into a print job on any device.
String buildClassRosterText({
  required SaiClass cls,
  required List<RosterStudent> students,
  required DateTime issuedAt,
}) {
  final percent = classAttendancePercent(students);
  final buffer = StringBuffer()
    ..writeln('كلية ساي التعليمية اليمنية الصينية')
    ..writeln('世门赛艾教育学院')
    ..writeln('كشف طلاب الصف')
    ..writeln(_divider)
    ..writeln('الصف: ${cls.name}')
    ..writeln('البرنامج: ${cls.program}')
    ..writeln('معلم الصف: ${cls.teacherName ?? 'غير مسند'}')
    ..writeln('الفرع: ${cls.branchName ?? '—'}')
    ..writeln('السعة: ${cls.capacity} · المسجلون: ${students.length} · المقاعد المتاحة: ${cls.available}')
    ..writeln('حضور شهر ${monthLabel(issuedAt)}: ${percent == null ? 'لا توجد سجلات' : '$percent%'}')
    ..writeln('تاريخ الإصدار: ${_stamp(issuedAt)}')
    ..writeln(_divider)
    ..writeln('م | رقم القيد | اسم الطالب | حضور الشهر | ملاحظات');

  if (students.isEmpty) {
    buffer.writeln('لا يوجد طلاب مسجلون في هذا الصف.');
  } else {
    for (var index = 0; index < students.length; index++) {
      final student = students[index];
      buffer.writeln(
        '${index + 1} | ${student.admissionNo} | ${student.fullName} | ${student.attendanceCell} | ',
      );
    }
  }

  buffer
    ..writeln(_divider)
    ..writeln('حضور الشهر = الأيام المسجّلة (حاضر + متأخر) من إجمالي أيام التسجيل.')
    ..writeln('توقيع معلم الصف: ..............................')
    ..writeln('توقيع إدارة الكلية: ..............................')
    ..writeln('صدر من تطبيق كلية ساي — نسخة ${students.length} طالباً.');

  return buffer.toString();
}

Future<void> copyClassRoster({
  required SaiClass cls,
  required List<RosterStudent> students,
  DateTime? issuedAt,
}) async {
  final text = buildClassRosterText(cls: cls, students: students, issuedAt: issuedAt ?? DateTime.now());
  await Clipboard.setData(ClipboardData(text: text));
}