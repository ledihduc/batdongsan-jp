/// Real implementation of [ISettlementRepository] hitting `/api/jp/settlements`.
library;

import 'package:house_booking/data/models/jp/deposit_settlement.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/jp/i_settlement_repository.dart';

class SettlementRepository implements ISettlementRepository {
  const SettlementRepository({ApiClient? client})
      : _client = client ?? const ApiClient();

  final ApiClient _client;

  @override
  Future<JpDepositSettlement> getSettlement(int settlementId) async {
    final response = await _client.get('/api/jp/settlements/$settlementId');
    return JpDepositSettlement.fromJson(response);
  }

  @override
  Future<JpDepositSettlement> updateDeductions(
    int settlementId,
    List<DeductionLine> deductions,
  ) async {
    final response = await _client.put(
      '/api/jp/settlements/$settlementId',
      body: {'deductions': deductions.map((d) => d.toJson()).toList()},
    );
    return JpDepositSettlement.fromJson(response);
  }

  @override
  Future<JpDepositSettlement> submitToTenant(int settlementId) async {
    final response = await _client.post(
      '/api/jp/settlements/$settlementId/submit',
      body: {},
    );
    return JpDepositSettlement.fromJson(response);
  }

  @override
  Future<JpDepositSettlement> acceptSettlement(int settlementId) async {
    final response = await _client.post(
      '/api/jp/settlements/$settlementId/accept',
      body: {},
    );
    return JpDepositSettlement.fromJson(response);
  }

  @override
  Future<JpDepositSettlement> disputeSettlement(
    int settlementId,
    String reason,
  ) async {
    final response = await _client.post(
      '/api/jp/settlements/$settlementId/dispute',
      body: {'reason': reason},
    );
    return JpDepositSettlement.fromJson(response);
  }
}
