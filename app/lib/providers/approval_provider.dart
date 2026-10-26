/// Provider for the approval inbox — pending approvals where user is owner.
///
/// Nạp theo yêu cầu qua [fetch]. KHÔNG hỏi định kỳ: phần polling 30s trước đây
/// chưa từng được gọi từ đâu (mã chết), và luồng uỷ quyền hiện chưa có người
/// dùng nào — bảng `delegation_approvals` rỗng.
library;

import 'package:flutter/foundation.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/data/models/approval_request_model.dart';
import 'package:house_booking/data/repositories/api_approval_repository.dart';

class ApprovalProvider with ChangeNotifier implements UserScoped {
  final ApiApprovalRepository _repo;

  ApprovalProvider({ApiApprovalRepository? repository})
      : _repo = repository ?? ApiApprovalRepository();

  List<ApprovalRequestModel> _pendingApprovals = [];
  bool _isLoading = false;
  String? _error;

  List<ApprovalRequestModel> get pendingApprovals =>
      List.unmodifiable(_pendingApprovals);
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get pendingCount =>
      _pendingApprovals.where((a) => a.status == ApprovalStatus.pending).length;

  /// Fetch all pending approvals for the owner.
  Future<void> fetch(String userId) async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      _pendingApprovals = await _repo.fetchPendingApprovals();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Owner: approve a pending request.
  /// [biometricVerified] must be true when request.requiresBiometric is true.
  Future<bool> approveRequest(
    String approvalId, {
    required bool biometricVerified,
  }) async {
    try {
      await _repo.approveRequest(approvalId,
          biometricVerified: biometricVerified);
      _removeFromPending(approvalId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Owner: reject a pending request with optional reason.
  Future<bool> rejectRequest(String approvalId, {String? reason}) async {
    try {
      await _repo.rejectRequest(approvalId, reason: reason);
      _removeFromPending(approvalId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void resetUserScope() {
    _pendingApprovals = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _removeFromPending(String approvalId) {
    _pendingApprovals =
        _pendingApprovals.where((a) => a.id != approvalId).toList();
  }
}
