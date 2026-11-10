import 'package:supabase_flutter/supabase_flutter.dart';
import '../security/sai_role.dart';

/// Read-only role lookup; never allows client-side role assignment.
class SaiRoleRepository {
  const SaiRoleRepository(this.client);
  final SupabaseClient client;

  Future<Set<SaiRole>> currentRoles() async {
    final user = client.auth.currentUser;
    if (user == null) return const {};
    final rows = await client.from('user_roles')
        .select('role').eq('user_id', user.id);
    return rows.map((row) => SaiRole.parse(row['role'] as String))
        .whereType<SaiRole>().toSet();
  }
}
