import 'package:house_booking/data/models/marketplace_sync_model.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Phase 08 — marketplace ↔ ops integration endpoints under
/// `/api/host/marketplace/*`. Mirrors `app/routers/marketplace_integration.py`.
class ApiMarketplaceRepository {
  final ApiClient _client = const ApiClient();

  Future<PublishRoomResult> publishRoom(
    int roomId, {
    String? title,
    String? description,
    double? price,
    String? productType,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (price != null) body['price'] = price;
    if (productType != null) body['product_type'] = productType;

    final resp = await _client.post(
      '/api/host/marketplace/rooms/$roomId/publish',
      body: body,
    );
    return PublishRoomResult.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<void> unpublishRoom(int roomId) async {
    await _client.post(
      '/api/host/marketplace/rooms/$roomId/unpublish',
      body: const <String, dynamic>{},
    );
  }

  Future<List<SyncStatusItem>> fetchSyncStatus() async {
    final resp = await _client.getList('/api/host/marketplace/sync-status');
    return resp
        .map((e) => SyncStatusItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CreateContractFromApptResult> createContractFromAppointment(
    int appointmentId,
  ) async {
    final resp = await _client.post(
      '/api/host/marketplace/contracts/from-appointment/$appointmentId',
      body: const <String, dynamic>{},
    );
    return CreateContractFromApptResult.fromJson(
      Map<String, dynamic>.from(resp),
    );
  }

  Future<Map<String, dynamic>> approveReservationFromBooking(
    int reservationId,
  ) async {
    final resp = await _client.post(
      '/api/host/marketplace/reservations/$reservationId/approve-from-booking',
      body: const <String, dynamic>{},
    );
    return Map<String, dynamic>.from(resp);
  }
}
