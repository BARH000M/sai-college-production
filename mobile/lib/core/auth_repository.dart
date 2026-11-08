import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_identity.dart';
import 'app_role.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;
  User? get currentUser => _client.auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'saicollege://auth/callback',
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<AppIdentity> loadIdentity(User user) async {
    final profile = await _client
        .from('profiles')
        .select('id, full_name, email')
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) {
      throw const IdentityLoadException(
        'لا يوجد ملف مستخدم مرتبط بهذا الحساب. تواصل مع إدارة الكلية.',
      );
    }

    final roleRows = await _client
        .from('user_roles')
        .select('role')
        .eq('user_id', user.id);

    final roles = roleRows
        .map((row) => parseAppRole(row['role']))
        .whereType<AppRole>()
        .toSet()
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    if (roles.isEmpty) {
      throw const IdentityLoadException(
        'لا يوجد دور مسند لهذا الحساب. تواصل مع إدارة الكلية.',
      );
    }

    return AppIdentity(
      userId: user.id,
      fullName: (profile['full_name'] as String?)?.trim().isNotEmpty == true
          ? (profile['full_name'] as String).trim()
          : 'مستخدم ساي',
      email: (profile['email'] as String?) ?? user.email ?? '',
      roles: roles,
    );
  }
}

class IdentityLoadException implements Exception {
  const IdentityLoadException(this.message);
  final String message;
  @override
  String toString() => message;
}
