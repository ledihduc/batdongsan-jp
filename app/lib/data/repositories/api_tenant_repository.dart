import 'package:house_booking/data/models/tenant_model.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Repository for /api/host/tenants endpoints.
class ApiTenantRepository {
  final ApiClient _client = const ApiClient();

  Future<List<TenantModel>> fetchTenants({String? query}) async {
    final params = <String, dynamic>{
      if (query != null && query.isNotEmpty) 'q': query,
    };
    final list = await _client.getList(
      '/api/host/tenants',
      queryParameters: params,
    );
    return list
        .map((e) => TenantModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<TenantModel> createTenant({
    required String fullName,
    String phone = '',
    String? email,
    String? birthday,
    String? addressOrigin,
  }) async {
    final resp = await _client.post(
      '/api/host/tenants',
      body: {
        'full_name': fullName,
        'phone': phone,
        if (email != null) 'email': email,
        if (birthday != null) 'birthday': birthday,
        if (addressOrigin != null) 'address_origin': addressOrigin,
      },
    );
    return TenantModel.fromJson(Map<String, dynamic>.from(resp));
  }
}
