import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/roles.dart';
/// Queries target the versioned public tables in migrations/001_initial_schema.sql.
/// RLS, not Flutter navigation, is the security boundary.
class SaiRepository {
 SaiRepository(this.db); final SupabaseClient db;
 Future<Set<AppRole>> roles(String userId) async {
  final rows=await db.from('user_roles').select('role').eq('user_id',userId);
  return {for(final row in rows) if(RoleText.parse(row['role'].toString()) case final AppRole r) r};
 }
 Future<Map<String,dynamic>?> profile(String userId) async => await db.from('profiles').select('id,full_name,email').eq('id',userId).maybeSingle();
 Future<List<Map<String,dynamic>>> classes() async => (await db.from('classes').select('id,name,program,capacity,branch_id,session_id,teacher_id').order('name')).cast<Map<String,dynamic>>();
 Future<List<Map<String,dynamic>>> students({String? classId}) async {
  var q=db.from('students').select('id,full_name,admission_no,class_id,status');
  if(classId!=null)q=q.eq('class_id',classId);
  return (await q.order('full_name')).cast<Map<String,dynamic>>();
 }
 Future<List<Map<String,dynamic>>> branches() async => (await db.from('branches').select('id,name,code').eq('is_active',true).order('name')).cast<Map<String,dynamic>>();
 Future<List<Map<String,dynamic>>> sessions() async => (await db.from('academic_sessions').select('id,name').eq('is_active',true)).cast<Map<String,dynamic>>();
 Future<List<Map<String,dynamic>>> attendanceClasses() async => (await db.rpc('sai_attendance_classes') as List).cast<Map<String,dynamic>>();
 Future<List<Map<String,dynamic>>> attendanceSessions(String classId) async => (await db.from('attendance_sessions').select('id,class_id,attendance_date,status').eq('class_id',classId).order('attendance_date',ascending:false)).cast<Map<String,dynamic>>();
 Future<List<Map<String,dynamic>>> attendanceRoster(String sessionId) async => (await db.rpc('sai_attendance_roster',params:{'wanted_session':sessionId}) as List).cast<Map<String,dynamic>>();
 Future<void> markAttendance({required String sessionId,required String studentId,required String status,String? recordId}) async {
  if(recordId==null){await db.from('attendance_records').insert({'attendance_session_id':sessionId,'student_id':studentId,'status':status});}
  else {await db.from('attendance_records').update({'status':status}).eq('id',recordId);}
 }
}
