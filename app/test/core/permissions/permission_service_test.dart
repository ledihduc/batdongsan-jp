import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/permissions/fcm_service.dart';
import 'package:house_booking/core/permissions/permission_events.dart';
import 'package:house_booking/core/permissions/permission_install_id.dart';
import 'package:house_booking/core/permissions/permission_service.dart';
import 'package:house_booking/core/permissions/permission_storage.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import '../../helpers/mock_storage.dart';

/// Minimal fake FCM that records method calls without touching real Firebase.
class FakeFcmService extends Fake implements FcmService {
  final List<String> deletedTokenCalls = [];
  final List<({String userId, String installId})> registeredTokens = [];
  PrimingOutcome _requestPermissionOutcome = PrimingOutcome.osGrant;

  @override
  Future<bool> registerToken({
    required String userId,
    required String installId,
  }) async {
    registeredTokens.add((userId: userId, installId: installId));
    return true;
  }

  @override
  Future<void> deleteToken() async {
    deletedTokenCalls.add('deleteToken');
  }

  @override
  Future<bool> shouldShowApnsFallback(String userId) async => false;

  @override
  Future<void> markDelivered(String userId) async {}

  @override
  Future<PrimingOutcome> requestPermission({
    required UserRole role,
    required bool useProvisionalOnIos,
    String userId = '',
  }) async {
    return _requestPermissionOutcome;
  }

  @override
  Future<bool> checkProvisionalUpgrade() async => false;

  @override
  Future<bool> isWebAlreadyGranted() async => false;

  @override
  Future<String?> getToken() async => 'test-fcm-token-1234';

  @override
  Stream<String> get onTokenRefresh => Stream.empty();

  @override
  void detachUserContext() {
    // No-op for testing
  }

  @override
  Future<bool> unregisterToken({required String installId}) async {
    return true;
  }

  void setRequestPermissionOutcome(PrimingOutcome outcome) {
    _requestPermissionOutcome = outcome;
  }
}

/// In-memory event sink for testing.
class FakePermissionEventSink extends Fake implements PermissionEventSink {
  final List<PermissionEvent> events = [];

  @override
  Future<void> capture(PermissionEvent event) async {
    events.add(event);
  }

  @override
  Future<List<PermissionEvent>> drainPending() async => events;

  @override
  Future<void> clear(List<PermissionEvent> events) async {
    this.events.removeWhere((e) => events.contains(e));
  }
}

/// Minimal permission install ID provider.
class FakePermissionInstallId extends Fake implements PermissionInstallId {
  @override
  Future<String> get() async => 'test-install-uuid';
}

void main() {
  group('PermissionService', () {
    late MockFlutterSecureStorage mockStorage;
    late PermissionStorage storage;
    late FakeFcmService fakeFcm;
    late FakePermissionEventSink fakeEvents;
    late FakePermissionInstallId fakeInstallId;
    late PermissionService service;

    setUp(() {
      mockStorage = MockFlutterSecureStorage();
      storage = PermissionStorage(mockStorage);
      fakeFcm = FakeFcmService();
      fakeEvents = FakePermissionEventSink();
      fakeInstallId = FakePermissionInstallId();
      service = PermissionService(
        storage: storage,
        events: fakeEvents,
        fcm: fakeFcm,
        installId: fakeInstallId,
      );
    });

    // ────────────────────────────────────────────────────────────────────────
    group('shouldShowNotificationPriming', () {
      test('returns true for first-time user (no state)', () async {
        final result = await service.shouldShowNotificationPriming(
          'test-user-1',
          UserRole.guest,
        );
        expect(result, isTrue);
      });

      test('returns false when already granted and role unchanged', () async {
        // Write state with osGranted=true and role=guest
        var state = const PrimingState(osGranted: true);
        state = state.copyWith(lastShownForRole: UserRole.guest);
        await storage.write('test-user-1', PermissionKind.notification, state);

        // Call with same role
        final result = await service.shouldShowNotificationPriming(
          'test-user-1',
          UserRole.guest,
        );
        expect(result, isFalse);
      });

      test('returns true when granted but role changed (AC-N8)', () async {
        // Write state with osGranted=true and role=guest
        var state = const PrimingState(osGranted: true);
        state = state.copyWith(lastShownForRole: UserRole.guest);
        await storage.write('test-user-1', PermissionKind.notification, state);

        // Call with different role
        final result = await service.shouldShowNotificationPriming(
          'test-user-1',
          UserRole.host,
        );
        expect(result, isTrue);
      });

      test('returns false when in defer cooldown (7d not yet elapsed)',
          () async {
        // Write state with lastDeferAt = 5 days ago
        final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
        var state = const PrimingState();
        state = state.copyWith(lastDeferAt: fiveDaysAgo);
        await storage.write('test-user-1', PermissionKind.notification, state);

        final result = await service.shouldShowNotificationPriming(
          'test-user-1',
          UserRole.guest,
        );
        expect(result, isFalse);
      });

      test('returns true when defer cooldown elapsed (>7d)', () async {
        // Write state with lastDeferAt = 8 days ago
        final eightDaysAgo = DateTime.now().subtract(const Duration(days: 8));
        var state = const PrimingState();
        state = state.copyWith(lastDeferAt: eightDaysAgo);
        await storage.write('test-user-1', PermissionKind.notification, state);

        final result = await service.shouldShowNotificationPriming(
          'test-user-1',
          UserRole.guest,
        );
        expect(result, isTrue);
      });

      test('returns false when in deny cooldown (30d not yet elapsed)',
          () async {
        // Write state with lastDenyAt = 20 days ago
        final twentyDaysAgo = DateTime.now().subtract(const Duration(days: 20));
        var state = const PrimingState();
        state = state.copyWith(lastDenyAt: twentyDaysAgo);
        await storage.write('test-user-1', PermissionKind.notification, state);

        final result = await service.shouldShowNotificationPriming(
          'test-user-1',
          UserRole.guest,
        );
        expect(result, isFalse);
      });

      test('returns true when deny cooldown elapsed (>30d)', () async {
        // Write state with lastDenyAt = 31 days ago
        final thirtyoneDaysAgo =
            DateTime.now().subtract(const Duration(days: 31));
        var state = const PrimingState();
        state = state.copyWith(lastDenyAt: thirtyoneDaysAgo);
        await storage.write('test-user-1', PermissionKind.notification, state);

        final result = await service.shouldShowNotificationPriming(
          'test-user-1',
          UserRole.guest,
        );
        expect(result, isTrue);
      });

      test('returns false when osPermanentlyDenied (settings banner path)',
          () async {
        var state = const PrimingState(osPermanentlyDenied: true);
        await storage.write('test-user-1', PermissionKind.notification, state);

        final result = await service.shouldShowNotificationPriming(
          'test-user-1',
          UserRole.guest,
        );
        expect(result, isFalse);
      });
    });

    // ────────────────────────────────────────────────────────────────────────
    group('grantNotification', () {
      test('persists osGranted=true and lastShownForRole on osGrant outcome',
          () async {
        final result = await service.grantNotification(
          userId: 'test-user-1',
          role: UserRole.guest,
          useProvisionalIos: false,
        );

        expect(result, equals(PrimingOutcome.osGrant));

        final stored =
            await storage.read('test-user-1', PermissionKind.notification);
        expect(stored.osGranted, isTrue);
        expect(stored.lastShownForRole, equals(UserRole.guest));
      });

      test('persists osProvisional=true on iOS provisional outcome', () async {
        // Mock FCM to return provisional
        fakeFcm.setRequestPermissionOutcome(PrimingOutcome.osProvisional);

        service = PermissionService(
          storage: storage,
          events: fakeEvents,
          fcm: fakeFcm,
          installId: fakeInstallId,
        );

        final result = await service.grantNotification(
          userId: 'test-user-1',
          role: UserRole.guest,
          useProvisionalIos: true,
        );

        expect(result, equals(PrimingOutcome.osProvisional));

        final stored =
            await storage.read('test-user-1', PermissionKind.notification);
        expect(stored.osProvisional, isTrue);
      });

      test('persists osPermanentlyDenied=true on osPermDeny', () async {
        // Mock FCM to return permanently denied
        fakeFcm.setRequestPermissionOutcome(PrimingOutcome.osPermDeny);

        service = PermissionService(
          storage: storage,
          events: fakeEvents,
          fcm: fakeFcm,
          installId: fakeInstallId,
        );

        final result = await service.grantNotification(
          userId: 'test-user-1',
          role: UserRole.guest,
          useProvisionalIos: false,
        );

        expect(result, equals(PrimingOutcome.osPermDeny));

        final stored =
            await storage.read('test-user-1', PermissionKind.notification);
        expect(stored.osPermanentlyDenied, isTrue);
      });

      test('captures both accept event and osOutcome event in the sink',
          () async {
        final result = await service.grantNotification(
          userId: 'test-user-1',
          role: UserRole.guest,
          useProvisionalIos: false,
        );

        expect(result, equals(PrimingOutcome.osGrant));

        // Should have at least 2 events: accept + osGrant
        expect(fakeEvents.events.length, greaterThanOrEqualTo(2));

        final outcomes = fakeEvents.events.map((e) => e.outcome).toList();
        expect(outcomes, contains(PrimingOutcome.accept));
        expect(outcomes, contains(PrimingOutcome.osGrant));
      });
    });

    // ────────────────────────────────────────────────────────────────────────
    group('deferNotification', () {
      test('updates lastDeferAt + lastShownForRole and captures defer event',
          () async {
        await service.deferNotification('test-user-1', UserRole.guest);

        final stored =
            await storage.read('test-user-1', PermissionKind.notification);
        expect(stored.lastDeferAt, isNotNull);
        expect(stored.lastShownForRole, equals(UserRole.guest));

        final deferEvents = fakeEvents.events
            .where((e) => e.outcome == PrimingOutcome.defer)
            .toList();
        expect(deferEvents.length, greaterThan(0));
      });
    });

    // ────────────────────────────────────────────────────────────────────────
    group('shouldRetriggerOnRoleUpgrade', () {
      test('returns false when no state exists', () async {
        final result =
            await service.shouldRetriggerOnRoleUpgrade('test-user-1', UserRole.host);
        expect(result, isFalse);
      });

      test('returns true when previously granted for different role', () async {
        var state = const PrimingState(osGranted: true);
        state = state.copyWith(lastShownForRole: UserRole.guest);
        await storage.write('test-user-1', PermissionKind.notification, state);

        final result = await service.shouldRetriggerOnRoleUpgrade(
          'test-user-1',
          UserRole.host,
        );
        expect(result, isTrue);
      });

      test('returns false when osPermanentlyDenied (banner only path)',
          () async {
        var state = const PrimingState(
          osGranted: false,
          osPermanentlyDenied: true,
        );
        state = state.copyWith(lastShownForRole: UserRole.guest);
        await storage.write('test-user-1', PermissionKind.notification, state);

        final result = await service.shouldRetriggerOnRoleUpgrade(
          'test-user-1',
          UserRole.host,
        );
        expect(result, isFalse);
      });

      test('returns false when role unchanged', () async {
        var state = const PrimingState(osGranted: true);
        state = state.copyWith(lastShownForRole: UserRole.guest);
        await storage.write('test-user-1', PermissionKind.notification, state);

        final result = await service.shouldRetriggerOnRoleUpgrade(
          'test-user-1',
          UserRole.guest,
        );
        expect(result, isFalse);
      });
    });

    // ────────────────────────────────────────────────────────────────────────
    group('shouldShowCameraPriming', () {
      test('returns true for first call per context', () async {
        final result = await service.shouldShowCameraPriming(
          'test-user-1',
          CameraContext.cccdUpload,
        );
        expect(result, isTrue);
      });

      test('returns false on second call for same context (AC-C2)', () async {
        // First call
        final firstResult = await service.shouldShowCameraPriming(
          'test-user-1',
          CameraContext.cccdUpload,
        );
        expect(firstResult, isTrue);

        // Grant (marks as shown)
        await service.grantCamera(
          userId: 'test-user-1',
          context: CameraContext.cccdUpload,
        );

        // Second call should return false
        final secondResult = await service.shouldShowCameraPriming(
          'test-user-1',
          CameraContext.cccdUpload,
        );
        expect(secondResult, isFalse);
      });

      test('returns true for a DIFFERENT context even after first context is shown',
          () async {
        // Show and grant for cccdUpload
        await service.shouldShowCameraPriming(
          'test-user-1',
          CameraContext.cccdUpload,
        );
        await service.grantCamera(
          userId: 'test-user-1',
          context: CameraContext.cccdUpload,
        );

        // Check different context — should return true
        final result = await service.shouldShowCameraPriming(
          'test-user-1',
          CameraContext.postHousePhoto,
        );
        expect(result, isTrue);
      });
    });

    // ────────────────────────────────────────────────────────────────────────
    group('onLogout', () {
      test('calls fcm.deleteToken and clears storage for that user', () async {
        // Write some state first
        var state = const PrimingState(osGranted: true);
        await storage.write('test-user-1', PermissionKind.notification, state);
        await storage.write('test-user-2', PermissionKind.notification, state);

        // Logout user-1
        await service.onLogout('test-user-1');

        // Check user-1 is cleared
        final user1State =
            await storage.read('test-user-1', PermissionKind.notification);
        expect(user1State.osGranted, isFalse);
        expect(user1State.lastShownAt, isNull);

        // Check user-2 is NOT touched
        final user2State =
            await storage.read('test-user-2', PermissionKind.notification);
        expect(user2State.osGranted, isTrue);

        // Verify deleteToken was called
        expect(fakeFcm.deletedTokenCalls.length, greaterThan(0));
      });

      test('does not touch state for other users (AC-N7)', () async {
        // Write state for two users
        var state = const PrimingState(osGranted: true);
        state = state.copyWith(lastShownForRole: UserRole.guest);
        await storage.write('user-a', PermissionKind.notification, state);

        state = const PrimingState(osGranted: false);
        state = state.copyWith(lastShownForRole: UserRole.host);
        await storage.write('user-b', PermissionKind.notification, state);

        // Logout user-a
        await service.onLogout('user-a');

        // Verify user-b untouched
        final userBState =
            await storage.read('user-b', PermissionKind.notification);
        expect(userBState.lastShownForRole, equals(UserRole.host));
      });
    });
  });
}
