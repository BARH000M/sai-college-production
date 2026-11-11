/// Shared class record used by the classes screen, the "add class" sheet,
/// the attendance register and the printable roster sheet.
class SaiClass {
  const SaiClass({
    required this.id,
    required this.name,
    required this.program,
    required this.capacity,
    required this.enrolled,
    required this.isActive,
    required this.branchId,
    required this.sessionId,
    this.teacherId,
    this.teacherName,
    this.branchName,
    this.sessionName,
  });

  final String id;
  final String name;
  final String program;
  final int capacity;
  final int enrolled;
  final bool isActive;
  final String branchId;
  final String sessionId;
  final String? teacherId;
  final String? teacherName;
  final String? branchName;
  final String? sessionName;

  double get ratio => capacity <= 0 ? 0 : (enrolled / capacity).clamp(0, 1).toDouble();
  int get percent => (ratio * 100).round();
  bool get isFull => capacity > 0 && enrolled >= capacity;
  bool get isNearFull => !isFull && capacity > 0 && ratio >= 0.8;
  int get available => capacity - enrolled > 0 ? capacity - enrolled : 0;

  String get statusLabel => isFull ? 'ممتلئ' : (isNearFull ? 'قريب من الامتلاء' : 'متاح');

  /// Builds a record from a `classes` row, using lookup maps for the joined
  /// names and the active-student counts.
  factory SaiClass.fromRow(
    Map<String, dynamic> row, {
    required Map<String, int> enrolledByClass,
    Map<String, String> teacherNames = const {},
    Map<String, String> branchNames = const {},
    Map<String, String> sessionNames = const {},
  }) {
    final id = row['id'] as String;
    final rawName = (row['name'] as String?)?.trim() ?? '';
    final rawProgram = (row['program'] as String?)?.trim() ?? '';
    final teacherId = row['teacher_id'] as String?;
    return SaiClass(
      id: id,
      name: rawName.isEmpty ? 'صف بدون اسم' : rawName,
      program: rawProgram.isEmpty ? 'غير محدد' : rawProgram,
      capacity: (row['capacity'] as num?)?.toInt() ?? 0,
      enrolled: enrolledByClass[id] ?? 0,
      isActive: row['is_active'] != false,
      branchId: (row['branch_id'] as String?) ?? '',
      sessionId: (row['session_id'] as String?) ?? '',
      teacherId: teacherId,
      teacherName: teacherId == null ? null : teacherNames[teacherId],
      branchName: branchNames[row['branch_id'] as String?],
      sessionName: sessionNames[row['session_id'] as String?],
    );
  }
}