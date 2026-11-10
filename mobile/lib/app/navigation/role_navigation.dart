import 'package:sai_college_mobile/core/app_nav.dart';
import 'package:sai_college_mobile/core/app_role.dart';

/// Re-exported so new code can depend on `app/navigation/` while the existing
/// implementation stays where it is. Phase 1 is additive: nothing is moved.
export 'package:sai_college_mobile/core/app_nav.dart';

/// Role-aware navigation helpers.
///
/// `navSlotsFor` answers "what does this role see". A multi-role account needs
/// one more thing — the union of its roles without duplicate destinations — and
/// that is what [slotsForRoles] provides.
abstract final class RoleNavigation {
  /// Destinations for a single active role.
  static List<NavSlot> slotsFor(AppRole role) => navSlotsFor(role);

  /// Destinations for the union of several roles, in the order the roles are
  /// given, with each destination appearing once (first holder wins).
  static List<NavSlot> slotsForRoles(Iterable<AppRole> roles) {
    final seen = <String>{};
    final slots = <NavSlot>[];
    for (final role in roles) {
      for (final slot in navSlotsFor(role)) {
        if (seen.add(slot.id)) slots.add(slot);
      }
    }
    return slots;
  }

  /// True when any held role exposes the destination.
  static bool canReach(Iterable<AppRole> roles, String slotId) {
    return roles.any(
      (role) => navSlotsFor(role).any((slot) => slot.id == slotId),
    );
  }
}