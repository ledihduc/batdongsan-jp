import 'package:house_booking/data/models/booking_availability.dart';
import 'package:house_booking/data/models/viewing_appointment_model.dart';

abstract class IViewingAppointmentRepository {
  Future<List<ViewingAppointmentModel>> getAppointments(int userId, String role);
  Future<bool> createAppointment(ViewingAppointmentModel appointment);
  Future<bool> updateAppointmentStatus(int appointmentId, String status);

  /// R7 — từ lịch ĐÃ XEM sang lịch HẸN GẶP để chốt phòng. Trả lịch mới.
  Future<ViewingAppointmentModel> henChot(
    int appointmentId, {
    required String date,
    required String timeSlot,
    String message,
  });

  /// Khung giờ khách có thể đặt cho 1 ngày (open/taken).
  Future<List<AvailableSlot>> getAvailableSlots(int houseId, String date);

  /// Khung giờ của một PHÒNG trong dự án — dùng khi phòng chưa gắn tin nào,
  /// nên không có `houseId` để hỏi.
  Future<List<AvailableSlot>> getRoomSlots(int roomId, String date);

  /// Cấu hình khung giờ chủ nhà đang mở (chỉ chủ tin / admin).
  Future<HostAvailability> getHostAvailability(int houseId);

  /// Lưu cấu hình khung giờ chủ nhà nhận đặt xem.
  Future<HostAvailability> saveHostAvailability(
      int houseId, List<int> weekdays, List<String> slots);
}
