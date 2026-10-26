import 'package:flutter/foundation.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/data/models/reservation_model.dart';
import 'package:house_booking/data/repositories/api_homestay_repository.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Phase 07 — host's reservation list + lifecycle actions.
class ReservationProvider extends ChangeNotifier implements UserScoped {
  ReservationProvider({ApiHomestayRepository? repo})
      : _repo = repo ?? ApiHomestayRepository();

  final ApiHomestayRepository _repo;

  List<ReservationModel> _records = [];
  ReservationModel? _selected;
  String? _statusFilter;
  bool _isLoading = false;
  String? _error;

  List<ReservationModel> get records => List.unmodifiable(_records);
  ReservationModel? get selected => _selected;
  String? get statusFilter => _statusFilter;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get pendingCount => _records.where((r) => r.isPending).length;
  int get checkedInCount => _records.where((r) => r.isCheckedIn).length;

  @override
  void resetUserScope() {
    _records = [];
    _selected = null;
    _statusFilter = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> fetchList({String? status, int? roomId}) async {
    _statusFilter = status;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _records = await _repo.fetchReservations(status: status, roomId: roomId);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDetail(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _selected = await _repo.getReservation(id);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> approve(int id) => _runAction(() => _repo.approveReservation(id));

  Future<bool> reject(int id, String reason) =>
      _runAction(() => _repo.rejectReservation(id, reason));

  Future<bool> checkIn(int id) =>
      _runAction(() => _repo.checkInReservation(id));

  Future<bool> checkOut(int id) =>
      _runAction(() => _repo.checkOutReservation(id));

  Future<bool> cancel(int id, {String? reason}) =>
      _runAction(() => _repo.cancelReservation(id, reason: reason));

  Future<ReservationModel?> createManual({
    required int roomId,
    required String guestName,
    String? guestPhone,
    String? guestEmail,
    required String checkInDate,
    required String checkOutDate,
    String? note,
  }) async {
    try {
      final created = await _repo.createReservation(
        roomId: roomId,
        guestName: guestName,
        guestPhone: guestPhone,
        guestEmail: guestEmail,
        checkInDate: checkInDate,
        checkOutDate: checkOutDate,
        note: note,
        source: 'manual',
      );
      _records = [created, ..._records];
      notifyListeners();
      return created;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> _runAction(Future<ReservationModel> Function() action) async {
    try {
      final updated = await action();
      _replace(updated);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  void _replace(ReservationModel updated) {
    final i = _records.indexWhere((r) => r.id == updated.id);
    if (i >= 0) _records[i] = updated;
    if (_selected?.id == updated.id) _selected = updated;
    notifyListeners();
  }
}
