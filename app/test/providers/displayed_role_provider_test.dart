/// Unit tests for DisplayedRoleProvider.derive — the pure derivation matrix
/// from docs/role-model.md.
///
/// Provider wiring (ChangeNotifier listener glue) is exercised via the
/// integration path in main.dart; this file covers the priority rules.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/models/displayed_role.dart';
import 'package:house_booking/providers/displayed_role_provider.dart';

DisplayedRole _derive({
  String? role,
  bool delegation = false,
  bool tenant = false,
}) =>
    DisplayedRoleProvider.derive(
      authRole: role,
      hasActiveDelegation: delegation,
      hasTenantJwt: tenant,
    );

void main() {
  group('DisplayedRoleProvider.derive — role-model.md matrix', () {
    test('admin + any delegation + any tenant → admin (priority)', () {
      expect(_derive(role: 'admin'), DisplayedRole.admin);
      expect(_derive(role: 'admin', delegation: true), DisplayedRole.admin);
      expect(_derive(role: 'admin', tenant: true), DisplayedRole.admin);
      expect(
        _derive(role: 'admin', delegation: true, tenant: true),
        DisplayedRole.admin,
      );
    });

    test('host + active delegation → operator_ (delegation wins over host)', () {
      expect(
        _derive(role: 'host', delegation: true),
        DisplayedRole.operator_,
      );
      expect(
        _derive(role: 'host', delegation: true, tenant: true),
        DisplayedRole.operator_,
      );
    });

    test('host + no delegation → host', () {
      expect(_derive(role: 'host'), DisplayedRole.host);
      expect(_derive(role: 'host', tenant: true), DisplayedRole.host);
    });

    test('guest + active delegation → operator_', () {
      expect(
        _derive(role: 'guest', delegation: true),
        DisplayedRole.operator_,
      );
    });

    test('guest + no delegation + tenant JWT → tenant', () {
      expect(_derive(role: 'guest', tenant: true), DisplayedRole.tenant);
    });

    test('guest + no delegation + no tenant → guest', () {
      expect(_derive(role: 'guest'), DisplayedRole.guest);
    });

    test('null auth role → guest (unauthenticated)', () {
      expect(_derive(role: null), DisplayedRole.guest);
      expect(_derive(role: null, delegation: true), DisplayedRole.guest);
      expect(_derive(role: null, tenant: true), DisplayedRole.guest);
    });

    test('unknown role string → guest fallback', () {
      // Backend contract guarantees guest|host|admin; anything else is a
      // programming error but we degrade to guest to be safe.
      expect(_derive(role: 'operator'), DisplayedRole.guest);
      expect(_derive(role: 'tenant'), DisplayedRole.guest);
      expect(_derive(role: 'xxx'), DisplayedRole.guest);
    });
  });

  group('access getters on DisplayedRole enum', () {
    test('canAccessHost: host + admin only', () {
      expect(DisplayedRole.host.canAccessHost, isTrue);
      expect(DisplayedRole.admin.canAccessHost, isTrue);
      expect(DisplayedRole.operator_.canAccessHost, isFalse);
      expect(DisplayedRole.tenant.canAccessHost, isFalse);
      expect(DisplayedRole.guest.canAccessHost, isFalse);
    });

    test('canAccessAdmin: admin only', () {
      expect(DisplayedRole.admin.canAccessAdmin, isTrue);
      expect(DisplayedRole.host.canAccessAdmin, isFalse);
      expect(DisplayedRole.operator_.canAccessAdmin, isFalse);
      expect(DisplayedRole.tenant.canAccessAdmin, isFalse);
      expect(DisplayedRole.guest.canAccessAdmin, isFalse);
    });

    test('canAccessOperator: operator_ only', () {
      expect(DisplayedRole.operator_.canAccessOperator, isTrue);
      expect(DisplayedRole.admin.canAccessOperator, isFalse);
      expect(DisplayedRole.host.canAccessOperator, isFalse);
      expect(DisplayedRole.tenant.canAccessOperator, isFalse);
      expect(DisplayedRole.guest.canAccessOperator, isFalse);
    });

    test('canAccessTenant: tenant only', () {
      expect(DisplayedRole.tenant.canAccessTenant, isTrue);
      expect(DisplayedRole.admin.canAccessTenant, isFalse);
      expect(DisplayedRole.host.canAccessTenant, isFalse);
      expect(DisplayedRole.operator_.canAccessTenant, isFalse);
      expect(DisplayedRole.guest.canAccessTenant, isFalse);
    });
  });

  group('vietnameseLabel', () {
    test('returns expected Vietnamese labels', () {
      expect(DisplayedRole.admin.vietnameseLabel, 'Quản trị');
      expect(DisplayedRole.host.vietnameseLabel, 'Chủ nhà');
      expect(DisplayedRole.operator_.vietnameseLabel, 'Đại lý quản lý');
      expect(DisplayedRole.tenant.vietnameseLabel, 'Người thuê');
      expect(DisplayedRole.guest.vietnameseLabel, 'Khách thuê');
    });
  });
}
