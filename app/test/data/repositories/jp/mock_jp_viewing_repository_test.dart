/// Unit tests for [MockJpViewingRepository].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/jp/jp_viewing.dart';
import 'package:house_booking/data/repositories/jp/mock_jp_viewing_repository.dart';

void main() {
  late MockJpViewingRepository repo;

  setUp(() {
    repo = MockJpViewingRepository();
  });

  test('create() creates viewing with pending status', () async {
    final slot = const JpViewingSlot(startAt: '2026-12-01T10:00:00+09:00');
    final v = await repo.create(
      listingId: 9001,
      proposedSlots: [slot],
      message: 'よろしくお願いします',
    );

    expect(v.status, equals(JpViewingStatus.pending));
    expect(v.listingId, equals(9001));
    expect(v.proposedSlots.length, equals(1));
    expect(v.message, equals('よろしくお願いします'));
  });

  test('getById() returns created viewing', () async {
    final slot = const JpViewingSlot(startAt: '2026-12-01T10:00:00+09:00');
    final created = await repo.create(
      listingId: 9001,
      proposedSlots: [slot],
    );

    final fetched = await repo.getById(created.id);
    expect(fetched.id, equals(created.id));
  });

  test('confirmSlot() updates status to confirmed', () async {
    final slot = const JpViewingSlot(startAt: '2026-12-01T10:00:00+09:00');
    final v = await repo.create(listingId: 9001, proposedSlots: [slot]);

    final confirmed = await repo.confirmSlot(
      viewingId: v.id,
      slot: slot,
    );

    expect(confirmed.status, equals(JpViewingStatus.confirmed));
    expect(confirmed.confirmedSlot, isNotNull);
    expect(confirmed.confirmedSlot!.startAt, equals(slot.startAt));
  });

  test('cancel() updates status to cancelled', () async {
    final slot = const JpViewingSlot(startAt: '2026-12-02T14:00:00+09:00');
    final v = await repo.create(listingId: 9001, proposedSlots: [slot]);

    final cancelled = await repo.cancel(v.id);
    expect(cancelled.status, equals(JpViewingStatus.cancelled));
  });

  test('listForTenant() returns only tenant viewings', () async {
    final slot = const JpViewingSlot(startAt: '2026-12-03T09:00:00+09:00');
    await repo.create(listingId: 9001, proposedSlots: [slot]);

    final list = await repo.listForTenant(1); // mock always uses tenantId = 1
    expect(list, isNotEmpty);
    expect(list.every((v) => v.tenantId == 1), isTrue);
  });

  test('getById() throws when id not found', () async {
    expect(() => repo.getById(99999), throwsA(isA<Exception>()));
  });
}
