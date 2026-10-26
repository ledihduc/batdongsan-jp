import 'package:house_booking/data/services/api_client.dart';

/// HẠNG PHÒNG của toà lưu trú ngắn hạn.
///
///     GET    /api/host/buildings/{id}/loai-phong
///     POST   /api/host/buildings/{id}/loai-phong
///     PATCH  /api/host/loai-phong/{id}
///     DELETE /api/host/loai-phong/{id}
///     POST   /api/host/loai-phong/{id}/phong     xếp danh sách phòng vào hạng
///     GET    /api/host/toa-va-hang               toà + hạng cho form đăng tin
///
/// Khách đặt HẠNG chứ không đặt số phòng, nên hạng là nơi khai giá và là đơn vị
/// để đếm "còn mấy phòng trống". Phòng chỉ ghi đè giá khi thật sự khác.
class LoaiPhongApi {
  const LoaiPhongApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<BangLoaiPhong> danhSach(int buildingId) async => BangLoaiPhong.fromMap(
    await _c.get('/api/host/buildings/$buildingId/loai-phong'),
  );

  Future<int> tao(
    int buildingId, {
    required String ten,
    String? moTa,
    int sucChua = 2,
    double? dienTich,
    String? giuong,
    List<String> anh = const [],
    List<String> tienNghi = const [],
    double? giaTheoGio,
    double? giaQuaDem,
    double? giaTheoNgay,
    List<int> roomIds = const [],
  }) async {
    final ra = await _c.post(
      '/api/host/buildings/$buildingId/loai-phong',
      body: {
        'ten': ten,
        'mo_ta': ?moTa,
        'suc_chua': sucChua,
        'dien_tich': ?dienTich,
        'giuong': ?giuong,
        'anh': anh,
        'tien_nghi': tienNghi,
        'gia_theo_gio': ?giaTheoGio,
        'gia_qua_dem': ?giaQuaDem,
        'gia_theo_ngay': ?giaTheoNgay,
        'room_ids': roomIds,
      },
    );
    return (ra['id'] as num?)?.toInt() ?? 0;
  }

  /// Chỉ gửi những khoá THẬT SỰ đổi: `null` ở server nghĩa là "không đụng tới",
  /// nên muốn xoá giá phải đi đường khác chứ không gửi null.
  Future<void> sua(int loaiId, Map<String, Object?> thayDoi) async {
    await _c.patch('/api/host/loai-phong/$loaiId', body: thayDoi);
  }

  Future<void> xoa(int loaiId) async {
    await _c.delete('/api/host/loai-phong/$loaiId');
  }

  /// Toà + hạng mà tôi được neo tin ngắn hạn vào — form đăng tin dựng 2 ô chọn
  /// nối nhau từ một lượt gọi (hỏi riêng thì app phải tự ghép và tự đoán toà
  /// nào chưa có hạng nào).
  Future<List<ToaCoHang>> toaVaHang() async {
    final m = await _c.get('/api/host/toa-va-hang');
    return [
      for (final x in (m['toa'] as List? ?? const []))
        ToaCoHang.fromMap((x as Map).cast<String, dynamic>()),
    ];
  }

  /// THAY THẾ danh sách phòng của hạng — bỏ tích là phòng ra khỏi hạng.
  Future<int> ganPhong(int loaiId, List<int> roomIds) async {
    final ra = await _c.post(
      '/api/host/loai-phong/$loaiId/phong',
      body: {'room_ids': roomIds},
    );
    return (ra['so_phong'] as num?)?.toInt() ?? 0;
  }
}

double? _d(dynamic v) => (v as num?)?.toDouble();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

String? _s(dynamic v) {
  final s = (v as String?)?.trim();
  return s == null || s.isEmpty ? null : s;
}

class PhongTrongHang {
  const PhongTrongHang({
    required this.id,
    required this.ma,
    this.trangThai = 'vacant',
    this.coKhach = false,
  });

  factory PhongTrongHang.fromMap(Map<String, dynamic> m) => PhongTrongHang(
    id: _i(m['id']),
    ma: m['ma'] as String? ?? '',
    trangThai: m['trang_thai'] as String? ?? 'vacant',
    coKhach: m['co_khach'] == true,
  );

  final int id;
  final String ma;
  final String trangThai;
  final bool coKhach;

  bool get baoTri => trangThai == 'maintenance';
}

class LoaiPhong {
  const LoaiPhong({
    required this.id,
    required this.ten,
    this.moTa,
    this.sucChua = 2,
    this.dienTich,
    this.giuong,
    this.anh = const [],
    this.tienNghi = const [],
    this.giaTheoGio,
    this.giaQuaDem,
    this.giaTheoNgay,
    this.giaGioHieuLuc,
    this.giaDemHieuLuc,
    this.giaNgayHieuLuc,
    this.thuTu = 0,
    this.dangBan = true,
    this.soPhong = 0,
    this.dangCoKhach = 0,
    this.baoTri = 0,
    this.trong = 0,
    this.phong = const [],
  });

  factory LoaiPhong.fromMap(Map<String, dynamic> m) {
    final gia = (m['gia_hieu_luc'] as Map?)?.cast<String, dynamic>() ?? const {};
    return LoaiPhong(
      id: _i(m['id']),
      ten: m['ten'] as String? ?? '',
      moTa: _s(m['mo_ta']),
      sucChua: _i(m['suc_chua']),
      dienTich: _d(m['dien_tich']),
      giuong: _s(m['giuong']),
      anh: [for (final x in (m['anh'] as List? ?? const [])) '$x'],
      tienNghi: [for (final x in (m['tien_nghi'] as List? ?? const [])) '$x'],
      giaTheoGio: _d(m['gia_theo_gio']),
      giaQuaDem: _d(m['gia_qua_dem']),
      giaTheoNgay: _d(m['gia_theo_ngay']),
      giaGioHieuLuc: _d(gia['gia_theo_gio']),
      giaDemHieuLuc: _d(gia['gia_qua_dem']),
      giaNgayHieuLuc: _d(gia['gia_theo_ngay']),
      thuTu: _i(m['thu_tu']),
      dangBan: m['dang_ban'] != false,
      soPhong: _i(m['so_phong']),
      dangCoKhach: _i(m['dang_co_khach']),
      baoTri: _i(m['bao_tri']),
      trong: _i(m['trong']),
      phong: [
        for (final x in (m['phong'] as List? ?? const []))
          PhongTrongHang.fromMap((x as Map).cast<String, dynamic>()),
      ],
    );
  }

  final int id;
  final String ten;
  final String? moTa;
  final int sucChua;
  final double? dienTich;
  final String? giuong;
  final List<String> anh;
  final List<String> tienNghi;

  /// Giá khai Ở HẠNG — `null` = hạng không bán hình thức đó.
  final double? giaTheoGio;
  final double? giaQuaDem;
  final double? giaTheoNgay;

  /// Giá ĐANG ÁP (hạng, hoặc của phòng nếu phòng khai riêng).
  final double? giaGioHieuLuc;
  final double? giaDemHieuLuc;
  final double? giaNgayHieuLuc;

  final int thuTu;
  final bool dangBan;
  final int soPhong;
  final int dangCoKhach;
  final int baoTri;

  /// Số phòng dùng được ngay bây giờ = tổng − đang có khách − bảo trì.
  final int trong;
  final List<PhongTrongHang> phong;
}

class BangLoaiPhong {
  const BangLoaiPhong({
    required this.buildingId,
    this.loaiPhong = const [],
    this.chuaXepHang = const [],
    this.tongPhong = 0,
  });

  factory BangLoaiPhong.fromMap(Map<String, dynamic> m) => BangLoaiPhong(
    buildingId: _i(m['building_id']),
    loaiPhong: [
      for (final x in (m['loai_phong'] as List? ?? const []))
        LoaiPhong.fromMap((x as Map).cast<String, dynamic>()),
    ],
    chuaXepHang: [
      for (final x in (m['chua_xep_hang'] as List? ?? const []))
        PhongTrongHang.fromMap((x as Map).cast<String, dynamic>()),
    ],
    tongPhong: _i(m['tong_phong']),
  );

  final int buildingId;
  final List<LoaiPhong> loaiPhong;

  /// Phòng chưa thuộc hạng nào — khách không đặt được theo hạng, phải nhắc.
  final List<PhongTrongHang> chuaXepHang;
  final int tongPhong;
}

/// Một hạng trong ô chọn của form đăng tin — đủ để người đăng nhận ra hạng và
/// thấy tin sẽ bán bao nhiêu phòng, không cần mở màn quản lý hạng.
class HangDeChon {
  const HangDeChon({
    required this.id,
    required this.ten,
    this.sucChua = 0,
    this.dienTich,
    this.giuong,
    this.giaTheoGio,
    this.giaQuaDem,
    this.giaTheoNgay,
    this.dangBan = true,
    this.soPhong = 0,
  });

  factory HangDeChon.fromMap(Map<String, dynamic> m) => HangDeChon(
    id: _i(m['id']),
    ten: m['ten'] as String? ?? '',
    sucChua: _i(m['suc_chua']),
    dienTich: _d(m['dien_tich']),
    giuong: _s(m['giuong']),
    giaTheoGio: _d(m['gia_theo_gio']),
    giaQuaDem: _d(m['gia_qua_dem']),
    giaTheoNgay: _d(m['gia_theo_ngay']),
    dangBan: m['dang_ban'] != false,
    soPhong: _i(m['so_phong']),
  );

  final int id;
  final String ten;
  final int sucChua;
  final double? dienTich;
  final String? giuong;
  final double? giaTheoGio;
  final double? giaQuaDem;
  final double? giaTheoNgay;
  final bool dangBan;

  /// Số phòng thuộc hạng — chính là tồn kho của tin, người đăng không gõ lại.
  final int soPhong;
}

class ToaCoHang {
  const ToaCoHang({
    required this.id,
    required this.ten,
    this.diaChi = '',
    this.hang = const [],
  });

  factory ToaCoHang.fromMap(Map<String, dynamic> m) => ToaCoHang(
    id: _i(m['id']),
    ten: m['ten'] as String? ?? '',
    diaChi: m['dia_chi'] as String? ?? '',
    hang: [
      for (final x in (m['hang'] as List? ?? const []))
        HangDeChon.fromMap((x as Map).cast<String, dynamic>()),
    ],
  );

  final int id;
  final String ten;
  final String diaChi;
  final List<HangDeChon> hang;
}
