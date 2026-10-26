/// In-memory mock for [IRenewalRepository].
///
/// Returns a single seeded renewal so all screens can render standalone
/// without a live backend.
library;

import 'package:house_booking/data/models/jp/renewal.dart';
import 'package:house_booking/domain/repositories/jp/i_renewal_repository.dart';

class MockRenewalRepository implements IRenewalRepository {
  // Seeded store keyed by renewal ID.
  final Map<int, JpRenewal> _store = {
    1: JpRenewal(
      id: 1,
      contractId: 101,
      propertyName: 'グランドパレス新宿',
      roomNumber: '305',
      tenantName: '山田 太郎',
      currentTermEnd: DateTime(2026, 12, 31),
      newTermEnd: DateTime(2027, 12, 31),
      monthlyRentYen: 85000,
      feeItems: const [
        RenewalFeeItem(label: '更新料（1ヶ月分）', amountYen: 85000),
        RenewalFeeItem(label: '更新事務手数料', amountYen: 10000),
        RenewalFeeItem(label: '消費税（10%）', amountYen: 9500),
      ],
      status: RenewalStatus.pending,
    ),
  };

  @override
  Future<JpRenewal> getRenewal(int renewalId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final renewal = _store[renewalId];
    if (renewal == null) throw Exception('Renewal $renewalId not found');
    return renewal;
  }

  @override
  Future<JpRenewal> confirmRenewal(int renewalId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final renewal = _store[renewalId];
    if (renewal == null) throw Exception('Renewal $renewalId not found');
    final updated = JpRenewal(
      id: renewal.id,
      contractId: renewal.contractId,
      propertyName: renewal.propertyName,
      roomNumber: renewal.roomNumber,
      tenantName: renewal.tenantName,
      currentTermEnd: renewal.currentTermEnd,
      newTermEnd: renewal.newTermEnd,
      monthlyRentYen: renewal.monthlyRentYen,
      feeItems: renewal.feeItems,
      status: RenewalStatus.confirmed,
      confirmedAt: DateTime.now(),
    );
    _store[renewalId] = updated;
    return updated;
  }

  @override
  Future<JpRenewal> declineRenewal(int renewalId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final renewal = _store[renewalId];
    if (renewal == null) throw Exception('Renewal $renewalId not found');
    final updated = JpRenewal(
      id: renewal.id,
      contractId: renewal.contractId,
      propertyName: renewal.propertyName,
      roomNumber: renewal.roomNumber,
      tenantName: renewal.tenantName,
      currentTermEnd: renewal.currentTermEnd,
      newTermEnd: renewal.newTermEnd,
      monthlyRentYen: renewal.monthlyRentYen,
      feeItems: renewal.feeItems,
      status: RenewalStatus.declined,
    );
    _store[renewalId] = updated;
    return updated;
  }
}
