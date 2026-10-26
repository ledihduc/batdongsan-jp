/// Repository wrapping delegation lifecycle API endpoints (Phase 03 backend).
///
/// All calls go through ApiClient which injects the acting-as header
/// automatically when ActorContextProvider has an active context.
library;

import 'package:house_booking/data/models/operator_delegation_model.dart';
import 'package:house_booking/data/models/delegation_invitation_model.dart';
import 'package:house_booking/data/services/api_client.dart';

class ApiDelegationRepository {
  final ApiClient _client;

  ApiDelegationRepository({ApiClient? client})
    : _client = client ?? const ApiClient();

  // ── Operator-side: portfolio ──────────────────────────────────────────────

  /// Fetch delegations where the current user is the OPERATOR.
  Future<List<OperatorDelegationModel>> fetchDelegationsAsOperator() async {
    final list = await _client.getList(
      '/api/delegations',
      queryParameters: {'role': 'operator'},
    );
    return list
        .map(
          (e) => OperatorDelegationModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  // ── Owner-side: manage delegations ────────────────────────────────────────

  /// Fetch delegations where the current user is the OWNER.
  Future<List<OperatorDelegationModel>> fetchDelegationsAsOwner() async {
    final list = await _client.getList(
      '/api/delegations',
      queryParameters: {'role': 'owner'},
    );
    return list
        .map(
          (e) => OperatorDelegationModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  /// Get a single delegation by ID.
  Future<OperatorDelegationModel> getDelegation(String delegationId) async {
    final resp = await _client.get('/api/delegations/$delegationId');
    return OperatorDelegationModel.fromJson(Map<String, dynamic>.from(resp));
  }

  // ── Owner-side: invitations ───────────────────────────────────────────────

  /// Owner sends an invitation to an operator by email.
  Future<DelegationInvitationModel> sendInvitation({
    required String operatorEmail,
    required String rolePreset,
    DelegationThresholds? thresholds,
  }) async {
    final body = <String, dynamic>{
      'operator_email': operatorEmail,
      'role_preset': rolePreset,
      if (thresholds != null) 'thresholds': thresholds.toJson(),
    };
    final resp = await _client.post('/api/delegation-invitations', body: body);
    return DelegationInvitationModel.fromJson(Map<String, dynamic>.from(resp));
  }

  // ── Operator-side: invitations ────────────────────────────────────────────

  /// Fetch pending invitations for the current operator user.
  Future<List<DelegationInvitationModel>> fetchPendingInvitations() async {
    final list = await _client.getList(
      '/api/delegation-invitations',
      queryParameters: {'status': 'pending'},
    );
    return list
        .map(
          (e) => DelegationInvitationModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  /// Operator accepts an invitation.
  Future<OperatorDelegationModel> acceptInvitation(String invitationId) async {
    final resp = await _client.post(
      '/api/delegation-invitations/$invitationId/accept',
    );
    return OperatorDelegationModel.fromJson(Map<String, dynamic>.from(resp));
  }

  /// Operator rejects an invitation.
  Future<void> rejectInvitation(String invitationId, {String? reason}) async {
    await _client.post(
      '/api/delegation-invitations/$invitationId/reject',
      body: {if (reason != null) 'reason': reason},
    );
  }

  // ── Owner-side: lifecycle management ─────────────────────────────────────

  /// Owner updates delegation status (active → paused, paused → active).
  Future<OperatorDelegationModel> updateDelegationStatus(
    String delegationId,
    String newStatus,
  ) async {
    final resp = await _client.patch(
      '/api/delegations/$delegationId/status',
      body: {'status': newStatus},
    );
    return OperatorDelegationModel.fromJson(Map<String, dynamic>.from(resp));
  }

  /// Owner terminates a delegation (AC-42).
  Future<OperatorDelegationModel> terminateDelegation(
    String delegationId, {
    String? reason,
  }) async {
    final resp = await _client.post(
      '/api/delegations/$delegationId/terminate',
      body: {if (reason != null) 'reason': reason},
    );
    return OperatorDelegationModel.fromJson(Map<String, dynamic>.from(resp));
  }

  /// Owner updates approval thresholds for a delegation (AC-31b).
  Future<OperatorDelegationModel> updateThresholds(
    String delegationId,
    DelegationThresholds thresholds,
  ) async {
    final resp = await _client.patch(
      '/api/delegations/$delegationId/thresholds',
      body: {'thresholds': thresholds.toJson()},
    );
    return OperatorDelegationModel.fromJson(Map<String, dynamic>.from(resp));
  }

  // ── Attestations ──────────────────────────────────────────────────────────

  /// Record sole-ownership attestation for a building (AC-64).
  Future<void> attestSoleOwnership(String buildingId) async {
    await _client.post('/api/buildings/$buildingId/attest-sole-ownership');
  }

  /// Record shared-login disclosure acknowledgment (AC-66).
  Future<void> acknowledgeSharedLoginDisclosure(String delegationId) async {
    await _client.post(
      '/api/delegations/$delegationId/acknowledge-shared-login',
    );
  }

  // ── Audit log ─────────────────────────────────────────────────────────────

  /// Fetch audit log entries for a delegation's activity feed (AC-38).
  Future<List<Map<String, dynamic>>> fetchAuditLog(
    String delegationId, {
    String? filterPeriod, // 'today', 'week', 'month'
    String? entityType,
    int page = 1,
    int pageSize = 30,
  }) async {
    final list = await _client.getList(
      '/api/delegations/$delegationId/audit-log',
      queryParameters: {
        if (filterPeriod != null) 'period': filterPeriod,
        if (entityType != null) 'entity_type': entityType,
        'page': page,
        'page_size': pageSize,
      },
    );
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
