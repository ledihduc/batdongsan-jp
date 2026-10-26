import 'package:house_booking/data/services/api_client.dart';

/// LỊCH PHÒNG NGẮN HẠN của cả toà trong một ngày (ma trận phòng × giờ).
///
///     GET /api/host/buildings/{id}/lich-ngan-han?ngay=YYYY-MM-DD
///
/// Nhận/trả phòng và bỏ khoá vẫn đi bằng [ShortStayApi] — một việc một đường.
class LichNganHanApi {
  const LichNganHanApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<LichNgay> ngay(int buildingId, {String? ngay}) async =>
      LichNgay.fromMap(
        await _c.get(
          '/api/host/buildings/$buildingId/lich-ngan-han',
          queryParameters: {if (ngay != null) 'ngay': ngay},
        ),
      );
}

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

String? _s(dynamic v) {
  final s = (v as String?)?.trim();
  return s == null || s.isEmpty ? null : s;
}

/// Một khối trên lưới: ca thuê hoặc khoảng khoá tay, ĐÃ cắt trong ngày đang xem.
class KhoiLich {
  const KhoiLich({
    required this.loai,
    required this.id,
    required this.tu,
    required this.den,
    this.tranTruoc = false,
    this.tranSau = false,
    this.trangThai = '',
    this.nhanKieu = '',
    this.nguon = '',
    this.ten,
    this.maDat,
    this.tong,
    this.ghiChu,
  });

  factory KhoiLich.fromMap(Map<String, dynamic> m) => KhoiLich(
    loai: m['loai'] as String? ?? 'dat',
    id: _i(m['id']),
    tu: DateTime.tryParse('${m['tu']}') ?? DateTime.now(),
    den: DateTime.tryParse('${m['den']}') ?? DateTime.now(),
    tranTruoc: m['tran_truoc'] == true,
    tranSau: m['tran_sau'] == true,
    trangThai: m['trang_thai'] as String? ?? '',
    nhanKieu: m['nhan_kieu'] as String? ?? '',
    nguon: m['nguon'] as String? ?? '',
    ten: _s(m['ten']),
    maDat: _s(m['ma_dat']),
    tong: (m['tong'] as num?)?.toDouble(),
    ghiChu: _s(m['ghi_chu']),
  );

  /// 'dat' = ca thuê · 'chan' = khoá tay (dọn phòng, sửa chữa).
  final String loai;
  final int id;
  final DateTime tu;
  final DateTime den;

  /// Ca bắt đầu từ hôm trước / kéo sang hôm sau — vẽ mũi nhọn ở mép lưới.
  final bool tranTruoc;
  final bool tranSau;
  final String trangThai;
  final String nhanKieu;
  final String nguon;
  final String? ten;
  final String? maDat;
  final double? tong;
  final String? ghiChu;

  bool get laChan => loai == 'chan';
}

class HangPhongLich {
  const HangPhongLich({
    required this.id,
    required this.ma,
    this.sucChua = 2,
    this.trangThai = 'vacant',
    this.hang,
    this.muc = const [],
  });

  factory HangPhongLich.fromMap(Map<String, dynamic> m) => HangPhongLich(
    id: _i(m['id']),
    ma: m['ma'] as String? ?? '',
    sucChua: _i(m['suc_chua']),
    trangThai: m['trang_thai'] as String? ?? 'vacant',
    hang: _s(m['hang']),
    muc: [
      for (final x in (m['muc'] as List? ?? const []))
        KhoiLich.fromMap((x as Map).cast<String, dynamic>()),
    ],
  );

  final int id;
  final String ma;
  final int sucChua;
  final String trangThai;

  /// Hạng phòng (nếu đã xếp) — khách đặt theo hạng.
  final String? hang;
  final List<KhoiLich> muc;
}

/// Việc phải làm trong ngày: nhận phòng · trả phòng · dọn xong.
class ViecTrongNgay {
  const ViecTrongNgay({
    required this.loai,
    required this.luc,
    required this.roomId,
    this.maPhong = '',
    this.reservationId,
    this.blockId,
    this.nhanKieu = '',
    this.ten,
    this.ghiChu,
    this.quaGio = false,
    this.sale,
  });

  factory ViecTrongNgay.fromMap(Map<String, dynamic> m) => ViecTrongNgay(
    loai: m['loai'] as String? ?? '',
    luc: DateTime.tryParse('${m['luc']}') ?? DateTime.now(),
    roomId: _i(m['room_id']),
    maPhong: m['ma_phong'] as String? ?? '',
    reservationId: (m['reservation_id'] as num?)?.toInt(),
    blockId: (m['block_id'] as num?)?.toInt(),
    nhanKieu: m['nhan_kieu'] as String? ?? '',
    ten: _s(m['ten']),
    ghiChu: _s(m['ghi_chu']),
    quaGio: m['qua_gio'] == true,
    sale: _s(m['sale']),
  );

  /// 'cho_duyet' | 'nhan_phong' | 'tra_phong' | 'don_xong'.
  final String loai;
  final DateTime luc;
  final int roomId;
  final String maPhong;
  final int? reservationId;
  final int? blockId;
  final String nhanKieu;
  final String? ten;
  final String? ghiChu;

  /// Đã quá giờ trả mà khách chưa check-out.
  final bool quaGio;

  /// Sale dẫn khách về — chỉ có ở đơn chờ duyệt.
  final String? sale;

  bool get laChoDuyet => loai == 'cho_duyet';
}

class LichNgay {
  const LichNgay({
    required this.ngay,
    this.bayGio,
    this.xemTaiChinh = false,
    this.buildingId = 0,
    this.tenToa = '',
    this.diaChi = '',
    this.luotDat = 0,
    this.dangO = 0,
    this.soPhong = 0,
    this.congSuat = 0,
    this.sapTra = 0,
    this.sapTraGio = 3,
    this.doanhThu = 0,
    this.phong = const [],
    this.viec = const [],
  });

  factory LichNgay.fromMap(Map<String, dynamic> m) {
    final t = (m['toa'] as Map?)?.cast<String, dynamic>() ?? const {};
    final k = (m['kpi'] as Map?)?.cast<String, dynamic>() ?? const {};
    return LichNgay(
      ngay: m['ngay'] as String? ?? '',
      bayGio: DateTime.tryParse('${m['bay_gio']}'),
      xemTaiChinh: m['xem_tai_chinh'] == true,
      buildingId: _i(t['id']),
      tenToa: t['ten'] as String? ?? '',
      diaChi: t['dia_chi'] as String? ?? '',
      luotDat: _i(k['luot_dat']),
      dangO: _i(k['dang_o']),
      soPhong: _i(k['so_phong']),
      congSuat: _d(k['cong_suat']),
      sapTra: _i(k['sap_tra']),
      sapTraGio: _i(k['sap_tra_gio']),
      doanhThu: _d(k['doanh_thu']),
      phong: [
        for (final x in (m['phong'] as List? ?? const []))
          HangPhongLich.fromMap((x as Map).cast<String, dynamic>()),
      ],
      viec: [
        for (final x in (m['su_kien'] as List? ?? const []))
          ViecTrongNgay.fromMap((x as Map).cast<String, dynamic>()),
      ],
    );
  }

  final String ngay;
  final DateTime? bayGio;
  final bool xemTaiChinh;
  final int buildingId;
  final String tenToa;
  final String diaChi;
  final int luotDat;
  final int dangO;
  final int soPhong;
  final double congSuat;
  final int sapTra;
  final int sapTraGio;
  final double doanhThu;
  final List<HangPhongLich> phong;
  final List<ViecTrongNgay> viec;
}
