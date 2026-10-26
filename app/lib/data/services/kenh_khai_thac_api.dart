import 'package:house_booking/data/services/api_client.dart';

/// KÊNH KHAI THÁC của phòng (`/api/host/rooms/{id}/kenh`).
///
/// Bốn pipeline, bốn nghiệp vụ khác nhau — không phải bốn cái tên của cùng một
/// thứ. Một phòng chạy được NHIỀU kênh cùng lúc: tháng này cho thuê đêm, tháng
/// sau cho thuê dài hạn, rồi đem bán. Đó là lý do đây là danh sách chứ không
/// phải một ô chọn.
class KenhKhaiThacApi {
  const KenhKhaiThacApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<List<KenhKhaiThac>> cuaPhong(int roomId) async {
    final r = await _c.getList('/api/host/rooms/$roomId/kenh');
    return r
        .whereType<Map>()
        .map((e) => KenhKhaiThac.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<KenhKhaiThac> dat(
    int roomId,
    String kenh, {
    required double gia,
    int? toiThieu,
    double? datCoc,
    int? mienPhiThang,
    bool dangBat = true,
  }) async => KenhKhaiThac.fromMap(
    await _c.put(
      '/api/host/rooms/$roomId/kenh/$kenh',
      body: {
        'gia': gia,
        if (toiThieu != null) 'toi_thieu': toiThieu,
        if (datCoc != null) 'dat_coc': datCoc,
        if (mienPhiThang != null) 'mien_phi_thang': mienPhiThang,
        'dang_bat': dangBat,
      },
    ),
  );

  Future<KenhKhaiThac> doiTrangThai(
    int roomId,
    String kenh,
    String trangThai,
  ) async => KenhKhaiThac.fromMap(
    await _c.post(
      '/api/host/rooms/$roomId/kenh/$kenh/trang-thai',
      body: {'trang_thai': trangThai},
    ),
  );

  Future<KenhKhaiThac> raoLai(int roomId, String kenh) async =>
      KenhKhaiThac.fromMap(
        await _c.post('/api/host/rooms/$roomId/kenh/$kenh/rao-lai'),
      );
}

class KenhKhaiThac {
  const KenhKhaiThac({
    required this.kenh,
    required this.gia,
    required this.donVi,
    required this.dangBat,
    required this.trangThai,
    required this.daChot,
    this.toiThieu,
    this.datCoc,
    this.mienPhiThang,
    this.soTinDaDong = 0,
  });

  /// 'ngan_han' | 'dai_han' | 'mat_bang' | 'ban'
  final String kenh;
  final double gia;

  /// 'dem' | 'thang' | 'm2_thang' | 'tong'
  final String donVi;
  final int? toiThieu;
  final double? datCoc;

  /// Chỉ mặt bằng: số tháng miễn tiền thuê để bên thuê sửa chữa.
  final int? mienPhiThang;
  final bool dangBat;

  /// 'dang_rao' | 'giu_cho' | 'da_coc' | 'da_ban' | 'da_cho_thue'
  final String trangThai;

  /// Kênh đã chốt → không nhận khách mới, chỉ còn nút "Rao lại".
  final bool daChot;

  /// Số tin bị đóng theo khi vừa chốt. Người bấm cần biết ngay: họ vừa gỡ tin
  /// của người khác khỏi chợ.
  final int soTinDaDong;

  static const nhanKenh = {
    'ngan_han': 'Ở ngắn hạn',
    'dai_han': 'Thuê dài hạn',
    // KHÔNG gọi là "thuê dài hạn": mặt bằng thương lượng theo m²/tháng, kỳ hạn
    // năm, có kỳ miễn phí sửa chữa — một nghiệp vụ khác hẳn.
    'mat_bang': 'Mặt bằng kinh doanh',
    'ban': 'Mua bán',
  };

  static const hauToDonVi = {
    'dem': '/đêm',
    'thang': '/tháng',
    'm2_thang': '/m²/tháng',
    // "3 tỷ/tổng" là câu vô nghĩa.
    'tong': '',
  };

  static const nhanTrangThai = {
    'dang_rao': 'Đang rao',
    'giu_cho': 'Giữ chỗ',
    'da_coc': 'Đã cọc',
    'da_ban': 'Đã bán',
    'da_cho_thue': 'Đã cho thuê',
  };

  /// Các bước tiếp theo hợp lệ của từng kênh. Kênh thuê chốt bằng HỢP ĐỒNG,
  /// không bấm tay ở đây — nên danh sách của nó rỗng.
  static const buocTiepTheo = {
    'ban': ['giu_cho', 'da_coc', 'da_ban'],
    'ngan_han': <String>[],
    'dai_han': <String>[],
    'mat_bang': <String>[],
  };

  String get ten => nhanKenh[kenh] ?? kenh;
  String get hauTo => hauToDonVi[donVi] ?? '';
  String get tenTrangThai => nhanTrangThai[trangThai] ?? trangThai;
  bool get laBan => kenh == 'ban';
  bool get laMatBang => kenh == 'mat_bang';

  factory KenhKhaiThac.fromMap(Map<String, dynamic> m) => KenhKhaiThac(
    kenh: m['kenh'] as String? ?? '',
    gia: (m['gia'] as num?)?.toDouble() ?? 0,
    donVi: m['don_vi'] as String? ?? '',
    toiThieu: (m['toi_thieu'] as num?)?.toInt(),
    datCoc: (m['dat_coc'] as num?)?.toDouble(),
    mienPhiThang: (m['mien_phi_thang'] as num?)?.toInt(),
    dangBat: m['dang_bat'] as bool? ?? true,
    trangThai: m['trang_thai'] as String? ?? 'dang_rao',
    daChot: m['da_chot'] as bool? ?? false,
    soTinDaDong: (m['so_tin_da_dong'] as num?)?.toInt() ?? 0,
  );
}
