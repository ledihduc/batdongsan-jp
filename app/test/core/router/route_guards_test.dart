/// Router guard unit tests — verify each guard's decision matrix per
/// docs/role-model.md access matrix.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/models/displayed_role.dart';
import 'package:house_booking/core/router/route_guards.dart';

void main() {
  group('guardHostRoutes', () {
    test('non-/host location → null (guard skips)', () {
      expect(
        guardHostRoutes(
          location: '/',
          role: DisplayedRole.guest,
          isAuthenticated: false,
        ),
        isNull,
      );
      expect(
        guardHostRoutes(
          location: '/operator',
          role: DisplayedRole.host,
          isAuthenticated: true,
        ),
        isNull,
      );
    });

    test('/host + unauthenticated → /login', () {
      expect(
        guardHostRoutes(
          location: '/host',
          role: DisplayedRole.guest,
          isAuthenticated: false,
        ),
        '/login',
      );
    });

    test('/host + guest role → /', () {
      expect(
        guardHostRoutes(
          location: '/host/analytics',
          role: DisplayedRole.guest,
          isAuthenticated: true,
        ),
        '/',
      );
    });

    test('/host + host role → null', () {
      expect(
        guardHostRoutes(
          location: '/host',
          role: DisplayedRole.host,
          isAuthenticated: true,
        ),
        isNull,
      );
    });

    test('/host + admin role → null (admin inherits host access)', () {
      expect(
        guardHostRoutes(
          location: '/host/analytics',
          role: DisplayedRole.admin,
          isAuthenticated: true,
        ),
        isNull,
      );
    });

    test('/host + operator role → / (operator is not host)', () {
      expect(
        guardHostRoutes(
          location: '/host',
          role: DisplayedRole.operator_,
          isAuthenticated: true,
        ),
        '/',
      );
    });

    test('/hostess (adjacent prefix) → null (no false-match)', () {
      expect(
        guardHostRoutes(
          location: '/hostess',
          role: DisplayedRole.guest,
          isAuthenticated: false,
        ),
        isNull,
      );
    });
  });

  group('guardAdminRoutes', () {
    test('/admin + admin → null', () {
      expect(
        guardAdminRoutes(
          location: '/admin',
          role: DisplayedRole.admin,
          isAuthenticated: true,
        ),
        isNull,
      );
    });

    test('/admin + host → /', () {
      expect(
        guardAdminRoutes(
          location: '/admin',
          role: DisplayedRole.host,
          isAuthenticated: true,
        ),
        '/',
      );
    });

    test('/admin + unauthenticated → /login', () {
      expect(
        guardAdminRoutes(
          location: '/admin',
          role: DisplayedRole.guest,
          isAuthenticated: false,
        ),
        '/login',
      );
    });

    test('/admin + operator (has delegation but not admin) → /', () {
      expect(
        guardAdminRoutes(
          location: '/admin/users',
          role: DisplayedRole.operator_,
          isAuthenticated: true,
        ),
        '/',
      );
    });
  });

  group('guardOperatorRoutes', () {
    test('/operator + operator_ → null', () {
      expect(
        guardOperatorRoutes(
          location: '/operator',
          role: DisplayedRole.operator_,
          isAuthenticated: true,
        ),
        isNull,
      );
    });

    test('/operator + host (no delegation) → /', () {
      expect(
        guardOperatorRoutes(
          location: '/operator/owner/123',
          role: DisplayedRole.host,
          isAuthenticated: true,
        ),
        '/',
      );
    });

    test('/operator + admin → / (admin does not act as operator by policy)', () {
      expect(
        guardOperatorRoutes(
          location: '/operator',
          role: DisplayedRole.admin,
          isAuthenticated: true,
        ),
        '/',
      );
    });

    test('/operator + unauthenticated → /login', () {
      expect(
        guardOperatorRoutes(
          location: '/operator',
          role: DisplayedRole.guest,
          isAuthenticated: false,
        ),
        '/login',
      );
    });
  });

  group('guardTenantRoutes', () {
    test('/tenant + tenant → null (once U2 lands)', () {
      expect(
        guardTenantRoutes(
          location: '/tenant',
          role: DisplayedRole.tenant,
          isAuthenticated: true,
        ),
        isNull,
      );
    });

    test('/tenant + guest → /', () {
      expect(
        guardTenantRoutes(
          location: '/tenant/report-unauthorized/abc',
          role: DisplayedRole.guest,
          isAuthenticated: true,
        ),
        '/',
      );
    });

    test('/tenant + unauthenticated → /login', () {
      expect(
        guardTenantRoutes(
          location: '/tenant',
          role: DisplayedRole.guest,
          isAuthenticated: false,
        ),
        '/login',
      );
    });
  });

  group('defaultHomeFor', () {
    test('maps each role to its home', () {
      expect(defaultHomeFor(DisplayedRole.admin), '/admin');
      expect(defaultHomeFor(DisplayedRole.operator_), '/operator');
      expect(defaultHomeFor(DisplayedRole.tenant), '/tenant');
      expect(defaultHomeFor(DisplayedRole.host), '/');
      expect(defaultHomeFor(DisplayedRole.guest), '/');
    });
  });
}
