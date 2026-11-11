import 'package:flutter/material.dart';

import '../../core/app_identity.dart';
import '../../core/app_role.dart';
import '../../core/sai_theme.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.identity, required this.activeRole, required this.onSignOut});

  final AppIdentity identity;
  final AppRole activeRole;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
      children: [
        Text('حسابي', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: SaiColors.navy)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFFFE9EC),
                  foregroundColor: SaiColors.red,
                  child: Text(identity.fullName.trim().isEmpty ? 'س' : identity.fullName.trim()[0], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(identity.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                      const SizedBox(height: 3),
                      Text(identity.email, textDirection: TextDirection.ltr, style: const TextStyle(color: SaiColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text('الأدوار المسندة', style: TextStyle(fontWeight: FontWeight.w700, color: SaiColors.navy)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: identity.roles.map((role) => Chip(
                avatar: Icon(role == activeRole ? Icons.verified : Icons.person_outline, size: 18, color: role == activeRole ? SaiColors.red : SaiColors.muted),
                label: Text(role.label),
                backgroundColor: role == activeRole ? const Color(0xFFFFE9EC) : Colors.white,
                side: const BorderSide(color: SaiColors.border),
              )).toList(),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => onSignOut(),
          icon: const Icon(Icons.logout, color: SaiColors.red),
          label: const Text('تسجيل الخروج', style: TextStyle(color: SaiColors.red)),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), side: const BorderSide(color: SaiColors.border)),
        ),
      ],
    );
  }
}
