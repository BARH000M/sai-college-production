import 'package:flutter/services.dart';

import 'class_models.dart';

class RosterStudent {
  const RosterStudent({required this.admissionNo, required this.fullName});

  final String admissionNo;
  final String fullName;
}

String _two(int value) => value.toString().padLeft(2, '0');

String _stamp(DateTime value) => '${value.year}/${_two(value.month)}/${_two(value.day)} — ${_two(value.hour)}:${_two(value.minute)}';

const _divider = '──────────────────────────────────';

/// Builds the plain-text version of the class roster sheet so it can be shared
/// through WhatsApp, email or copied into a print job on any device.
String buildClassRosterText({
  required SaiClass cls,
  required List<RosterStudent> students,
  required DateTime issuedAt,
}) {
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
    ..writeln('تاريخ الإصدار: ${_stamp(issuedAt)}')
    ..writeln(_divider)
    ..writeln('م | رقم القيد | اسم الطالب | الحضور | ملاحظات');

  if (students.isEmpty) {
    buffer.writeln('لا يوجد طلاب مسجلون في هذا الصف.');
  } else {
    for (var index = 0; index < students.length; index++) {
      final student = students[index];
      buffer.writeln('${index + 1} | ${student.admissionNo} | ${student.fullName} |  | ');
    }
  }

  buffer
    ..writeln(_divider)
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