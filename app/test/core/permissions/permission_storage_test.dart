import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/permissions/permission_storage.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import '../../helpers/mock_storage.dart';

void main() {
  group('PermissionStorage', () {
    // group() and test() from flutter_test package
    late MockFlutterSecureStorage mockStorage;
    late PermissionStorage storage;

    setUp(() {
      mockStorage = MockFlutterSecureStorage();
      storage = PermissionStorage(mockStorage);
    });

    group('read/write', () {
      test('writes and reads state for notification kind', () async {
        final now = DateTime.now();
        final state = PrimingState(
          lastShownAt: now,
          lastDeferAt: now.subtract(const Duration(hours: 1)),
          lastShownForRole: UserRole.guest,
        );

        await storage.write('user123', PermissionKind.notification, state);
        final read = await storage.read('user123', PermissionKind.notification);

        expect(read.lastShownAt?.toIso8601String(),
            state.lastShownAt?.toIso8601String());
        expect(read.lastDeferAt?.toIso8601String(),
            state.lastDeferAt?.toIso8601String());
        expect(read.lastShownForRole, UserRole.guest);
      });

      test('writes and reads state with camera subcontext', () async {
        final now = DateTime.now();
        final state = PrimingState(
          lastShownAt: now,
          osGranted: true,
        );

        await storage.write(
          'user123',
          PermissionKind.camera,
          state,
          subContext: 'cccdUpload',
        );
        final read = await storage.read(
          'user123',
          PermissionKind.camera,
          subContext: 'cccdUpload',
        );

        expect(read.osGranted, true);
        expect(read.lastShownAt?.toIso8601String(),
            state.lastShownAt?.toIso8601String());
      });

      test('returns empty state when no key exists', () async {
        final read =
            await storage.read('nonexistent', PermissionKind.notification);
        expect(read.lastShownAt, isNull);
        expect(read.lastDeferAt, isNull);
        expect(read.osGranted, false);
      });
    });

    group('per-user isolation', () {
      test('different users have separate keys', () async {
        final state1 = PrimingState(
          lastShownAt: DateTime.now(),
          lastShownForRole: UserRole.guest,
        );
        final state2 = PrimingState(
          lastShownAt: DateTime.now().subtract(const Duration(days: 10)),
          lastShownForRole: UserRole.host,
        );

        await storage.write('user1', PermissionKind.notification, state1);
        await storage.write('user2', PermissionKind.notification, state2);

        final readUser1 =
            await storage.read('user1', PermissionKind.notification);
        final readUser2 =
            await storage.read('user2', PermissionKind.notification);

        expect(readUser1.lastShownForRole, UserRole.guest);
        expect(readUser2.lastShownForRole, UserRole.host);
        expect(readUser1.lastShownAt?.isBefore(readUser2.lastShownAt!), false);
      });

      test('clearUser only deletes target user keys', () async {
        final state = PrimingState(lastShownAt: DateTime.now());

        await storage.write('user1', PermissionKind.notification, state);
        await storage.write('user2', PermissionKind.notification, state);
        await storage.write(
          'user1',
          PermissionKind.camera,
          state,
          subContext: 'cccdUpload',
        );

        await storage.clearUser('user1');

        final readUser1Notif =
            await storage.read('user1', PermissionKind.notification);
        final readUser1Camera = await storage.read(
          'user1',
          PermissionKind.camera,
          subContext: 'cccdUpload',
        );
        final readUser2Notif =
            await storage.read('user2', PermissionKind.notification);

        expect(readUser1Notif.lastShownAt, isNull);
        expect(readUser1Camera.lastShownAt, isNull);
        expect(readUser2Notif.lastShownAt, isNotNull);
      });
    });

    group('isInCooldown', () {
      test('returns false when no cooldown set', () async {
        final inCooldown = await storage.isInCooldown(
          'user123',
          PermissionKind.notification,
        );
        expect(inCooldown, false);
      });

      test('returns true within 7-day defer cooldown', () async {
        final now = DateTime.now();
        final recentDefer = now.subtract(const Duration(hours: 12));
        final state = PrimingState(lastDeferAt: recentDefer);

        await storage.write('user123', PermissionKind.notification, state);

        final inCooldown = await storage.isInCooldown(
          'user123',
          PermissionKind.notification,
        );
        expect(inCooldown, true);
      });

      test('returns false after 7-day defer cooldown expires', () async {
        final now = DateTime.now();
        final expiredDefer = now.subtract(const Duration(days: 8));
        final state = PrimingState(lastDeferAt: expiredDefer);

        await storage.write('user123', PermissionKind.notification, state);

        final inCooldown = await storage.isInCooldown(
          'user123',
          PermissionKind.notification,
        );
        expect(inCooldown, false);
      });

      test('returns true within 30-day deny cooldown', () async {
        final now = DateTime.now();
        final recentDeny = now.subtract(const Duration(days: 15));
        final state = PrimingState(lastDenyAt: recentDeny);

        await storage.write('user123', PermissionKind.notification, state);

        final inCooldown = await storage.isInCooldown(
          'user123',
          PermissionKind.notification,
        );
        expect(inCooldown, true);
      });

      test('returns false after 30-day deny cooldown expires', () async {
        final now = DateTime.now();
        final expiredDeny = now.subtract(const Duration(days: 31));
        final state = PrimingState(lastDenyAt: expiredDeny);

        await storage.write('user123', PermissionKind.notification, state);

        final inCooldown = await storage.isInCooldown(
          'user123',
          PermissionKind.notification,
        );
        expect(inCooldown, false);
      });

      test('defer cooldown takes precedence over deny', () async {
        final now = DateTime.now();
        final recentDefer = now.subtract(const Duration(hours: 12));
        final expiredDeny = now.subtract(const Duration(days: 31));
        final state = PrimingState(
          lastDeferAt: recentDefer,
          lastDenyAt: expiredDeny,
        );

        await storage.write('user123', PermissionKind.notification, state);

        final inCooldown = await storage.isInCooldown(
          'user123',
          PermissionKind.notification,
        );
        expect(inCooldown, true);
      });
    });

    group('clearUser with camera contexts', () {
      test('deletes all camera sub-context keys for user', () async {
        final state = PrimingState(lastShownAt: DateTime.now());
        final contexts = [
          'cccdUpload',
          'postHousePhoto',
          'contractPhoto',
        ];

        for (final ctx in contexts) {
          await storage.write(
            'user1',
            PermissionKind.camera,
            state,
            subContext: ctx,
          );
        }

        await storage.clearUser('user1');

        for (final ctx in contexts) {
          final read = await storage.read(
            'user1',
            PermissionKind.camera,
            subContext: ctx,
          );
          expect(read.lastShownAt, isNull);
        }
      });
    });

    group('skipDays (debug)', () {
      test('shifts timestamps backwards by specified days', () async {
        final now = DateTime.now();
        final state = PrimingState(
          lastShownAt: now,
          lastDeferAt: now.subtract(const Duration(hours: 6)),
          lastDenyAt: now.subtract(const Duration(days: 15)),
        );

        await storage.write('user123', PermissionKind.notification, state);

        await storage.skipDays('user123', 7);

        final read = await storage.read('user123', PermissionKind.notification);

        expect(
          read.lastShownAt!.difference(state.lastShownAt!).inDays,
          -7,
        );
        expect(
          read.lastDeferAt!.difference(state.lastDeferAt!).inDays,
          -7,
        );
        expect(
          read.lastDenyAt!.difference(state.lastDenyAt!).inDays,
          -7,
        );
      });

      test('skipDays handles null timestamps', () async {
        final now = DateTime.now();
        final state = PrimingState(
          lastShownAt: now,
          lastDeferAt: null,
          lastDenyAt: null,
        );

        await storage.write('user123', PermissionKind.notification, state);
        await storage.skipDays('user123', 7);

        final read = await storage.read('user123', PermissionKind.notification);
        expect(read.lastShownAt, isNotNull);
        expect(read.lastDeferAt, isNull);
        expect(read.lastDenyAt, isNull);
      });

      test('skipDays updates camera sub-context keys', () async {
        final now = DateTime.now();
        final state = PrimingState(lastShownAt: now);

        await storage.write(
          'user123',
          PermissionKind.camera,
          state,
          subContext: 'cccdUpload',
        );

        await storage.skipDays('user123', 7);

        final read = await storage.read(
          'user123',
          PermissionKind.camera,
          subContext: 'cccdUpload',
        );
        expect(read.lastShownAt, isNotNull);
        expect(
          read.lastShownAt!.difference(state.lastShownAt!).inDays,
          -7,
        );
      });
    });

    group('resetAll (debug)', () {
      test('clears all priming keys across all users', () async {
        final state = PrimingState(lastShownAt: DateTime.now());

        await storage.write('user1', PermissionKind.notification, state);
        await storage.write('user2', PermissionKind.notification, state);
        await storage.write(
          'user1',
          PermissionKind.camera,
          state,
          subContext: 'cccdUpload',
        );

        await storage.resetAll();

        final read1 = await storage.read('user1', PermissionKind.notification);
        final read2 = await storage.read('user2', PermissionKind.notification);
        final read3 = await storage.read(
          'user1',
          PermissionKind.camera,
          subContext: 'cccdUpload',
        );

        expect(read1.lastShownAt, isNull);
        expect(read2.lastShownAt, isNull);
        expect(read3.lastShownAt, isNull);
      });
    });
  });
}
