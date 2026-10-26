import 'package:house_booking/data/services/api_client.dart';

/// Đơn vị hành chính (tỉnh hoặc phường/xã) — {code, name}.
class AdminUnit {
  const AdminUnit({required this.code, required this.name});
  final String code;
  final String name;

  factory AdminUnit.fromMap(Map<String, dynamic> m) =>
      AdminUnit(code: m['code'].toString(), name: m['name'] as String);
}

/// Dịch vụ chọn địa giới khi đăng tin: master 2 cấp (tỉnh → phường/xã) +
/// reverse geocode cho map picker. Không nhập tay — chọn từ danh mục.
class LocationInputService {
  /// [client] chỉ để test bơm ApiClient giả — code sản phẩm dùng mặc định.
  const LocationInputService({ApiClient client = const ApiClient()})
    : _client = client;

  final ApiClient _client;

  Future<List<AdminUnit>> provinces() async {
    final res = await _client.get('/api/master/provinces');
    final list = List<Map<String, dynamic>>.from(res['provinces'] as List);
    return list.map(AdminUnit.fromMap).toList();
  }

  Future<List<AdminUnit>> wards(String provinceCode) async {
    final res = await _client.get(
      '/api/master/wards',
      queryParameters: {'province_code': provinceCode},
    );
    final list = List<Map<String, dynamic>>.from(res['wards'] as List);
    return list.map(AdminUnit.fromMap).toList();
  }

  /// Reverse geocode → địa chỉ + tỉnh/phường đã đối chiếu master (best-effort).
  /// null khi lỗi.
  Future<ReverseResult?> reverseGeocode(double lat, double lng) async {
    try {
      final res = await _client.get(
        '/api/geo/reverse',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      final name = res['display_name'];
      final prov = res['province'];
      final ward = res['ward'];
      return ReverseResult(
        address: name is String ? name : '',
        province: prov is Map
            ? AdminUnit.fromMap(Map<String, dynamic>.from(prov))
            : null,
        ward: ward is Map
            ? AdminUnit.fromMap(Map<String, dynamic>.from(ward))
            : null,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Kết quả reverse geocode: địa chỉ + tỉnh/phường đã match master (có thể null).
class ReverseResult {
  const ReverseResult({required this.address, this.province, this.ward});
  final String address;
  final AdminUnit? province;
  final AdminUnit? ward;
}
