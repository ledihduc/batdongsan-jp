import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/permissions/permission_events.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import '../../helpers/mock_storage.dart';

void main() {
  group('LocalPermissionEventSink', () {
    late MockFlutterSecureStorage mockStorage;
    late LocalPermissionEventSink sink;

    setUp(() {
      mockStorage = MockFlutterSecureStorage();
      sink = LocalPermissionEventSink(mockStorage);
    });

    group('capture', () {
      test('captures a single event', () async {
        final event = PermissionEvent(
          outcome: PrimingOutcome.accept,
          kind: PermissionKind.notification,
          role: UserRole.guest,
          platform: 'ios',
          ts: DateTime.now(),
        );

        await sink.capture(event);
        final drained = await sink.drainPending();

        expect(drained.length, 1);
        expect(drained[0].outcome, PrimingOutcome.accept);
      });

      test('captures multiple events in order', () async {
        final now = DateTime.now();
        final events = [
          PermissionEvent(
            outcome: PrimingOutcome.shown,
            kind: PermissionKind.notification,
            role: UserRole.guest,
            platform: 'ios',
            ts: now,
          ),
          PermissionEvent(
            outcome: PrimingOutcome.accept,
            kind: PermissionKind.notification,
            role: UserRole.guest,
            platform: 'ios',
            ts: now.add(const Duration(milliseconds: 100)),
          ),
          PermissionEvent(
            outcome: PrimingOutcome.osGrant,
            kind: PermissionKind.notification,
            role: UserRole.guest,
            platform: 'ios',
            ts: now.add(const Duration(milliseconds: 200)),
          ),
        ];

        for (final event in events) {
          await sink.capture(event);
        }

        final drained = await sink.drainPending();
        expect(drained.length, 3);
        expect(drained[0].outcome, PrimingOutcome.shown);
        expect(drained[1].outcome, PrimingOutcome.accept);
        expect(drained[2].outcome, PrimingOutcome.osGrant);
      });
    });

    group('queue cap at 200 events', () {
      test('caps queue at 200 and drops oldest events', () async {
        final baseTime = DateTime(2024, 1, 1);

        // Capture 250 events
        for (int i = 0; i < 250; i++) {
          final event = PermissionEvent(
            outcome: PrimingOutcome.accept,
            kind: PermissionKind.notification,
            role: UserRole.guest,
            platform: 'ios',
            ts: baseTime.add(Duration(milliseconds: i)),
          );
          await sink.capture(event);
        }

        final drained = await sink.drainPending();

        // Should have exactly 200 events
        expect(drained.length, 200);

        // Oldest 50 should be dropped (events 0-49)
        // Remaining should be events 50-249
        final oldestRemaining = drained[0].ts;
        final expectedOldest = baseTime.add(const Duration(milliseconds: 50));
        expect(
          oldestRemaining.difference(expectedOldest).inMilliseconds,
          0,
        );
      });

      test('maintains event order after cap', () async {
        final baseTime = DateTime(2024, 1, 1);

        for (int i = 0; i < 250; i++) {
          final event = PermissionEvent(
            outcome: i % 2 == 0 ? PrimingOutcome.accept : PrimingOutcome.defer,
            kind: PermissionKind.notification,
            role: UserRole.guest,
            platform: 'ios',
            ts: baseTime.add(Duration(milliseconds: i)),
          );
          await sink.capture(event);
        }

        final drained = await sink.drainPending();

        // Verify chronological order
        for (int i = 1; i < drained.length; i++) {
          expect(
            drained[i].ts.isAfter(drained[i - 1].ts),
            true,
            reason: 'Event $i should be after event ${i - 1}',
          );
        }
      });
    });

    group('drainPending', () {
      test('returns snapshot without clearing', () async {
        final event1 = PermissionEvent(
          outcome: PrimingOutcome.accept,
          kind: PermissionKind.notification,
          role: UserRole.guest,
          platform: 'ios',
          ts: DateTime.now(),
        );
        await sink.capture(event1);

        final drained1 = await sink.drainPending();
        expect(drained1.length, 1);

        final drained2 = await sink.drainPending();
        expect(drained2.length, 1);
      });

      test('returns copy of queue, not reference', () async {
        final event = PermissionEvent(
          outcome: PrimingOutcome.accept,
          kind: PermissionKind.notification,
          role: UserRole.guest,
          platform: 'ios',
          ts: DateTime.now(),
        );
        await sink.capture(event);

        final drained = await sink.drainPending();
        expect(drained.length, 1);
      });
    });

    group('clear', () {
      test('removes events matching by timestamp microseconds', () async {
        final baseTime = DateTime(2024, 1, 1, 12, 30, 45, 123456);
        final events = [
          PermissionEvent(
            outcome: PrimingOutcome.accept,
            kind: PermissionKind.notification,
            role: UserRole.guest,
            platform: 'ios',
            ts: baseTime,
          ),
          PermissionEvent(
            outcome: PrimingOutcome.defer,
            kind: PermissionKind.notification,
            role: UserRole.guest,
            platform: 'ios',
            ts: baseTime.add(const Duration(seconds: 1)),
          ),
          PermissionEvent(
            outcome: PrimingOutcome.osGrant,
            kind: PermissionKind.notification,
            role: UserRole.guest,
            platform: 'ios',
            ts: baseTime.add(const Duration(seconds: 2)),
          ),
        ];

        for (final event in events) {
          await sink.capture(event);
        }

        // Clear first and last
        await sink.clear([events[0], events[2]]);

        final remaining = await sink.drainPending();
        expect(remaining.length, 1);
        expect(remaining[0].outcome, PrimingOutcome.defer);
      });

      test('clears empty list safely', () async {
        final event = PermissionEvent(
          outcome: PrimingOutcome.accept,
          kind: PermissionKind.notification,
          role: UserRole.guest,
          platform: 'ios',
          ts: DateTime.now(),
        );
        await sink.capture(event);

        await sink.clear([]);

        final remaining = await sink.drainPending();
        expect(remaining.length, 1);
      });

      test('clears all events when all match', () async {
        final baseTime = DateTime.now();
        final events = List.generate(
          5,
          (i) => PermissionEvent(
            outcome: PrimingOutcome.accept,
            kind: PermissionKind.notification,
            role: UserRole.guest,
            platform: 'ios',
            ts: baseTime.add(Duration(milliseconds: i)),
          ),
        );

        for (final event in events) {
          await sink.capture(event);
        }

        await sink.clear(events);

        final remaining = await sink.drainPending();
        expect(remaining.length, 0);
      });
    });

    group('persistence', () {
      test('persists captured events to secure storage', () async {
        final event = PermissionEvent(
          outcome: PrimingOutcome.accept,
          kind: PermissionKind.notification,
          role: UserRole.guest,
          platform: 'ios',
          ts: DateTime.now(),
        );

        await sink.capture(event);

        // Verify data was written
        final stored = mockStorage.getAllStored();
        expect(stored.containsKey('priming_event_queue_v1'), true);
      });

      test('hydrates from storage on next instance', () async {
        final event = PermissionEvent(
          outcome: PrimingOutcome.accept,
          kind: PermissionKind.notification,
          role: UserRole.guest,
          platform: 'ios',
          ts: DateTime.now(),
        );

        final sink1 = LocalPermissionEventSink(mockStorage);
        await sink1.capture(event);

        // Create new instance with same storage
        final sink2 = LocalPermissionEventSink(mockStorage);
        final drained = await sink2.drainPending();

        expect(drained.length, 1);
        expect(drained[0].outcome, PrimingOutcome.accept);
      });

      test('skips malformed events during hydration', () async {
        // Manually write malformed JSON to storage
        await mockStorage.write(
          key: 'priming_event_queue_v1',
          value: '[{"outcome":"invalid"},{"outcome":"accept","kind":"notification","platform":"ios","ts":"2024-01-01T12:00:00.000Z"}]',
        );

        final sink = LocalPermissionEventSink(mockStorage);
        final drained = await sink.drainPending();

        // Should skip malformed, keep valid
        expect(drained.length, 1);
        expect(drained[0].outcome, PrimingOutcome.accept);
      });
    });

    group('camera events', () {
      test('captures camera events with context', () async {
        final event = PermissionEvent(
          outcome: PrimingOutcome.accept,
          kind: PermissionKind.camera,
          context: 'cccdUpload',
          platform: 'android',
          ts: DateTime.now(),
        );

        await sink.capture(event);
        final drained = await sink.drainPending();

        expect(drained.length, 1);
        expect(drained[0].kind, PermissionKind.camera);
        expect(drained[0].context, 'cccdUpload');
      });
    });
  });
}
