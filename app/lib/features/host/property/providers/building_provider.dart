import 'package:flutter/foundation.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/core/permissions/role_guard.dart';
import 'package:house_booking/data/models/building_model.dart';
import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/data/repositories/api_building_repository.dart';
import 'package:house_booking/data/services/api_client.dart';

/// BuildingProvider — manages list of buildings for the current host.
class BuildingProvider extends ChangeNotifier implements UserScoped {
  final ApiBuildingRepository _repo = ApiBuildingRepository();

  List<BuildingModel> _buildings = [];
  bool _isLoading = false;
  String? _error;

  List<BuildingModel> get buildings => List.unmodifiable(_buildings);
  bool get isLoading => _isLoading;
  String? get error => _error;

  @override
  void resetUserScope() {
    _buildings = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> fetchBuildings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _buildings = await _repo.fetchBuildings();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Không thể tải danh sách tòa nhà';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<BuildingModel?> createBuilding({
    required String name,
    String address = '',
    String city = '',
    String district = '',
    String ward = '',
    String? note,
  }) async {
    try {
      final b = await _repo.createBuilding(
        name: name,
        address: address,
        city: city,
        district: district,
        ward: ward,
        note: note,
      );
      _buildings = [..._buildings, b];
      notifyListeners();
      return b;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateBuilding(
    int buildingId, {
    String? name,
    String? address,
    String? city,
    String? district,
    String? ward,
    String? note,
    double? giaDien,
    double? giaNuoc,
    double? phiDichVu,
  }) async {
    try {
      final updated = await _repo.updateBuilding(
        buildingId,
        name: name,
        address: address,
        city: city,
        district: district,
        ward: ward,
        note: note,
        giaDien: giaDien,
        giaNuoc: giaNuoc,
        phiDichVu: phiDichVu,
      );
      _buildings = _buildings.map((b) => b.id == buildingId ? updated : b).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBuilding(int buildingId, {UserModel? actor}) async {
    if (actor != null && !RoleGuard.canHost(actor)) {
      throw const PermissionDeniedException(
        action: 'deleteBuilding',
        requiredRole: 'host',
      );
    }
    try {
      await _repo.deleteBuilding(buildingId);
      _buildings = _buildings.where((b) => b.id != buildingId).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }
}
