/// Interface for JP deposit settlement (敷金精算) operations.
///
/// Backend endpoints:
///   GET  /api/jp/settlements/:id
///   PUT  /api/jp/settlements/:id   (owner: update deductions)
///   POST /api/jp/settlements/:id/submit   (owner: push to tenant_review)
///   POST /api/jp/settlements/:id/accept   (tenant: accept)
///   POST /api/jp/settlements/:id/dispute  (tenant: dispute with reason)
library;

import 'package:house_booking/data/models/jp/deposit_settlement.dart';

abstract interface class ISettlementRepository {
  /// Fetch a settlement by ID.
  Future<JpDepositSettlement> getSettlement(int settlementId);

  /// Owner: replace all deduction lines and re-calculate net refund.
  Future<JpDepositSettlement> updateDeductions(
    int settlementId,
    List<DeductionLine> deductions,
  );

  /// Owner: submit itemization to tenant for review.
  /// Transitions status draft → tenant_review.
  Future<JpDepositSettlement> submitToTenant(int settlementId);

  /// Tenant: accept the itemization — triggers refund invoice.
  Future<JpDepositSettlement> acceptSettlement(int settlementId);

  /// Tenant: dispute the itemization with a free-text reason.
  Future<JpDepositSettlement> disputeSettlement(
    int settlementId,
    String reason,
  );
}
