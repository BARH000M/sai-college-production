import '../../routing/app_role.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../auth/profile.dart';

class AccountPage extends StatelessWidget {
  const AccountPage(
      {super.key, required this.profile, required this.onSignOut});
  final Profile profile;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                CircleAvatar(
                    radius: 26,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                        profile.fullName.isEmpty
                            ? 'م'
                            : profile.fullName.substring(0, 1),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20))),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(profile.fullName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(resolveRole(profile).label,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ])),
              ]))),
      const SizedBox(height: 12),
      Card(
          child: Column(children: [
        ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('البريد', style: TextStyle(fontSize: 13)),
            subtitle:
                Text(profile.email, style: const TextStyle(fontSize: 12))),
        const Divider(height: 1),
        ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('حالة الحساب', style: TextStyle(fontSize: 13)),
            subtitle: Text(profile.active ? 'نشط' : 'موقوف',
                style: const TextStyle(fontSize: 12))),
      ])),
      const SizedBox(height: 20),
      OutlinedButton.icon(
          onPressed: () => unawaited(onSignOut()),
          icon: const Icon(Icons.logout),
          label: const Text('تسجيل الخروج'),
          style:
              OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46))),
    ]);
  }
}
