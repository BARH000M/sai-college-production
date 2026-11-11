import 'app_role.dart';

class AppIdentity {
  const AppIdentity({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.roles,
  });

  final String userId;
  final String fullName;
  final String email;
  final List<AppRole> roles;
}
