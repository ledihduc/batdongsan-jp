import 'package:flutter/foundation.dart';

import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/data/models/marketplace_sync_model.dart';
import 'package:house_booking/data/repositories/api_marketplace_repository.dart';

/// Phase 08 — manages sync status list + publish/unpublish + booking conversion.
class MarketplaceProvider extends ChangeNotifier implements UserScoped {
  final ApiMarketplaceRepository _repo = ApiMarketplaceRepository();

  List<SyncStatusItem> _items = const [];
  bool _isLoading = false;
  String? _error;
  PublishRoomResult? _lastPublish;
  CreateContractFromApptResult? _lastContract;

  List<SyncStatusItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  PublishRoomResult? get lastPublish => _lastPublish;
  CreateContractFromApptResult? get lastContract => _lastContract;

  @override
  void resetUserScope() {
    _items = const [];
    _isLoading = false;
    _error = null;
    _lastPublish = null;
    _lastContract = null;
    notifyListeners();
  }

  Future<void> fetchSyncStatus() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _repo.fetchSyncStatus();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> publishRoom(
    int roomId, {
    String? title,
    String? description,
    double? price,
    String? productType,
  }) async {
    _error = null;
    try {
      _lastPublish = await _repo.publishRoom(
        roomId,
        title: title,
        description: description,
        price: price,
        productType: productType,
      );
      await fetchSyncStatus();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> unpublishRoom(int roomId) async {
    _error = null;
    try {
      await _repo.unpublishRoom(roomId);
      await fetchSyncStatus();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<CreateContractFromApptResult?> createContractFromAppointment(
    int appointmentId,
  ) async {
    _error = null;
    try {
      _lastContract = await _repo.createContractFromAppointment(appointmentId);
      notifyListeners();
      return _lastContract;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> approveReservationFromBooking(int reservationId) async {
    _error = null;
    try {
      await _repo.approveReservationFromBooking(reservationId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
