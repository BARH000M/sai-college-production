import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase.dart';

class Profile {
  const Profile(
      {required this.id,
      required this.email,
      required this.fullName,
      required this.role,
      required this.active,
      this.teacherId,
      this.studentId,
      this.platformAdmin = false});
  final String id;
  final String email;
  final String fullName;
  final String role;
  final bool active;
  final int? teacherId;
  final int? studentId;
  final bool platformAdmin;

  factory Profile.fromRow(Map<String, dynamic> row) => Profile(
        id: row['id'] as String,
        email: (row['email'] as String?) ?? '',
        fullName: (row['full_name'] as String?) ?? 'مستخدم',
        role: (row['role'] as String?) ?? 'parent',
        active: row['active'] as bool? ?? true,
        teacherId: (row['teacher_id'] as num?)?.toInt(),
        studentId: (row['student_id'] as num?)?.toInt(),
        platformAdmin: row['platform_admin'] as bool? ?? false,
      );
}

Future<Profile?> loadProfile(User user) async {
  final row = await db
      .from('school_profiles')
      .select(
          'id, email, full_name, role, teacher_id, student_id, active, platform_admin')
      .eq('id', user.id)
      .maybeSingle();
  if (row == null) return null;
  return Profile.fromRow(row);
}
