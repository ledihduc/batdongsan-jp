import 'package:house_booking/data/services/api_client.dart';

/// Điện nước DÀI HẠN — người thuê gửi chỉ số + ảnh công tơ, chủ nhà duyệt.
///
///     GET  /api/host/dien-nuoc?building_id=&thang=YYYY-MM
///     POST /api/host/dien-nuoc/{id}/duyet
///     POST /api/host/dien-nuoc/{id}/chup-lai
///     POST /api/guest/dien-nuoc
class DienNuocApi {
  const DienNuocApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<BangDienNuoc> bangThang(int buildingId, String thang) async =>
      BangDienNuoc.fromMap(
        await _c.get(
          '/api/host/dien-nuoc',
          queryParameters: {'building_id': buildingId, 'thang': thang},
        ),
      );

  /// Chi tiết MỘT phòng MỘT tháng: chỉ số, ảnh công tơ, tiền điện / nước,
  /// % so với tháng trước và lịch sử 6 tháng.
  Future<ChiTietDienNuoc> chiTietPhong(int roomId, String thang) async =>
      ChiTietDienNuoc.fromMap(
        await _c.get(
          '/api/host/dien-nuoc/phong',
          queryParameters: {'room_id': roomId, 'thang': thang},
        ),
      );

  /// Chủ nhà TỰ chụp công tơ trong app rồi ghi luôn chỉ số.
  /// `chupLuc` là giờ MÁY chụp (ISO), `lat`/`lng` là toạ độ lúc bấm chụp —
  /// thiếu toạ độ vẫn gửi được, người dùng có quyền từ chối chia sẻ vị trí.
  Future<void> chuNhaChup(
    int roomId, {
    required String loai,
    required double chiSo,
    required String anh,
    required String chupLuc,
    double? lat,
    double? lng,
  }) async {
    await _c.post(
      '/api/host/dien-nuoc/phong/$roomId/chup',
      body: {
        'loai': loai,
        'chi_so': chiSo,
        'anh': anh,
        'chup_luc': chupLuc,
        'lat': ?lat,
        'lng': ?lng,
      },
    );
  }

  Future<void> duyet(int readingId) async {
    await _c.post('/api/host/dien-nuoc/$readingId/duyet');
  }

  Future<void> chupLai(int readingId, String lyDo) async {
    await _c.post(
      '/api/host/dien-nuoc/$readingId/chup-lai',
      body: {'ly_do': lyDo},
    );
  }

  /// Người thuê gửi chỉ số tháng này cho phòng MÌNH đang thuê.
  Future<void> gui({
    required int contractId,
    required double dien,
    required double nuoc,
    String? anhDien,
    String? anhNuoc,
  }) async {
    await _c.post(
      '/api/guest/dien-nuoc',
      body: {
        'contract_id': contractId,
        'electricity_kwh': dien,
        'water_m3': nuoc,
        if (anhDien != null) 'anh_dien': anhDien,
        if (anhNuoc != null) 'anh_nuoc': anhNuoc,
      },
    );
  }
}

double? _d(dynamic v) => (v as num?)?.toDouble();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

/// Chuỗi rỗng từ server = "không có", không phải giá trị.
String? _s(dynamic v) {
  final s = (v as String?)?.trim();
  return s == null || s.isEmpty ? null : s;
}

class BangDienNuoc {
  const BangDienNuoc({
    required this.buildingId,
    required this.tenToa,
    required this.thang,
    required this.tongPhong,
    required this.daGui,
    required this.choDuyet,
    required this.thieuAnh,
    required this.daDuyet,
    required this.chuaGui,
    required this.tongTamTinh,
    required this.dong,
  });

  final int buildingId;
  final String tenToa;
  final String thang;
  final int tongPhong;
  final int daGui;
  final int choDuyet;
  final int thieuAnh;
  final int daDuyet;
  final int chuaGui;
  final double tongTamTinh;
  final List<DongDienNuoc> dong;

  factory BangDienNuoc.fromMap(Map<String, dynamic> m) => BangDienNuoc(
    buildingId: _i(m['building_id']),
    tenToa: m['ten_toa'] as String? ?? '',
    thang: m['thang'] as String? ?? '',
    tongPhong: _i(m['tong_phong']),
    daGui: _i(m['da_gui']),
    choDuyet: _i(m['cho_duyet']),
    thieuAnh: _i(m['thieu_anh']),
    daDuyet: _i(m['da_duyet']),
    chuaGui: _i(m['chua_gui']),
    tongTamTinh: _d(m['tong_tam_tinh']) ?? 0,
    dong: [
      for (final e in (m['dong'] as List? ?? const []).whereType<Map>())
        DongDienNuoc.fromMap(Map<String, dynamic>.from(e)),
    ],
  );
}

/// Một tháng trong biểu đồ lịch sử. `dienDung == null` = tháng đó CHƯA có chỉ
/// số — khác 0 (đã chốt số mà không dùng gì).
class ThangDienNuoc {
  const ThangDienNuoc({
    required this.thang,
    this.dienDung,
    this.nuocDung,
    this.thanhTien,
    this.trangThai = 'chua_gui',
  });

  /// 'YYYY-MM'.
  final String thang;
  final double? dienDung;
  final double? nuocDung;
  final double? thanhTien;
  final String trangThai;

  factory ThangDienNuoc.fromMap(Map<String, dynamic> m) => ThangDienNuoc(
    thang: m['thang'] as String? ?? '',
    dienDung: _d(m['dien_dung']),
    nuocDung: _d(m['nuoc_dung']),
    thanhTien: _d(m['thanh_tien']),
    trangThai: m['trang_thai'] as String? ?? 'chua_gui',
  );
}

/// Điện nước của MỘT phòng trong MỘT tháng: chỉ số, ảnh công tơ, tiền điện /
/// nước, % so với tháng trước và lịch sử 6 tháng.
class ChiTietDienNuoc {
  const ChiTietDienNuoc({
    required this.roomId,
    required this.maPhong,
    required this.thang,
    this.buildingId = 0,
    this.tenToa = '',
    this.nguoiThue = '',
    this.hopDongDen = '',
    this.trangThai = 'chua_gui',
    this.readingId,
    this.ngayChot,
    this.guiLuc,
    this.nguoiGui = '',
    this.duyetLuc,
    this.dienCu,
    this.dienMoi,
    this.dienDung,
    this.nuocCu,
    this.nuocMoi,
    this.nuocDung,
    this.giaDien = 0,
    this.giaNuoc = 0,
    this.tienDien,
    this.tienNuoc,
    this.thanhTien,
    this.anhDien,
    this.anhNuoc,
    this.lyDoTraVe,
    this.dienPhanTram,
    this.nuocPhanTram,
    this.tienPhanTram,
    this.lichSu = const [],
    this.chupLuc,
    this.chupLat,
    this.chupLng,
    this.nguonAnh,
  });

  final int roomId;
  final String maPhong;

  /// 'YYYY-MM'.
  final String thang;
  final int buildingId;
  final String tenToa;
  final String nguoiThue;
  final String hopDongDen;

  /// 'chua_gui' | 'cho_duyet' | 'thieu_anh' | 'can_chup_lai' | 'da_duyet'
  final String trangThai;

  /// `null` = tháng này chưa có ai gửi chỉ số.
  final int? readingId;
  final String? ngayChot;
  final String? guiLuc;

  /// Rỗng = chủ nhà tự ghi, không phải người thuê gửi.
  final String nguoiGui;
  final String? duyetLuc;
  final double? dienCu;
  final double? dienMoi;
  final double? dienDung;
  final double? nuocCu;
  final double? nuocMoi;
  final double? nuocDung;
  final double giaDien;
  final double giaNuoc;
  final double? tienDien;
  final double? tienNuoc;
  final double? thanhTien;
  final String? anhDien;
  final String? anhNuoc;
  final String? lyDoTraVe;

  /// % thay đổi so với tháng trước; `null` = không có tháng trước để so.
  final int? dienPhanTram;
  final int? nuocPhanTram;
  final int? tienPhanTram;

  /// Cũ → mới, tháng đang xem đứng cuối.
  final List<ThangDienNuoc> lichSu;

  /// Giờ MÁY chụp ảnh (ISO) — chỉ có khi ảnh chụp thẳng trong app.
  final String? chupLuc;
  final double? chupLat;
  final double? chupLng;

  /// 'chu_nha' = chủ nhà tự chụp; null / 'nguoi_thue' = người thuê gửi.
  final String? nguonAnh;

  factory ChiTietDienNuoc.fromMap(Map<String, dynamic> m) => ChiTietDienNuoc(
    roomId: _i(m['room_id']),
    maPhong: m['ma_phong'] as String? ?? '',
    thang: m['thang'] as String? ?? '',
    buildingId: _i(m['building_id']),
    tenToa: m['ten_toa'] as String? ?? '',
    nguoiThue: m['nguoi_thue'] as String? ?? '',
    hopDongDen: m['hop_dong_den'] as String? ?? '',
    trangThai: m['trang_thai'] as String? ?? 'chua_gui',
    readingId: (m['reading_id'] as num?)?.toInt(),
    ngayChot: m['ngay_chot'] as String?,
    guiLuc: m['gui_luc'] as String?,
    nguoiGui: m['nguoi_gui'] as String? ?? '',
    duyetLuc: m['duyet_luc'] as String?,
    dienCu: _d(m['dien_cu']),
    dienMoi: _d(m['dien_moi']),
    dienDung: _d(m['dien_dung']),
    nuocCu: _d(m['nuoc_cu']),
    nuocMoi: _d(m['nuoc_moi']),
    nuocDung: _d(m['nuoc_dung']),
    giaDien: _d(m['gia_dien']) ?? 0,
    giaNuoc: _d(m['gia_nuoc']) ?? 0,
    tienDien: _d(m['tien_dien']),
    tienNuoc: _d(m['tien_nuoc']),
    thanhTien: _d(m['thanh_tien']),
    anhDien: m['anh_dien'] as String?,
    anhNuoc: m['anh_nuoc'] as String?,
    lyDoTraVe: m['ly_do_tra_ve'] as String?,
    dienPhanTram: (m['dien_phan_tram'] as num?)?.toInt(),
    nuocPhanTram: (m['nuoc_phan_tram'] as num?)?.toInt(),
    tienPhanTram: (m['tien_phan_tram'] as num?)?.toInt(),
    lichSu: [
      for (final e in (m['lich_su'] as List? ?? const []).whereType<Map>())
        ThangDienNuoc.fromMap(Map<String, dynamic>.from(e)),
    ],
    chupLuc: _s(m['chup_luc']),
    chupLat: _d(m['chup_lat']),
    chupLng: _d(m['chup_lng']),
    nguonAnh: _s(m['nguon_anh']),
  );
}

class DongDienNuoc {
  const DongDienNuoc({
    required this.roomId,
    required this.maPhong,
    required this.trangThai,
    this.readingId,
    this.nguoiThue = '',
    this.hopDongDen = '',
    this.capNhat,
    this.dienMoi,
    this.dienCu,
    this.nuocMoi,
    this.nuocCu,
    this.dienDung,
    this.nuocDung,
    this.thanhTien,
    this.anhDien,
    this.anhNuoc,
    this.lyDoTraVe,
  });

  final int? readingId;
  final int roomId;
  final String maPhong;

  /// 'chua_gui' | 'cho_duyet' | 'da_duyet' | 'can_chup_lai' | 'thieu_anh'
  final String trangThai;
  final String nguoiThue;
  final String hopDongDen;
  final String? capNhat;
  final double? dienMoi;
  final double? dienCu;
  final double? nuocMoi;
  final double? nuocCu;
  final double? dienDung;
  final double? nuocDung;

  /// `null` khi chưa đủ hai mốc (chưa gửi, hoặc chưa có mốc tháng trước).
  final double? thanhTien;
  final String? anhDien;
  final String? anhNuoc;
  final String? lyDoTraVe;

  factory DongDienNuoc.fromMap(Map<String, dynamic> m) => DongDienNuoc(
    readingId: (m['reading_id'] as num?)?.toInt(),
    roomId: _i(m['room_id']),
    maPhong: m['ma_phong'] as String? ?? '',
    trangThai: m['trang_thai'] as String? ?? 'chua_gui',
    nguoiThue: m['nguoi_thue'] as String? ?? '',
    hopDongDen: m['hop_dong_den'] as String? ?? '',
    capNhat: m['cap_nhat'] as String?,
    dienMoi: _d(m['dien_moi']),
    dienCu: _d(m['dien_cu']),
    nuocMoi: _d(m['nuoc_moi']),
    nuocCu: _d(m['nuoc_cu']),
    dienDung: _d(m['dien_dung']),
    nuocDung: _d(m['nuoc_dung']),
    thanhTien: _d(m['thanh_tien']),
    anhDien: m['anh_dien'] as String?,
    anhNuoc: m['anh_nuoc'] as String?,
    lyDoTraVe: m['ly_do_tra_ve'] as String?,
  );
}
