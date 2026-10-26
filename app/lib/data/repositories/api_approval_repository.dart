/// Repository wrapping approval workflow API endpoints (Phase 04 backend).
library;

import 'package:house_booking/data/models/approval_request_model.dart';
import 'package:house_booking/data/services/api_client.dart';

class ApiApprovalRepository {
  final ApiClient _client;

  ApiApprovalRepository({ApiClient? client})
    : _client = client ?? const ApiClient();

  /// Fetch pending approvals for the owner (approval inbox).
  Future<List<ApprovalRequestModel>> fetchPendingApprovals({
    String? delegationId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final list = await _client.getList(
      '/api/approvals',
      queryParameters: {
        'status': 'pending',
        if (delegationId != null) 'delegation_id': delegationId,
        'page': page,
        'page_size': pageSize,
      },
    );
    return list
        .map(
          (e) => ApprovalRequestModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  /// Fetch a single approval request by ID.
  Future<ApprovalRequestModel> getApproval(String approvalId) async {
    final resp = await _client.get('/api/approvals/$approvalId');
    return ApprovalRequestModel.fromJson(Map<String, dynamic>.from(resp));
  }

  /// Owner approves a pending request.
  /// [biometricVerified] must be true for high-value actions (AC-29b).
  Future<ApprovalRequestModel> approveRequest(
    String approvalId, {
    required bool biometricVerified,
  }) async {
    final resp = await _client.post(
      '/api/approvals/$approvalId/approve',
      body: {'biometric_verified': biometricVerified},
    );
    return ApprovalRequestModel.fromJson(Map<String, dynamic>.from(resp));
  }

  /// Owner rejects a pending request.
  Future<ApprovalRequestModel> rejectRequest(
    String approvalId, {
    String? reason,
  }) async {
    final resp = await _client.post(
      '/api/approvals/$approvalId/reject',
      body: {if (reason != null) 'rejection_reason': reason},
    );
    return ApprovalRequestModel.fromJson(Map<String, dynamic>.from(resp));
  }
}
