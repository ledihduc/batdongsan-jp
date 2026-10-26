import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';

/// BỘ MÀN "GÓC NHÌN CHỦ NHÀ" (mockup 04/10/2026).
///
///     GET  /api/host/chu-nha/tong-quan
///     GET  /api/host/chu-nha/yeu-cau
///     GET  /api/host/chu-nha/phong?building_id=
///     GET  /api/host/chu-nha/phong/{room_id}/lich-xem
///     POST /api/host/chu-nha/lich-xem/{id}/ket-qua
///     POST /api/host/chu-nha/lich-xem/{id}/hop-dong
///
/// Duyệt / từ chối lịch: `PATCH /api/viewing-appointments/{id}/status`.
/// Đề nghị chốt trên tin: `POST /api/deals/{id}/confirm|reject`.
class ChuNhaApi {
  const ChuNhaApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<TongQuanChuNha> tongQuan() async =>
      TongQuanChuNha.fromMap(await _c.get('/api/host/chu-nha/tong-quan'));

  Future<YeuCauChuNha> yeuCau() async =>
      YeuCauChuNha.fromMap(await _c.get('/api/host/chu-nha/yeu-cau'));

  Future<PhongCuaToa> phong({int? buildingId}) async => PhongCuaToa.fromMap(
    await _c.get(
      '/api/host/chu-nha/phong',
      queryParameters: {if (buildingId != null) 'building_id': '$buildingId'},
    ),
  );

  Future<({List<LichChuNha> sapToi, List<LichChuNha> daQua})> lichXemPhong(
    int roomId,
  ) async {
    final m = await _c.get('/api/host/chu-nha/phong/$roomId/lich-xem');
    return (sapToi: _ds(m['sap_toi']), daQua: _ds(m['da_qua']));
  }

  Future<void> duyetLich(int id) => _c.patch(
    '/api/viewing-appointments/$id/status',
    body: {'status': 'approved'},
  );

  Future<void> tuChoiLich(int id, {String lyDo = ''}) => _c.patch(
    '/api/viewing-appointments/$id/status',
    body: {'status': 'rejected', 'ly_do': lyDo},
  );

  /// Chủ nhà không đồng ý cho thuê dù khách muốn — khép lịch ('lost').
  Future<void> tuChoiChot(int id, {String lyDo = ''}) => _c.patch(
    '/api/viewing-appointments/$id/status',
    body: {'status': 'lost', 'ly_do': lyDo},
  );

  Future<void> ghiKetQua(
    int id, {
    required bool muonThue,
    String ghiChu = '',
  }) => _c.post(
    '/api/host/chu-nha/lich-xem/$id/ket-qua',
    body: {'muon_thue': muonThue, 'ghi_chu': ghiChu},
  );

  /// Hợp đồng NHÁP từ lịch xem, rồi chuyển lịch sang "chốt" để khách nhận
  /// đề nghị thuê ở trang Hoạt động của họ.
  Future<int> taoHopDong(
    int appointmentId, {
    required double giaThue,
    required int soThang,
    required DateTime ngayBatDau,
    required double tienCoc,
    required int ngayThanhToan,
    String? hinhThuc,
  }) async {
    final m = await _c.post(
      '/api/host/chu-nha/lich-xem/$appointmentId/hop-dong',
      body: {
        'gia_thue': giaThue,
        'so_thang': soThang,
        'ngay_bat_dau':
            '${ngayBatDau.year}-${_hai(ngayBatDau.month)}-${_hai(ngayBatDau.day)}',
        'tien_coc': tienCoc,
        'ngay_thanh_toan': ngayThanhToan,
        'hinh_thuc_thanh_toan': ?hinhThuc,
      },
    );
    await _c.patch(
      '/api/viewing-appointments/$appointmentId/status',
      body: {'status': 'locked'},
    );
    return (m['contract_id'] as num).toInt();
  }

  Future<void> xacNhanGiaoDich(int dealId) =>
      _c.post('/api/deals/$dealId/confirm', body: const {});

  Future<void> tuChoiGiaoDich(int dealId, {String lyDo = ''}) =>
      _c.post('/api/deals/$dealId/reject', body: {'reason': lyDo});
}

String _hai(int n) => n.toString().padLeft(2, '0');

List<LichChuNha> _ds(dynamic v) => [
  for (final x in (v as List? ?? const []))
    LichChuNha.fromMap(Map<String, dynamic>.from(x as Map)),
];

double? _d(dynamic v) => (v as num?)?.toDouble();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

/// Một lịch xem / yêu cầu chốt nhìn từ chủ nhà. Khách KHÔNG có trong payload —
/// màn in "[ẩn thông tin]".
class LichChuNha {
  const LichChuNha({
    required this.id,
    required this.kieu,
    this.loai = 'xem',
    this.trangThai = '',
    this.ngay = '',
    this.gio = '',
    this.quaGio = false,
    this.roomId,
    this.tenPhong = '',
    this.anh,
    this.sale,
    this.ghiChu = '',
    this.ketQua,
    this.ghiChuKetQua = '',
    this.giaThue,
  });

  factory LichChuNha.fromMap(Map<String, dynamic> m) {
    final p = Map<String, dynamic>.from(m['phong'] as Map? ?? const {});
    return LichChuNha(
      id: _i(m['id']),
      kieu: m['kieu'] as String? ?? 'lich_xem',
      loai: m['loai'] as String? ?? 'xem',
      trangThai: m['trang_thai'] as String? ?? '',
      ngay: m['ngay'] as String? ?? '',
      gio: m['gio'] as String? ?? '',
      quaGio: m['qua_gio'] == true,
      roomId: (p['id'] as num?)?.toInt(),
      tenPhong: p['ten'] as String? ?? '',
      anh: p['anh'] as String?,
      sale: m['sale'] is Map
          ? SalePhuTrach.fromMap(Map<String, dynamic>.from(m['sale'] as Map))
          : null,
      ghiChu: m['ghi_chu'] as String? ?? '',
      ketQua: m['ket_qua'] as String?,
      ghiChuKetQua: m['ghi_chu_ket_qua'] as String? ?? '',
      giaThue: _d(m['gia_thue']),
    );
  }

  final int id;

  /// lich_xem · chot · ghi_ket_qua · giao_dich (đề nghị chốt trên tin — [id]
  /// là id giao dịch, không phải id lịch).
  final String kieu;
  final String loai;
  final String trangThai;
  final String ngay;
  final String gio;
  final bool quaGio;
  final int? roomId;
  final String tenPhong;
  final String? anh;
  final SalePhuTrach? sale;
  final String ghiChu;

  /// 'chot' · 'khong_chot' · null.
  final String? ketQua;
  final String ghiChuKetQua;
  final double? giaThue;

  bool get laGiaoDich => kieu == 'giao_dich';

  DateTime? get luc {
    final d = DateTime.tryParse(ngay);
    if (d == null) return null;
    final p = gio.split('-').first.split(':');
    return DateTime(
      d.year,
      d.month,
      d.day,
      int.tryParse(p.first) ?? 0,
      p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0,
    );
  }
}

class TongQuanChuNha {
  const TongQuanChuNha({
    this.ten = '',
    this.soToa = 0,
    this.dangThue = 0,
    this.phongTrong = 0,
    this.coLichXem = 0,
    this.sapTra = 0,
    this.doanhThuThang = 0,
    this.doanhThuTang,
    this.thang = 1,
    this.canXacNhan = const [],
    this.soViecKhac = 0,
  });

  factory TongQuanChuNha.fromMap(Map<String, dynamic> m) => TongQuanChuNha(
    ten: m['ten'] as String? ?? '',
    soToa: _i(m['so_toa']),
    dangThue: _i(m['dang_thue']),
    phongTrong: _i(m['phong_trong']),
    coLichXem: _i(m['co_lich_xem']),
    sapTra: _i(m['sap_tra']),
    doanhThuThang: _d(m['doanh_thu_thang']) ?? 0,
    doanhThuTang: _d(m['doanh_thu_tang']),
    thang: _i(m['thang']) == 0 ? DateTime.now().month : _i(m['thang']),
    canXacNhan: _ds(m['can_xac_nhan']),
    soViecKhac: _i(m['so_viec_khac']),
  );

  final String ten;
  final int soToa;
  final int dangThue;
  final int phongTrong;
  final int coLichXem;
  final int sapTra;
  final double doanhThuThang;

  /// % so với tháng trước; null = tháng trước không có doanh thu để so.
  final double? doanhThuTang;
  final int thang;
  final List<LichChuNha> canXacNhan;
  final int soViecKhac;
}

class YeuCauChuNha {
  const YeuCauChuNha({
    this.lichXem = const [],
    this.chot = const [],
    this.khac = const [],
    this.giaoDich = const [],
  });

  factory YeuCauChuNha.fromMap(Map<String, dynamic> m) => YeuCauChuNha(
    lichXem: _ds(m['lich_xem']),
    chot: _ds(m['chot']),
    khac: _ds(m['khac']),
    giaoDich: _ds(m['giao_dich']),
  );

  final List<LichChuNha> lichXem;

  /// Khách muốn thuê sau buổi xem, chưa có hợp đồng.
  final List<LichChuNha> chot;

  /// Buổi xem đã qua, chưa ghi kết quả.
  final List<LichChuNha> khac;

  /// Đề nghị chốt khách bấm thẳng trên tin.
  final List<LichChuNha> giaoDich;
}

class PhongChuNha {
  const PhongChuNha({
    required this.id,
    required this.code,
    this.tang = 'Khác',
    this.dienTich,
    this.gia,
    this.donVi = 'tháng',
    this.anh,
    this.trangThai = 'trong',
  });

  factory PhongChuNha.fromMap(Map<String, dynamic> m) => PhongChuNha(
    id: _i(m['id']),
    code: m['code'] as String? ?? '',
    tang: m['tang'] as String? ?? 'Khác',
    dienTich: _d(m['dien_tich']),
    gia: _d(m['gia']),
    donVi: m['don_vi'] as String? ?? 'tháng',
    anh: m['anh'] as String?,
    trangThai: m['trang_thai'] as String? ?? 'trong',
  );

  final int id;
  final String code;
  final String tang;
  final double? dienTich;
  final double? gia;
  final String donVi;
  final String? anh;

  /// dang_thue · trong · co_lich_xem · sap_tra · bao_tri
  final String trangThai;

  /// "Phòng 101" — mã "P101" bỏ chữ P đầu.
  String get ten => 'Phòng ${code.replaceFirst(RegExp(r'^[Pp](?=\d)'), '')}';
}

class PhongCuaToa {
  const PhongCuaToa({
    this.toa = const [],
    this.toaChon,
    this.phong = const [],
    this.dem = const {},
  });

  factory PhongCuaToa.fromMap(Map<String, dynamic> m) => PhongCuaToa(
    toa: [
      for (final x in (m['toa'] as List? ?? const []))
        (
          id: _i((x as Map)['id']),
          ten: x['ten'] as String? ?? '',
          diaChi: x['dia_chi'] as String? ?? '',
        ),
    ],
    toaChon: (m['toa_chon'] as num?)?.toInt(),
    phong: [
      for (final x in (m['phong'] as List? ?? const []))
        PhongChuNha.fromMap(Map<String, dynamic>.from(x as Map)),
    ],
    dem: {
      for (final e in (m['dem'] as Map? ?? const {}).entries)
        '${e.key}': (e.value as num).toInt(),
    },
  );

  final List<({int id, String ten, String diaChi})> toa;
  final int? toaChon;
  final List<PhongChuNha> phong;
  final Map<String, int> dem;
}
