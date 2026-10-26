import 'package:house_booking/data/models/building_model.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Repository for /api/host/buildings endpoints.
class ApiBuildingRepository {
  final ApiClient _client = const ApiClient();

  Future<List<BuildingModel>> fetchBuildings() async {
    final list = await _client.getList('/api/host/buildings');
    return list
        .map((e) => BuildingModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<BuildingModel> createBuilding({
    required String name,
    String address = '',
    String city = '',
    String district = '',
    String ward = '',
    String? note,
  }) async {
    final resp = await _client.post(
      '/api/host/buildings',
      body: {
        'name': name,
        'address': address,
        'city': city,
        'district': district,
        'ward': ward,
        if (note != null) 'note': note,
      },
    );
    return BuildingModel.fromJson(Map<String, dynamic>.from(resp as Map));
  }

  Future<BuildingModel> updateBuilding(
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
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (district != null) 'district': district,
      if (ward != null) 'ward': ward,
      if (note != null) 'note': note,
      if (giaDien != null) 'gia_dien': giaDien,
      if (giaNuoc != null) 'gia_nuoc': giaNuoc,
      if (phiDichVu != null) 'phi_dich_vu': phiDichVu,
    };
    final resp = await _client.patch(
      '/api/host/buildings/$buildingId',
      body: body,
    );
    return BuildingModel.fromJson(Map<String, dynamic>.from(resp as Map));
  }

  Future<void> deleteBuilding(int buildingId) async {
    await _client.delete('/api/host/buildings/$buildingId');
  }
}
