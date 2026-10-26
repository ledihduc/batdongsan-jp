/// In-memory mock for [ISettlementRepository].
///
/// Seeded with one draft settlement to allow both owner and tenant screens
/// to render without a live backend.
library;

import 'package:house_booking/data/models/jp/deposit_settlement.dart';
import 'package:house_booking/domain/repositories/jp/i_settlement_repository.dart';

class MockSettlementRepository implements ISettlementRepository {
  final Map<int, JpDepositSettlement> _store = {
    1: JpDepositSettlement(
      id: 1,
      contractId: 101,
      propertyName: 'グランドパレス新宿',
      roomNumber: '305',
      tenantName: '山田 太郎',
      depositYen: 170000,
      deductions: const [
        DeductionLine(
          id: 'ded-1',
          title: '畳表替え',
          amountYen: 25000,
          photoUrls: [],
        ),
        DeductionLine(
          id: 'ded-2',
          title: 'クロス補修',
          amountYen: 18000,
          photoUrls: [],
        ),
      ],
      status: SettlementStatus.draft,
    ),
  };

  @override
  Future<JpDepositSettlement> getSettlement(int settlementId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final s = _store[settlementId];
    if (s == null) throw Exception('Settlement $settlementId not found');
    return s;
  }

  @override
  Future<JpDepositSettlement> updateDeductions(
    int settlementId,
    List<DeductionLine> deductions,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final s = _store[settlementId];
    if (s == null) throw Exception('Settlement $settlementId not found');
    final updated = s.copyWith(deductions: deductions);
    _store[settlementId] = updated;
    return updated;
  }

  @override
  Future<JpDepositSettlement> submitToTenant(int settlementId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final s = _store[settlementId];
    if (s == null) throw Exception('Settlement $settlementId not found');
    final updated = s.copyWith(status: SettlementStatus.tenantReview);
    _store[settlementId] = updated;
    return updated;
  }

  @override
  Future<JpDepositSettlement> acceptSettlement(int settlementId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final s = _store[settlementId];
    if (s == null) throw Exception('Settlement $settlementId not found');
    final updated = s.copyWith(status: SettlementStatus.tenantAccepted);
    _store[settlementId] = updated;
    return updated;
  }

  @override
  Future<JpDepositSettlement> disputeSettlement(
    int settlementId,
    String reason,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final s = _store[settlementId];
    if (s == null) throw Exception('Settlement $settlementId not found');
    final updated = s.copyWith(
      status: SettlementStatus.tenantDisputed,
      disputeReason: reason,
    );
    _store[settlementId] = updated;
    return updated;
  }
}
