/// Unit tests for [RoleGuard] and [PermissionDeniedException].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/permissions/role_guard.dart';
import 'package:house_booking/data/models/user_model.dart';

UserModel _user(String role) => UserModel(
      id: 1,
      name: 'test',
      email: 't@e.st',
      passwordHash: '',
      phone: '',
      avatarPath: '',
      role: role,
    );

void main() {
  group('RoleGuard.canHost', () {
    test('admin has host access', () {
      expect(RoleGuard.canHost(_user('admin')), isTrue);
    });

    test('host has host access', () {
      expect(RoleGuard.canHost(_user('host')), isTrue);
    });

    test('guest denied', () {
      expect(RoleGuard.canHost(_user('guest')), isFalse);
    });

    test('operator (Phase 01: guest with delegation) denied at auth layer', () {
      // Phase 01 gates on auth role only; operator persona (role='guest' with
      // active delegation) is not yet distinguished. Phase 03 upgrades this.
      expect(RoleGuard.canHost(_user('guest')), isFalse);
    });

    test('null user denied', () {
      expect(RoleGuard.canHost(null), isFalse);
    });

    test('unknown role denied', () {
      expect(RoleGuard.canHost(_user('super_admin')), isFalse);
    });
  });

  group('RoleGuard.canAdmin', () {
    test('admin has admin access', () {
      expect(RoleGuard.canAdmin(_user('admin')), isTrue);
    });

    test('host denied admin', () {
      expect(RoleGuard.canAdmin(_user('host')), isFalse);
    });

    test('guest denied admin', () {
      expect(RoleGuard.canAdmin(_user('guest')), isFalse);
    });

    test('null user denied admin', () {
      expect(RoleGuard.canAdmin(null), isFalse);
    });
  });

  group('PermissionDeniedException', () {
    test('carries action and required role', () {
      const e = PermissionDeniedException(
        action: 'deleteHouse',
        requiredRole: 'host',
        actualRole: 'guest',
      );
      expect(e.action, equals('deleteHouse'));
      expect(e.requiredRole, equals('host'));
      expect(e.actualRole, equals('guest'));
      expect(e.toString(), contains('deleteHouse'));
      expect(e.toString(), contains('host'));
      expect(e.toString(), contains('guest'));
    });

    test('anonymous when actualRole omitted', () {
      const e = PermissionDeniedException(
        action: 'deleteHouse',
        requiredRole: 'host',
      );
      expect(e.toString(), contains('anonymous'));
    });
  });
}
