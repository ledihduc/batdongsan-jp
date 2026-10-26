import 'package:house_booking/data/models/service_fee_model.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Repository for /api/host/service-fees endpoints (Phase 04).
class ApiServiceFeeRepository {
  final ApiClient _client = const ApiClient();

  Future<List<ServiceFeeModel>> fetchServiceFees({
    int? buildingId,
    bool? isActive,
  }) async {
    final query = <String, dynamic>{
      if (buildingId != null) 'building_id': buildingId,
      if (isActive != null) 'is_active': isActive,
    };
    final list = await _client.getList(
      '/api/host/service-fees',
      queryParameters: query,
    );
    return list
        .map(
          (e) => ServiceFeeModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<ServiceFeeModel> createServiceFee({
    required int buildingId,
    required String name,
    double unitPrice = 0,
    String billingCycle = 'monthly', // monthly|one_time
  }) async {
    final resp = await _client.post(
      '/api/host/service-fees',
      body: {
        'building_id': buildingId,
        'name': name,
        'unit_price': unitPrice,
        'billing_cycle': billingCycle,
      },
    );
    return ServiceFeeModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<ServiceFeeModel> updateServiceFee(
    int feeId, {
    String? name,
    double? unitPrice,
    String? billingCycle,
    bool? isActive,
  }) async {
    final resp = await _client.patch(
      '/api/host/service-fees/$feeId',
      body: {
        if (name != null) 'name': name,
        if (unitPrice != null) 'unit_price': unitPrice,
        if (billingCycle != null) 'billing_cycle': billingCycle,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return ServiceFeeModel.fromJson(Map<String, dynamic>.from(resp));
  }

  /// Attach a ServiceFee to a Contract with a snapshotted monthly amount.
  Future<ContractServiceFeeModel> attachToContract({
    required int contractId,
    required int serviceFeeId,
    required double monthlyAmount,
  }) async {
    final resp = await _client.post(
      '/api/host/contracts/$contractId/service-fees',
      body: {'service_fee_id': serviceFeeId, 'monthly_amount': monthlyAmount},
    );
    return ContractServiceFeeModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<void> detachFromContract({
    required int contractId,
    required int feeId,
  }) async {
    await _client.delete('/api/host/contracts/$contractId/service-fees/$feeId');
  }
}
