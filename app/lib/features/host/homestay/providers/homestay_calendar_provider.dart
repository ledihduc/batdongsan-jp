import 'package:flutter/foundation.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/data/models/homestay_calendar_model.dart';
import 'package:house_booking/data/repositories/api_homestay_repository.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Phase 07 — unified + per-room calendar state.
class HomestayCalendarProvider extends ChangeNotifier implements UserScoped {
  HomestayCalendarProvider({ApiHomestayRepository? repo})
      : _repo = repo ?? ApiHomestayRepository();

  final ApiHomestayRepository _repo;

  UnifiedCalendarResponse? _unified;
  CalendarResponse? _selected;
  String _month = _currentMonth();
  bool _isLoading = false;
  String? _error;

  UnifiedCalendarResponse? get unified => _unified;
  CalendarResponse? get selected => _selected;
  String get month => _month;
  bool get isLoading => _isLoading;
  String? get error => _error;

  static String _currentMonth() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    return '${now.year}-$mm';
  }

  @override
  void resetUserScope() {
    _unified = null;
    _selected = null;
    _month = _currentMonth();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Shift current month by ±N months and refetch unified calendar.
  Future<void> shiftMonth(int delta) async {
    final parts = _month.split('-');
    var y = int.parse(parts[0]);
    var m = int.parse(parts[1]) + delta;
    while (m < 1) {
      m += 12;
      y -= 1;
    }
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    _month = '$y-${m.toString().padLeft(2, '0')}';
    await fetchUnified();
  }

  Future<void> fetchUnified() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _unified = await _repo.fetchUnifiedCalendar(_month);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRoom(int roomId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _selected = await _repo.fetchRoomCalendar(roomId: roomId, month: _month);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Block / unblock a date range, then refresh the current view.
  Future<bool> blockRange({
    required int roomId,
    required String startDate,
    required String endDate,
    required String action,
    String? note,
  }) async {
    try {
      await _repo.blockAvailability(
        roomId: roomId,
        startDate: startDate,
        endDate: endDate,
        action: action,
        note: note,
      );
      // Refresh whichever view is currently active.
      if (_selected != null && _selected!.roomId == roomId) {
        await fetchRoom(roomId);
      } else {
        await fetchUnified();
      }
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }
}
