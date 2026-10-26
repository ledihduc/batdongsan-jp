import 'package:flutter/foundation.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/core/permissions/role_guard.dart';
import 'package:house_booking/data/models/contract_model.dart';
import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/data/repositories/api_contract_repository.dart';
import 'package:house_booking/data/services/api_client.dart';

/// ContractProvider — manages contracts + expiring dashboard widget.
class ContractProvider extends ChangeNotifier implements UserScoped {
  final ApiContractRepository _repo = ApiContractRepository();

  List<ContractModel> _contracts = [];
  List<ContractModel> _expiringContracts = [];
  bool _isLoading = false;
  String? _error;

  List<ContractModel> get contracts => List.unmodifiable(_contracts);
  List<ContractModel> get expiringContracts =>
      List.unmodifiable(_expiringContracts);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get expiringCount => _expiringContracts.length;

  @override
  void resetUserScope() {
    _contracts = [];
    _expiringContracts = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> fetchContracts({
    String? status,
    int? roomId,
    bool includeTerminated = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _contracts = await _repo.fetchContracts(
        status: status,
        roomId: roomId,
        includeTerminated: includeTerminated,
      );
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Không thể tải hợp đồng';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch contracts expiring within N days for dashboard widget.
  Future<void> fetchExpiringContracts({int days = 30}) async {
    try {
      _expiringContracts =
          await _repo.fetchContracts(expiringWithin: days);
      notifyListeners();
    } catch (_) {
      // Silent fail for dashboard widget
    }
  }

  Future<ContractModel?> createContract({
    required int roomId,
    required String startDate,
    required String endDate,
    required double monthlyRent,
    double deposit = 0,
    List<String> handoverPhotos = const [],
    required List<Map<String, dynamic>> tenants,
  }) async {
    try {
      final c = await _repo.createContract(
        roomId: roomId,
        startDate: startDate,
        endDate: endDate,
        monthlyRent: monthlyRent,
        deposit: deposit,
        handoverPhotos: handoverPhotos,
        tenants: tenants,
      );
      _contracts = [..._contracts, c];
      notifyListeners();
      return c;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<ContractModel?> activateContract(int contractId) async {
    try {
      final updated = await _repo.activateContract(contractId);
      _updateInList(updated);
      return updated;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<ContractModel?> terminateContract(
    int contractId, {
    required String actualEndDate,
    double depositRefundAmount = 0,
    String? damageNote,
    List<String> damagePhotos = const [],
    UserModel? actor,
  }) async {
    if (actor != null && !RoleGuard.canHost(actor)) {
      throw const PermissionDeniedException(
        action: 'terminateContract',
        requiredRole: 'host',
      );
    }
    try {
      final updated = await _repo.terminateContract(
        contractId,
        actualEndDate: actualEndDate,
        depositRefundAmount: depositRefundAmount,
        damageNote: damageNote,
        damagePhotos: damagePhotos,
      );
      _updateInList(updated);
      return updated;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<ContractModel?> transferRoom(
      int contractId, int newRoomId, {UserModel? actor}) async {
    if (actor != null && !RoleGuard.canHost(actor)) {
      throw const PermissionDeniedException(
        action: 'transferRoom',
        requiredRole: 'host',
      );
    }
    try {
      final updated = await _repo.transferRoom(contractId, newRoomId);
      _updateInList(updated);
      return updated;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  void _updateInList(ContractModel updated) {
    _contracts = _contracts
        .map((c) => c.id == updated.id ? updated : c)
        .toList();
    notifyListeners();
  }
}
