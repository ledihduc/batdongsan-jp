import 'package:house_booking/data/models/booking_availability.dart';
import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/i_viewing_appointment_repository.dart';

class ApiViewingAppointmentRepository implements IViewingAppointmentRepository {
  final ApiClient _client = const ApiClient();

  @override
  Future<List<ViewingAppointmentModel>> getAppointments(
    int userId,
    String role,
  ) async {
    final response = await _client.get(
      '/api/viewing-appointments',
      queryParameters: {'userId': userId, 'role': role},
    );

    final appointments = List<Map<String, dynamic>>.from(
      response['bookings'] as List,
    );
    return appointments.map(ViewingAppointmentModel.fromMap).toList();
  }

  @override
  Future<bool> createAppointment(ViewingAppointmentModel appointment) async {
    // Lỗi (409 slot đã đặt, 400 không hợp lệ...) ném ApiException để provider bắt.
    await _client.post('/api/viewing-appointments', body: appointment.toMap());
    return true;
  }

  @override
  Future<bool> updateAppointmentStatus(int appointmentId, String status) async {
    await _client.patch(
      '/api/viewing-appointments/$appointmentId/status',
      body: {'status': status},
    );
    return true;
  }

  @override
  Future<ViewingAppointmentModel> henChot(
    int appointmentId, {
    required String date,
    required String timeSlot,
    String message = '',
  }) async {
    final res = await _client.post(
      '/api/viewing-appointments/$appointmentId/hen-chot',
      body: {
        'booking_date': date,
        'booking_time': timeSlot,
        if (message.isNotEmpty) 'message': message,
      },
    );
    return ViewingAppointmentModel.fromMap(
      Map<String, dynamic>.from(res['booking'] as Map),
    );
  }

  @override
  Future<List<AvailableSlot>> getAvailableSlots(
    int houseId,
    String date,
  ) async {
    final res = await _client.get(
      '/api/houses/$houseId/available-slots',
      queryParameters: {'date': date},
    );
    final list = List<Map<String, dynamic>>.from(
      res['slots'] as List? ?? const [],
    );
    return list.map(AvailableSlot.fromMap).toList();
  }

  @override
  Future<List<AvailableSlot>> getRoomSlots(int roomId, String date) async {
    final res = await _client.get(
      '/api/rooms/$roomId/available-slots',
      queryParameters: {'date': date},
    );
    final list = List<Map<String, dynamic>>.from(
      res['slots'] as List? ?? const [],
    );
    return list.map(AvailableSlot.fromMap).toList();
  }

  @override
  Future<HostAvailability> getHostAvailability(int houseId) async {
    final res = await _client.get('/api/houses/$houseId/availability');
    return HostAvailability.fromMap(res);
  }

  @override
  Future<HostAvailability> saveHostAvailability(
    int houseId,
    List<int> weekdays,
    List<String> slots,
  ) async {
    final res = await _client.put(
      '/api/houses/$houseId/availability',
      body: {
        'config': {'weekdays': weekdays, 'slots': slots},
      },
    );
    return HostAvailability.fromMap(res);
  }
}
