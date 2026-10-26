import 'package:flutter/material.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/data/models/booking_availability.dart';
import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/data/repositories/api_viewing_appointment_repository.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/i_viewing_appointment_repository.dart';

class ViewingAppointmentProvider with ChangeNotifier implements UserScoped {
  final IViewingAppointmentRepository _repository = ApiViewingAppointmentRepository();

  List<ViewingAppointmentModel> _appointments = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastFetchAt;

  int _pendingGuestCount = 0;
  int _pendingHostCount = 0;

  // ── Khung giờ đặt xem (SlotPicker) ──────────────────────────────────────────
  List<AvailableSlot> _availableSlots = [];
  bool _slotsLoading = false;
  String? _slotsError;
  bool _lastBookingConflict = false;

  // ── Cấu hình khung giờ chủ nhà (HostAvailabilityScreen) ─────────────────────
  HostAvailability? _hostAvailability;
  bool _availabilityLoading = false;
  bool _availabilitySaving = false;
  String? _availabilityError;

  List<ViewingAppointmentModel> get appointments => _appointments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<AvailableSlot> get availableSlots => _availableSlots;
  bool get slotsLoading => _slotsLoading;
  String? get slotsError => _slotsError;
  bool get lastBookingConflict => _lastBookingConflict;

  HostAvailability? get hostAvailability => _hostAvailability;
  bool get availabilityLoading => _availabilityLoading;
  bool get availabilitySaving => _availabilitySaving;
  String? get availabilityError => _availabilityError;

  int get pendingGuestCount => _pendingGuestCount;
  int get pendingHostCount => _pendingHostCount;

  /// True khi list cũ hơn `maxAgeSeconds` hoặc chưa fetch lần nào. Dùng cho
  /// BookingHistoryScreen.initState — tránh double-fetch với AuthWrapper
  /// đã hydrate ban đầu nhưng vẫn refresh khi user quay lại sau lâu.
  bool isStale({int maxAgeSeconds = 60}) {
    if (_lastFetchAt == null) return true;
    return DateTime.now().difference(_lastFetchAt!).inSeconds > maxAgeSeconds;
  }

  @override
  void resetUserScope() {
    _appointments = [];
    _isLoading = false;
    _errorMessage = null;
    _lastFetchAt = null;
    _pendingGuestCount = 0;
    _pendingHostCount = 0;
    _availableSlots = [];
    _slotsLoading = false;
    _slotsError = null;
    _lastBookingConflict = false;
    _hostAvailability = null;
    _availabilityLoading = false;
    _availabilitySaving = false;
    _availabilityError = null;
    notifyListeners();
  }

  /// Nạp khung giờ khách có thể đặt cho 1 ngày (open/taken). Không throw.
  /// Khung giờ của một tin, hoặc — khi `roomId` khác null — của một PHÒNG.
  ///
  /// Một hàm cho cả hai vì màn đặt lịch là một; tách đôi thì mỗi lần sửa xử lý
  /// lỗi phải nhớ sửa hai chỗ.
  Future<void> loadAvailableSlots(
    int? houseId,
    String date, {
    int? roomId,
  }) async {
    _slotsLoading = true;
    _slotsError = null;
    notifyListeners();
    try {
      _availableSlots = roomId != null
          ? await _repository.getRoomSlots(roomId, date)
          : await _repository.getAvailableSlots(houseId!, date);
    } catch (e) {
      _availableSlots = [];
      _slotsError = 'Không tải được khung giờ. Vui lòng thử lại.';
    } finally {
      _slotsLoading = false;
      notifyListeners();
    }
  }

  /// R7 — hẹn gặp để CHỐT phòng, nối tiếp một lịch đã xem.
  ///
  /// Trả `true` khi tạo được. Danh sách được nạp lại ở góc nhìn chủ nhà vì nút
  /// này chỉ nằm bên đó.
  Future<bool> henChot(
    int appointmentId, {
    required int hostId,
    required String date,
    required String timeSlot,
    String message = '',
  }) async {
    try {
      _errorMessage = null;
      await _repository.henChot(
        appointmentId,
        date: date,
        timeSlot: timeSlot,
        message: message,
      );
      _appointments = await _repository.getAppointments(hostId, 'host');
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Không tạo được lịch hẹn chốt.';
      notifyListeners();
      return false;
    }
  }

  /// Nạp cấu hình khung giờ chủ nhà (dùng ở HostAvailabilityScreen).
  Future<void> loadHostAvailability(int houseId) async {
    _availabilityLoading = true;
    _availabilityError = null;
    notifyListeners();
    try {
      _hostAvailability = await _repository.getHostAvailability(houseId);
    } catch (e) {
      _availabilityError = 'Không tải được cấu hình khung giờ.';
    } finally {
      _availabilityLoading = false;
      notifyListeners();
    }
  }

  /// Lưu cấu hình khung giờ chủ nhà. Trả true nếu thành công.
  Future<bool> saveHostAvailability(
      int houseId, List<int> weekdays, List<String> slots) async {
    _availabilitySaving = true;
    _availabilityError = null;
    notifyListeners();
    try {
      _hostAvailability =
          await _repository.saveHostAvailability(houseId, weekdays, slots);
      return true;
    } catch (e) {
      _availabilityError = 'Lưu cấu hình thất bại. Vui lòng thử lại.';
      return false;
    } finally {
      _availabilitySaving = false;
      notifyListeners();
    }
  }

  Future<void> refreshBadgeCounts(int userId) async {
    try {
      final futures = await Future.wait([
        _repository.getAppointments(userId, 'guest'),
        _repository.getAppointments(userId, 'host'),
      ]);
      _pendingGuestCount =
          futures[0].where((b) => b.status == 'pending').length;
      _pendingHostCount =
          futures[1].where((b) => b.status == 'pending').length;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchAppointments(int userId, String role) async {
    _isLoading = true;
    notifyListeners();

    try {
      _appointments = await _repository.getAppointments(userId, role);
      _lastFetchAt = DateTime.now();
    } catch (e) {
      _errorMessage = 'Lỗi tải danh sách: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createNewAppointment({
    int? houseId,
    int? roomId,
    required int guestId,
    required String date,
    required String timeSlot,
    required String message,
  }) async {
    _isLoading = true;
    notifyListeners();

    final appointment = ViewingAppointmentModel(
      houseId: houseId,
      roomId: roomId,
      guestId: guestId,
      bookingDate: date,
      bookingTime: timeSlot,
      message: message,
      status: 'pending',
    );

    try {
      _errorMessage = null;
      _lastBookingConflict = false;
      final success = await _repository.createAppointment(appointment);
      if (success) {
        // Refresh list
        _appointments = await _repository.getAppointments(guestId, 'guest');
        return true;
      }
      _errorMessage = 'Gửi yêu cầu đặt lịch thất bại.';
      return false;
    } on ApiException catch (e) {
      // 409 = khung giờ đã bị đặt; hiển thị đúng thông báo backend + báo hiệu
      // để màn hình refresh lại danh sách slot.
      _lastBookingConflict = e.statusCode == 409;
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Lỗi kết nối, vui lòng thử lại.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Chốt phòng cho 1 appointment → backend tự lo các appointment khác + giảm available + tạo notif.
  Future<bool> lockAppointment(int appointmentId, int userId, String role) async {
    return updateStatus(appointmentId, 'locked', userId, role);
  }

  Future<bool> updateStatus(int appointmentId, String status, int userId, String role) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _repository.updateAppointmentStatus(appointmentId, status);
      if (success) {
        _appointments = await _repository.getAppointments(userId, role);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Lỗi cập nhật: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
