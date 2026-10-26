/// Provider for delegation list and invitation management.
///
/// Holds operator's portfolio of delegations (operator side) and
/// owner's outgoing delegations (owner side).
library;

import 'package:flutter/foundation.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/data/models/operator_delegation_model.dart';
import 'package:house_booking/data/models/delegation_invitation_model.dart';
import 'package:house_booking/data/repositories/api_delegation_repository.dart';

enum DelegationLoadState { idle, loading, loaded, error }

class DelegationProvider with ChangeNotifier implements UserScoped {
  final ApiDelegationRepository _repo;

  DelegationProvider({ApiDelegationRepository? repository})
      : _repo = repository ?? ApiDelegationRepository();

  DelegationLoadState _state = DelegationLoadState.idle;
  String? _error;

  /// Delegations where current user is the OPERATOR (portfolio view).
  List<OperatorDelegationModel> _myDelegationsAsOperator = [];

  /// Delegations where current user is the OWNER (manage view).
  List<OperatorDelegationModel> _myDelegationsAsOwner = [];

  /// Pending invitations for the current operator user.
  List<DelegationInvitationModel> _pendingInvitations = [];

  DelegationLoadState get state => _state;
  String? get error => _error;
  List<OperatorDelegationModel> get myDelegationsAsOperator =>
      List.unmodifiable(_myDelegationsAsOperator);
  List<OperatorDelegationModel> get myDelegationsAsOwner =>
      List.unmodifiable(_myDelegationsAsOwner);
  List<DelegationInvitationModel> get pendingInvitations =>
      List.unmodifiable(_pendingInvitations);

  int get pendingInvitationCount => _pendingInvitations
      .where((i) => i.status == InvitationStatus.pending)
      .length;

  /// Fetch all delegations where current user is the operator.
  Future<void> fetchMyDelegationsAsOperator() async {
    _setLoading();
    try {
      _myDelegationsAsOperator =
          await _repo.fetchDelegationsAsOperator();
      _state = DelegationLoadState.loaded;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _state = DelegationLoadState.error;
    }
    notifyListeners();
  }

  /// Fetch all delegations where current user is the owner.
  Future<void> fetchMyDelegationsAsOwner() async {
    _setLoading();
    try {
      _myDelegationsAsOwner = await _repo.fetchDelegationsAsOwner();
      _state = DelegationLoadState.loaded;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _state = DelegationLoadState.error;
    }
    notifyListeners();
  }

  /// Fetch pending invitations for the operator.
  Future<void> fetchPendingInvitations() async {
    try {
      _pendingInvitations = await _repo.fetchPendingInvitations();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  /// Owner: send a new delegation invitation.
  Future<DelegationInvitationModel?> sendInvitation({
    required String operatorEmail,
    required String rolePreset,
    DelegationThresholds? thresholds,
  }) async {
    try {
      final invitation = await _repo.sendInvitation(
        operatorEmail: operatorEmail,
        rolePreset: rolePreset,
        thresholds: thresholds,
      );
      return invitation;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Operator: accept a pending invitation.
  Future<OperatorDelegationModel?> acceptInvitation(String invitationId) async {
    try {
      final delegation = await _repo.acceptInvitation(invitationId);
      // Remove from pending list and add to operator portfolio.
      _pendingInvitations = _pendingInvitations
          .where((i) => i.id != invitationId)
          .toList();
      _myDelegationsAsOperator = [delegation, ..._myDelegationsAsOperator];
      notifyListeners();
      return delegation;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Operator: reject a pending invitation.
  Future<bool> rejectInvitation(String invitationId,
      {String? reason}) async {
    try {
      await _repo.rejectInvitation(invitationId, reason: reason);
      _pendingInvitations = _pendingInvitations
          .where((i) => i.id != invitationId)
          .toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Owner: pause an active delegation.
  Future<OperatorDelegationModel?> pauseDelegation(String delegationId) async {
    return _updateDelegationStatus(delegationId, 'paused');
  }

  /// Owner: resume a paused delegation.
  Future<OperatorDelegationModel?> resumeDelegation(
      String delegationId) async {
    return _updateDelegationStatus(delegationId, 'active');
  }

  /// Owner: terminate a delegation (30-day lockdown applies).
  Future<OperatorDelegationModel?> terminateDelegation(
    String delegationId, {
    String? reason,
  }) async {
    try {
      final updated = await _repo.terminateDelegation(delegationId,
          reason: reason);
      _replaceInOwnerList(updated);
      notifyListeners();
      return updated;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Owner: update approval thresholds for a delegation.
  Future<OperatorDelegationModel?> updateThresholds(
    String delegationId,
    DelegationThresholds thresholds,
  ) async {
    try {
      final updated =
          await _repo.updateThresholds(delegationId, thresholds);
      _replaceInOwnerList(updated);
      notifyListeners();
      return updated;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Record sole-ownership attestation for a building (AC-64).
  Future<bool> attestSoleOwnership(String buildingId) async {
    try {
      await _repo.attestSoleOwnership(buildingId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Record shared-login disclosure acknowledgment (AC-66).
  Future<bool> acknowledgeSharedLoginDisclosure(
      String delegationId) async {
    try {
      await _repo.acknowledgeSharedLoginDisclosure(delegationId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void resetUserScope() {
    _state = DelegationLoadState.idle;
    _error = null;
    _myDelegationsAsOperator = [];
    _myDelegationsAsOwner = [];
    _pendingInvitations = [];
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<OperatorDelegationModel?> _updateDelegationStatus(
    String delegationId,
    String newStatus,
  ) async {
    try {
      final updated = await _repo.updateDelegationStatus(
          delegationId, newStatus);
      _replaceInOwnerList(updated);
      notifyListeners();
      return updated;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  void _replaceInOwnerList(OperatorDelegationModel updated) {
    _myDelegationsAsOwner = _myDelegationsAsOwner.map((d) {
      return d.id == updated.id ? updated : d;
    }).toList();
  }

  void _setLoading() {
    _state = DelegationLoadState.loading;
    notifyListeners();
  }
}
