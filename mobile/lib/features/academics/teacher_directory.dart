import 'package:supabase_flutter/supabase_flutter.dart';

/// A teacher account as returned by the account-management edge function.
class TeacherOption {
  const TeacherOption({required this.userId, required this.fullName, required this.email});

  final String userId;
  final String fullName;
  final String email;

  String get displayName => fullName.trim().isEmpty ? email : fullName.trim();
}

/// Reads the teacher directory through the existing account-management edge
/// function, because `profiles` is only readable by its owner in the database.
/// A restricted account simply receives an empty list instead of an exception.
Future<List<TeacherOption>> loadTeacherDirectory(SupabaseClient client) async {
  try {
    final response = await client.functions.invoke(
      'provision-learning-account',
      body: {'action': 'teacher-overview'},
    );
    final data = response.data;
    if (data is! Map) return const <TeacherOption>[];
    final raw = data['teachers'];
    if (raw is! List) return const <TeacherOption>[];
    final teachers = <TeacherOption>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final userId = entry['userId']?.toString();
      if (userId == null || userId.isEmpty) continue;
      teachers.add(TeacherOption(
        userId: userId,
        fullName: (entry['fullName'] as String?)?.trim() ?? '',
        email: (entry['email'] as String?)?.trim() ?? '',
      ));
    }
    teachers.sort((a, b) => a.displayName.compareTo(b.displayName));
    return teachers;
  } catch (_) {
    return const <TeacherOption>[];
  }
}

Future<Map<String, String>> loadTeacherNames(SupabaseClient client) async {
  final teachers = await loadTeacherDirectory(client);
  return {for (final teacher in teachers) teacher.userId: teacher.displayName};
}