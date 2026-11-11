import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/access.dart';

const backendUrl = 'https://aeryusbrulqdxjdynwfh.supabase.co';
const previewMode = bool.fromEnvironment('SAI_PREVIEW', defaultValue: false);
const publicKey = String.fromEnvironment('SUPABASE_PUBLIC_KEY');

class Account {
  const Account(this.name, this.roles, this.email);
  final String name, email;
  final Set<Role> roles;
}

class Repository {
  SupabaseClient get client => Supabase.instance.client;
  Future<Account> account() async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('انتهت الجلسة. يرجى تسجيل الدخول.');
    }
    final profile = await client
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .maybeSingle();
    final rows = await client
        .from('user_roles')
        .select('role')
        .eq('user_id', user.id);
    return Account(
      (profile?['full_name'] as String?) ?? user.email ?? '',
      Access.parse(rows.map((r) => r['role'] as String)),
      user.email ?? '',
    );
  }

  Future<List<Map<String, dynamic>>> classes() async => await client
      .from('classes')
      .select('id,name,program,capacity')
      .order('name');
  Future<List<Map<String, dynamic>>> students(String classId) async =>
      await client
          .from('students')
          .select('id,full_name,admission_no')
          .eq('class_id', classId)
          .order('full_name');
}
