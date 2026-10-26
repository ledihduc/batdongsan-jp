import 'package:flutter/foundation.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/data/models/service_fee_model.dart';
import 'package:house_booking/data/repositories/api_service_fee_repository.dart';
import 'package:house_booking/data/services/api_client.dart';

/// ServiceFeeProvider — manages building-level fees and per-contract assignments.
class ServiceFeeProvider extends ChangeNotifier implements UserScoped {
  final ApiServiceFeeRepository _repo = ApiServiceFeeRepository();

  List<ServiceFeeModel> _serviceFees = [];
  bool _isLoading = false;
  String? _error;

  List<ServiceFeeModel> get serviceFees => List.unmodifiable(_serviceFees);
  bool get isLoading => _isLoading;
  String? get error => _error;

  @override
  void resetUserScope() {
    _serviceFees = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> fetchServiceFees({int? buildingId, bool? isActive}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _serviceFees = await _repo.fetchServiceFees(
        buildingId: buildingId,
        isActive: isActive,
      );
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Không thể tải dịch vụ';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ServiceFeeModel?> createServiceFee({
    required int buildingId,
    required String name,
    double unitPrice = 0,
    String billingCycle = 'monthly',
  }) async {
    try {
      final fee = await _repo.createServiceFee(
        buildingId: buildingId,
        name: name,
        unitPrice: unitPrice,
        billingCycle: billingCycle,
      );
      _serviceFees = [..._serviceFees, fee];
      notifyListeners();
      return fee;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<ServiceFeeModel?> updateServiceFee(
    int feeId, {
    String? name,
    double? unitPrice,
    String? billingCycle,
    bool? isActive,
  }) async {
    try {
      final updated = await _repo.updateServiceFee(
        feeId,
        name: name,
        unitPrice: unitPrice,
        billingCycle: billingCycle,
        isActive: isActive,
      );
      _serviceFees = _serviceFees
          .map((f) => f.id == updated.id ? updated : f)
          .toList();
      notifyListeners();
      return updated;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<ContractServiceFeeModel?> attachToContract({
    required int contractId,
    required int serviceFeeId,
    required double monthlyAmount,
  }) async {
    try {
      return await _repo.attachToContract(
        contractId: contractId,
        serviceFeeId: serviceFeeId,
        monthlyAmount: monthlyAmount,
      );
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> detachFromContract({
    required int contractId,
    required int feeId,
  }) async {
    try {
      await _repo.detachFromContract(contractId: contractId, feeId: feeId);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }
}
