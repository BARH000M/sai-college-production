import '../app_identity.dart';
import '../app_role.dart';

/// Role groupings used across the application.
///
/// These mirror the role declarations in `core/feature_catalog.dart` and the
/// hidden-button rules already used by the working screens, so the client stays
/// consistent with itself. They are a UI convenience only: every capability is
/// still enforced by row level security in Supabase, which remains
/// authoritative. A capability returning true never grants data access on its
/// own.
abstract final class RoleGroups {
  /// Roles holding a staff workspace.
  static const Set<AppRole> staff = {
    AppRole.superAdmin,
    AppRole.admin,
    AppRole.teacher,
    AppRole.accountant,
    AppRole.receptionist,
    AppRole.librarian,
    AppRole.contentEditor,
  };

  /// Roles that own or are attached to a learner record.
  static const Set<AppRole> learners = {AppRole.student, AppRole.parent};

  /// Roles allowed to create and edit classes.
  static const Set<AppRole> classManagers = {AppRole.superAdmin, AppRole.admin};

  /// Roles allowed to mark attendance.
  static const Set<AppRole> attendanceMarkers = {
    AppRole.superAdmin,
    AppRole.admin,
    AppRole.teacher,
    AppRole.receptionist,
  };

  /// Roles allowed to import students and link guardians.
  static const Set<AppRole> studentManagers = {
    AppRole.superAdmin,
    AppRole.admin,
    AppRole.receptionist,
  };

  /// Roles allowed to work the admissions pipeline.
  static const Set<AppRole> admissionsStaff = {
    AppRole.superAdmin,
    AppRole.admin,
    AppRole.receptionist,
  };

  /// Roles allowed to read fee, payment and refund records.
  static const Set<AppRole> financeReaders = {
    AppRole.superAdmin,
    AppRole.admin,
    AppRole.accountant,
    AppRole.student,
    AppRole.parent,
  };

  /// Roles allowed to use the library catalogue and circulation.
  static const Set<AppRole> libraryUsers = {
    AppRole.superAdmin,
    AppRole.admin,
    AppRole.librarian,
    AppRole.teacher,
    AppRole.student,
    AppRole.parent,
  };

  /// Roles allowed to author learning content.
  static const Set<AppRole> contentAuthors = {
    AppRole.superAdmin,
    AppRole.admin,
    AppRole.contentEditor,
    AppRole.teacher,
  };

  /// Roles allowed to administer branches and academic sessions.
  static const Set<AppRole> branchAdministrators = {
    AppRole.superAdmin,
    AppRole.admin,
  };

  /// Roles allowed to change another account's roles.
  ///
  /// The web portal routes this through the `manage-roles` edge function; the
  /// mobile application stays read-only for role assignment on purpose.
  static const Set<AppRole> roleManagers = {AppRole.superAdmin};
}

/// Capability checks for the roles an account actually holds.
///
/// A multi-role account receives the union: any held role satisfying a check
/// makes that check true.
final class SaiPermissions {
  const SaiPermissions(this._roles);

  /// Builds the checks from a loaded identity.
  factory SaiPermissions.of(AppIdentity identity) =>
      SaiPermissions(identity.roles.toSet());

  /// Builds the checks from a raw role list.
  factory SaiPermissions.fromRoles(Iterable<AppRole> roles) =>
      SaiPermissions(roles.toSet());

  final Set<AppRole> _roles;

  /// The roles this instance was built from.
  Set<AppRole> get roles => Set<AppRole>.unmodifiable(_roles);

  bool _matches(Set<AppRole> allowed) => _roles.any(allowed.contains);

  bool get isStaff => _matches(RoleGroups.staff);

  bool get isLearner => _matches(RoleGroups.learners);

  bool get hasMultipleRoles => _roles.length > 1;

  bool get canManageClasses => _matches(RoleGroups.classManagers);

  bool get canMarkAttendance => _matches(RoleGroups.attendanceMarkers);

  bool get canManageStudents => _matches(RoleGroups.studentManagers);

  bool get canManageAdmissions => _matches(RoleGroups.admissionsStaff);

  bool get canReadFinance => _matches(RoleGroups.financeReaders);

  bool get canUseLibrary => _matches(RoleGroups.libraryUsers);

  bool get canAuthorContent => _matches(RoleGroups.contentAuthors);

  bool get canManageBranches => _matches(RoleGroups.branchAdministrators);

  bool get canManageRoles => _matches(RoleGroups.roleManagers);

  /// True when the account has its own learner record to show (student) or a
  /// verified guardian link to read (parent).
  bool get canReadOwnLearnerData => isLearner;
}