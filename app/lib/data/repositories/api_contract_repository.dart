import 'package:house_booking/data/models/contract_model.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Repository for /api/host/contracts endpoints.
class ApiContractRepository {
  final ApiClient _client = const ApiClient();

  Future<List<ContractModel>> fetchContracts({
    String? status,
    int? roomId,
    int? expiringWithin,
    bool includeTerminated = false,
  }) async {
    final query = <String, dynamic>{
      if (status != null) 'status': status,
      if (roomId != null) 'room_id': roomId,
      if (expiringWithin != null) 'expiring_within': expiringWithin,
      if (includeTerminated) 'include_terminated': 'true',
    };
    final list = await _client.getList(
      '/api/host/contracts',
      queryParameters: query,
    );
    return list
        .map((e) => ContractModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ContractModel> getContract(int contractId) async {
    final resp = await _client.get('/api/host/contracts/$contractId');
    return ContractModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<ContractModel> createContract({
    required int roomId,
    required String startDate,
    required String endDate,
    required double monthlyRent,
    double deposit = 0,
    List<String> handoverPhotos = const [],
    required List<Map<String, dynamic>> tenants,
  }) async {
    final resp = await _client.post(
      '/api/host/contracts',
      body: {
        'room_id': roomId,
        'start_date': startDate,
        'end_date': endDate,
        'monthly_rent': monthlyRent,
        'deposit': deposit,
        'handover_photos': handoverPhotos,
        'tenants': tenants,
      },
    );
    return ContractModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<ContractModel> activateContract(int contractId) async {
    final resp = await _client.patch(
      '/api/host/contracts/$contractId/activate',
    );
    return ContractModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<ContractModel> terminateContract(
    int contractId, {
    required String actualEndDate,
    double depositRefundAmount = 0,
    String? damageNote,
    List<String> damagePhotos = const [],
  }) async {
    final resp = await _client.patch(
      '/api/host/contracts/$contractId/terminate',
      body: {
        'actual_end_date': actualEndDate,
        'deposit_refund_amount': depositRefundAmount,
        if (damageNote != null) 'damage_note': damageNote,
        'damage_photos': damagePhotos,
      },
    );
    return ContractModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<ContractModel> transferRoom(int contractId, int newRoomId) async {
    final resp = await _client.patch(
      '/api/host/contracts/$contractId/transfer-room',
      body: {'new_room_id': newRoomId},
    );
    return ContractModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<Map<String, dynamic>> batchRenew({
    required List<int> contractIds,
    required String newEndDate,
  }) async {
    final resp = await _client.post(
      '/api/host/contracts/batch-renew',
      body: {'contract_ids': contractIds, 'new_end_date': newEndDate},
    );
    return Map<String, dynamic>.from(resp);
  }
}
