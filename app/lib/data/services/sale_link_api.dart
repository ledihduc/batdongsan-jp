import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/models/building_model.dart';

/// Mã liên kết sale ↔ chủ phòng (`/api/sales/me/code`, `/api/owner-links`).
///
/// Khác các API đọc khác trong app: ở đây **không nuốt lỗi**. Liên kết là hành
/// động đổi trạng thái tài khoản, người dùng phải biết vì sao hỏng ("mã sai"
/// khác "mất mạng" khác "bạn đã có sale khác").
class SaleLinkApi {
  const SaleLinkApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<MaLienKet> maCuaToi() async =>
      MaLienKet.fromMap(await _c.get('/api/sales/me/code'));

  Future<MaLienKet> doiMa() async =>
      MaLienKet.fromMap(await _c.post('/api/sales/me/code/regenerate'));

  /// Tra mã để XEM sale là ai. Không tạo liên kết.
  Future<SaleTomTat> traMa(String code, {required int buildingId}) async =>
      SaleTomTat.fromMap(
        await _c.post(
          '/api/owner-links/resolve-code',
          body: {'code': code, 'building_id': buildingId},
        ),
      );

  Future<LienKet> lienKet(String code, {required int buildingId}) async =>
      LienKet.fromMap(
        await _c.post(
          '/api/owner-links',
          body: {'code': code, 'building_id': buildingId},
        ),
      );

  Future<List<BuildingModel>> toaCuaToi() async =>
      (await _c.getList(
            '/api/host/buildings',
            queryParameters: {'owned_only': true},
          ))
          .whereType<Map>()
          .map((e) => BuildingModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

  Future<List<LienKet>> cuaToiBenChu() async =>
      _ds(await _c.getList('/api/owner-links/me'));

  Future<List<LienKet>> cuaToiBenSale() async =>
      _ds(await _c.getList('/api/sales/me/owners'));

  Future<void> ngat(int linkId, {String? lyDo}) async {
    await _c.post('/api/owner-links/$linkId/end', body: {'reason': ?lyDo});
  }

  Future<void> chuyen(int linkId, String maSaleMoi) async {
    await _c.post(
      '/api/owner-links/$linkId/transfer',
      body: {'code': maSaleMoi},
    );
  }

  List<LienKet> _ds(List<dynamic> r) => r
      .whereType<Map>()
      .map((e) => LienKet.fromMap(Map<String, dynamic>.from(e)))
      .toList();
}

class MaLienKet {
  const MaLienKet({required this.ma, required this.soChuPhong});

  final String ma;
  final int soChuPhong;

  factory MaLienKet.fromMap(Map<String, dynamic> m) => MaLienKet(
    ma: m['sale_code'] as String? ?? '',
    soChuPhong: (m['so_chu_phong'] as num?)?.toInt() ?? 0,
  );
}

class SaleTomTat {
  const SaleTomTat({
    required this.saleId,
    required this.ten,
    required this.daLienKet,
    this.avatar,
    this.buildingId,
    this.buildingName,
    this.gioiThieu,
    this.khuVuc = const [],
  });

  final int saleId;
  final String ten;
  final bool daLienKet;
  final String? avatar;
  final int? buildingId;
  final String? buildingName;
  final String? gioiThieu;
  final List<String> khuVuc;

  factory SaleTomTat.fromMap(Map<String, dynamic> m) => SaleTomTat(
    saleId: (m['sale_id'] as num?)?.toInt() ?? 0,
    ten: m['ten'] as String? ?? '',
    daLienKet: m['da_lien_ket'] == true,
    avatar: m['avatar'] as String?,
    buildingId: (m['building_id'] as num?)?.toInt(),
    buildingName: m['building_name'] as String?,
    gioiThieu: m['gioi_thieu'] as String?,
    khuVuc: (m['khu_vuc'] as List? ?? const []).whereType<String>().toList(),
  );
}

class LienKet {
  const LienKet({
    required this.id,
    required this.saleId,
    required this.ownerId,
    required this.tenDoiPhuong,
    required this.trangThai,
    this.avatarDoiPhuong,
    this.buildingId,
    this.buildingName,
  });

  final int id;
  final int saleId;
  final int ownerId;
  final String tenDoiPhuong;
  final String trangThai;
  final String? avatarDoiPhuong;
  final int? buildingId;
  final String? buildingName;

  factory LienKet.fromMap(Map<String, dynamic> m) => LienKet(
    id: (m['id'] as num).toInt(),
    saleId: (m['sale_id'] as num?)?.toInt() ?? 0,
    ownerId: (m['owner_id'] as num?)?.toInt() ?? 0,
    tenDoiPhuong: m['ten_doi_phuong'] as String? ?? '',
    trangThai: m['status'] as String? ?? '',
    avatarDoiPhuong: m['avatar_doi_phuong'] as String?,
    buildingId: (m['building_id'] as num?)?.toInt(),
    buildingName: m['building_name'] as String?,
  );
}
