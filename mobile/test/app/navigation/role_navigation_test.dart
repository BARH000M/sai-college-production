import 'package:flutter_test/flutter_test.dart';
import 'package:sai_college_mobile/app/navigation/role_navigation.dart';
import 'package:sai_college_mobile/core/app_role.dart';

List<String> slotIdsFor(AppRole role) =>
    RoleNavigation.slotsFor(role).map((slot) => slot.id).toList();

void main() {
  group('RoleNavigation — single role', () {
    test('delegates to the shared navigation definition', () {
      for (final role in AppRole.values) {
        expect(slotIdsFor(role), navSlotsFor(role).map((slot) => slot.id).toList());
      }
    });

    test('every role exposes home and the more destination', () {
      for (final role in AppRole.values) {
        final ids = slotIdsFor(role).toSet();
        expect(ids, contains('home'), reason: 'missing home for ${role.name}');
        expect(ids, contains('more'), reason: 'missing more for ${role.name}');
      }
    });

    test('slot ids are unique inside a role', () {
      for (final role in AppRole.values) {
        final ids = slotIdsFor(role);
        expect(ids.toSet().length, ids.length, reason: 'duplicate slot for ${role.name}');
      }
    });
  });

  group('RoleNavigation — multi role union', () {
    test('union has no duplicate destinations', () {
      final ids = RoleNavigation.slotsForRoles(
        const [AppRole.teacher, AppRole.receptionist],
      ).map((slot) => slot.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('union keeps destinations from both roles', () {
      final ids = RoleNavigation.slotsForRoles(
        const [AppRole.accountant, AppRole.librarian],
      ).map((slot) => slot.id).toSet();
      expect(ids, containsAll(<String>{'finance', 'library'}));
    });

    test('canReach reports availability across the held roles', () {
      expect(RoleNavigation.canReach(const [AppRole.student], 'courses'), isTrue);
      expect(RoleNavigation.canReach(const [AppRole.student], 'finance'), isFalse);
      expect(
        RoleNavigation.canReach(const [AppRole.student, AppRole.parent], 'children'),
        isTrue,
      );
    });

    test('an empty role list reaches nothing', () {
      expect(RoleNavigation.slotsForRoles(const <AppRole>[]), isEmpty);
      expect(RoleNavigation.canReach(const <AppRole>[], 'home'), isFalse);
    });
  });
}