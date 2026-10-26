/// Unit tests for ActorContextProvider — state transitions, persistence rules.
///
/// Critical invariant: state is NEVER persisted (AC-15, NFR-07).
/// Tests cover: enter context, clear, refresh, notification on changes.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/operator_delegation_model.dart';
import 'package:house_booking/providers/actor_context_provider.dart';

// Helpers
OperatorDelegationModel _makeDelegation({
  String id = 'deleg-001',
  String ownerUserId = 'owner-1',
  String ownerName = 'Nguyễn Văn A',
  DelegationStatus status = DelegationStatus.active,
}) {
  return OperatorDelegationModel(
    id: id,
    ownerUserId: ownerUserId,
    operatorUserId: 'operator-1',
    rolePreset: DelegationRolePreset.operatorFull,
    status: status,
    createdAt: DateTime(2026, 1, 1),
    ownerName: ownerName,
  );
}

void main() {
  group('ActorContextProvider — initial state', () {
    late ActorContextProvider provider;

    setUp(() => provider = ActorContextProvider());
    tearDown(() => provider.dispose());

    test('starts with no active delegation context', () {
      expect(provider.currentDelegation, isNull);
      expect(provider.currentDelegationId, isNull);
      expect(provider.isActingAs, isFalse);
    });

    test('actingAsOwnerName returns default when no context', () {
      expect(provider.actingAsOwnerName, equals('Chủ nhà'));
    });
  });

  group('ActorContextProvider — enterContext', () {
    late ActorContextProvider provider;

    setUp(() => provider = ActorContextProvider());
    tearDown(() => provider.dispose());

    test('sets currentDelegation after enterContext', () {
      final delegation = _makeDelegation();
      provider.enterContext(delegation);

      expect(provider.currentDelegation, equals(delegation));
      expect(provider.currentDelegationId, equals('deleg-001'));
      expect(provider.isActingAs, isTrue);
    });

    test('actingAsOwnerName returns owner name after enterContext', () {
      final delegation = _makeDelegation(ownerName: 'Trần Thị B');
      provider.enterContext(delegation);

      expect(provider.actingAsOwnerName, equals('Trần Thị B'));
    });

    test('enterContext notifies listeners', () {
      var notified = false;
      provider.addListener(() => notified = true);
      provider.enterContext(_makeDelegation());

      expect(notified, isTrue);
    });

    test('enterContext replaces previous context', () {
      provider.enterContext(_makeDelegation(id: 'deleg-001'));
      provider.enterContext(_makeDelegation(id: 'deleg-002'));

      expect(provider.currentDelegationId, equals('deleg-002'));
    });
  });

  group('ActorContextProvider — clear', () {
    late ActorContextProvider provider;

    setUp(() => provider = ActorContextProvider());
    tearDown(() => provider.dispose());

    test('clear removes active delegation', () {
      provider.enterContext(_makeDelegation());
      provider.clear();

      expect(provider.currentDelegation, isNull);
      expect(provider.currentDelegationId, isNull);
      expect(provider.isActingAs, isFalse);
    });

    test('clear notifies listeners when context was set', () {
      provider.enterContext(_makeDelegation());
      var notified = false;
      provider.addListener(() => notified = true);
      provider.clear();

      expect(notified, isTrue);
    });

    test('clear is a no-op when no context — does NOT notify', () {
      // No context set, clear should do nothing
      var notified = false;
      provider.addListener(() => notified = true);
      provider.clear();

      expect(notified, isFalse);
    });
  });

  group('ActorContextProvider — refresh', () {
    late ActorContextProvider provider;

    setUp(() => provider = ActorContextProvider());
    tearDown(() => provider.dispose());

    test('refresh updates currentDelegation when IDs match', () {
      final original = _makeDelegation(id: 'deleg-001');
      provider.enterContext(original);

      final updated = _makeDelegation(
        id: 'deleg-001',
        ownerName: 'Cập nhật Tên',
        status: DelegationStatus.paused,
      );
      provider.refresh(updated);

      expect(provider.currentDelegation?.status, equals(DelegationStatus.paused));
      expect(provider.actingAsOwnerName, equals('Cập nhật Tên'));
    });

    test('refresh is a no-op when IDs do not match', () {
      final original = _makeDelegation(id: 'deleg-001');
      provider.enterContext(original);

      final different = _makeDelegation(id: 'deleg-999');
      provider.refresh(different);

      // Still points to original
      expect(provider.currentDelegationId, equals('deleg-001'));
    });

    test('refresh notifies listeners when ID matches', () {
      provider.enterContext(_makeDelegation(id: 'deleg-001'));
      var notified = false;
      provider.addListener(() => notified = true);

      provider.refresh(_makeDelegation(id: 'deleg-001'));
      expect(notified, isTrue);
    });
  });

  group('ActorContextProvider — persistence (AC-15, NFR-07)', () {
    test('new instance has no context — simulates cold start', () {
      // Each new ActorContextProvider starts clean.
      // This is the key invariant: no SharedPreferences / SecureStorage.
      final provider1 = ActorContextProvider();
      provider1.enterContext(_makeDelegation());
      expect(provider1.isActingAs, isTrue);
      provider1.dispose();

      // New instance = cold start simulation
      final provider2 = ActorContextProvider();
      expect(provider2.isActingAs, isFalse,
          reason:
              'ActorContextProvider must NOT persist across instances — simulates app cold start (AC-15, NFR-07)');
      provider2.dispose();
    });
  });
}
