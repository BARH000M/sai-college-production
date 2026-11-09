import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sai_college_mobile/design_system/design_system.dart';

import '../data/sai_repository.dart';
import '../models/roles.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.roles, required this.repo});

  final Set<AppRole> roles;
  final SaiRepository repo;

  @override
  Widget build(BuildContext context) {
    final user = repo.db.auth.currentUser;
    return SaiPageScaffold(
      title: 'حسابي',
      subtitle: user?.email,
      children: [
        if (user != null)
          FutureBuilder<Map<String, dynamic>?>(
            future: repo.profile(user.id),
            builder: (context, snapshot) => SaiListTile(
              title: snapshot.data?['full_name']?.toString() ?? 'المستخدم',
              subtitle: user.email,
              icon: Icons.account_circle_outlined,
            ),
          ),
        const SaiSectionTitle(
          title: 'صلاحيات الحساب',
          padding: EdgeInsetsDirectional.only(start: 2, top: 12, bottom: 8),
        ),
        for (final role in roles)
          SaiListTile(title: role.arabic, icon: Icons.verified_user_outlined),
        const SizedBox(height: 6),
        SaiListTile(
          title: 'تسجيل الخروج',
          icon: Icons.logout,
          accentColor: SaiColors.danger,
          onTap: () => Supabase.instance.client.auth.signOut(),
        ),
      ],
    );
  }
}