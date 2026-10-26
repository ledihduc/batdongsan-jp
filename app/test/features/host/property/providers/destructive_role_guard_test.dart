/// Provider-layer defense-in-depth tests: destructive methods throw
/// [PermissionDeniedException] when called with a non-host actor.
///
/// Phase 01 wired an optional `actor:` param on:
/// - BuildingProvider.deleteBuilding
/// - HouseProvider.deleteHouse
/// - ContractProvider.terminateContract
/// - ContractProvider.transferRoom
///
/// The role check runs before any repository call, so tests do not need
/// network mocking — the guard rejects the call synchronously.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/permissions/role_guard.dart';
import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/features/host/property/providers/contract_provider.dart';
import 'package:house_booking/providers/house_provider.dart';

UserModel _user(String role) => UserModel(
      id: 42,
      name: 'test',
      email: 't@e.st',
      passwordHash: '',
      phone: '',
      avatarPath: '',
      role: role,
    );

void main() {
  group('BuildingProvider.deleteBuilding', () {
    test('throws PermissionDeniedException for guest actor', () {
      final provider = BuildingProvider();
      expect(
        () => provider.deleteBuilding(1, actor: _user('guest')),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('does not throw at guard when actor is null (legacy caller)', () {
      // Backward compat: existing call sites without actor param are not
      // guard-checked at the provider layer. UI guard remains authoritative.
      final provider = BuildingProvider();
      expect(
        () => provider.deleteBuilding(1, actor: null),
        returnsNormally,
      );
    });
  });

  group('HouseProvider.deleteHouse', () {
    test('throws PermissionDeniedException for guest actor', () {
      final provider = HouseProvider();
      expect(
        () => provider.deleteHouse(1, actor: _user('guest')),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('permits host actor at guard (repo call not tested here)', () {
      // Host reaches the repo call — we can't reliably assert without HTTP.
      // The important behavior — synchronous guard rejects non-host — is
      // covered above.
      final provider = HouseProvider();
      // Should not throw at the guard step. It may hit repo/network which is
      // out of scope; wrap in try to allow either normal or ApiException.
      expect(
        () => provider.deleteHouse(1, actor: _user('host')),
        returnsNormally,
      );
    });
  });

  group('ContractProvider.terminateContract', () {
    test('throws PermissionDeniedException for guest actor', () {
      final provider = ContractProvider();
      expect(
        () => provider.terminateContract(
          1,
          actualEndDate: '2026-07-02',
          actor: _user('guest'),
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('ContractProvider.transferRoom', () {
    test('throws PermissionDeniedException for guest actor', () {
      final provider = ContractProvider();
      expect(
        () => provider.transferRoom(1, 2, actor: _user('guest')),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });
}
