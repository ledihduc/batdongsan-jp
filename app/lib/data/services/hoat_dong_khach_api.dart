import 'package:house_booking/data/services/api_client.dart';

/// Tab "Hoạt động" của khách hàng: ba con số "Cần chú ý" + sổ hợp đồng và
/// hoá đơn của chính người đăng nhập. API: GET /api/guest/hoat-dong.
class HoatDongKhachApi {
  const HoatDongKhachApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<HoatDongKhach> lay() async =>
      HoatDongKhach.fromMap(await _c.get('/api/guest/hoat-dong'));
}

int _int(Object? v) => (v as num?)?.toInt() ?? 0;
double _so(Object? v) => (v as num?)?.toDouble() ?? 0;

class HoatDongKhach {
  const HoatDongKhach({
    this.lichXemSapToi = 0,
    this.hoaDonCanTra = 0,
    this.tienCanTra = 0,
    this.hopDongSapHet = 0,
    this.hopDong = const [],
    this.hoaDon = const [],
  });

  factory HoatDongKhach.fromMap(Map<String, dynamic> m) => HoatDongKhach(
    lichXemSapToi: _int(m['lich_xem_sap_toi']),
    hoaDonCanTra: _int(m['hoa_don_can_tra']),
    tienCanTra: _so(m['tien_can_tra']),
    hopDongSapHet: _int(m['hop_dong_sap_het']),
    hopDong: [
      for (final x in (m['hop_dong'] as List? ?? const []))
        if (x is Map) HopDongKhach.fromMap(Map<String, dynamic>.from(x)),
    ],
    hoaDon: [
      for (final x in (m['hoa_don'] as List? ?? const []))
        if (x is Map) HoaDonKhach.fromMap(Map<String, dynamic>.from(x)),
    ],
  );

  final int lichXemSapToi;
  final int hoaDonCanTra;
  final double tienCanTra;
  final int hopDongSapHet;
  final List<HopDongKhach> hopDong;
  final List<HoaDonKhach> hoaDon;
}

class HopDongKhach {
  const HopDongKhach({
    required this.contractId,
    this.maPhong = '',
    this.tenToa = '',
    this.diaChi = '',
    this.tienThue = 0,
    this.tuNgay = '',
    this.denNgay = '',
    this.conNgay,
    this.sapHet = false,
    this.anhHopDong = const [],
    this.anhCoc = const [],
  });

  factory HopDongKhach.fromMap(Map<String, dynamic> m) => HopDongKhach(
    contractId: _int(m['contract_id']),
    maPhong: m['ma_phong'] as String? ?? '',
    tenToa: m['ten_toa'] as String? ?? '',
    diaChi: m['dia_chi'] as String? ?? '',
    tienThue: _so(m['tien_thue']),
    tuNgay: m['tu_ngay'] as String? ?? '',
    denNgay: m['den_ngay'] as String? ?? '',
    conNgay: (m['con_ngay'] as num?)?.toInt(),
    sapHet: m['sap_het'] as bool? ?? false,
    anhHopDong: List<String>.from(m['anh_hop_dong'] as List? ?? const []),
    anhCoc: List<String>.from(m['anh_coc'] as List? ?? const []),
  );

  final int contractId;
  final String maPhong;
  final String tenToa;
  final String diaChi;
  final double tienThue;
  final String tuNgay;
  final String denNgay;

  /// Số ngày tới hạn hợp đồng; `null` = hợp đồng không ghi ngày hết.
  final int? conNgay;
  final bool sapHet;
  final List<String> anhHopDong;
  final List<String> anhCoc;
}

class HoaDonKhach {
  const HoaDonKhach({
    required this.id,
    required this.contractId,
    this.so = '',
    this.maPhong = '',
    this.tenToa = '',
    this.kyTu = '',
    this.kyDen = '',
    this.han = '',
    this.tong = 0,
    this.daTra = 0,
    this.conNo = 0,
    this.trangThai = 'sent',
    this.traLuc,
  });

  factory HoaDonKhach.fromMap(Map<String, dynamic> m) => HoaDonKhach(
    id: _int(m['id']),
    contractId: _int(m['contract_id']),
    so: m['so'] as String? ?? '',
    maPhong: m['ma_phong'] as String? ?? '',
    tenToa: m['ten_toa'] as String? ?? '',
    kyTu: m['ky_tu'] as String? ?? '',
    kyDen: m['ky_den'] as String? ?? '',
    han: m['han'] as String? ?? '',
    tong: _so(m['tong']),
    daTra: _so(m['da_tra']),
    conNo: _so(m['con_no']),
    trangThai: m['trang_thai'] as String? ?? 'sent',
    traLuc: DateTime.tryParse(m['tra_luc'] as String? ?? ''),
  );

  final int id;
  final int contractId;
  final String so;
  final String maPhong;
  final String tenToa;
  final String kyTu;
  final String kyDen;
  final String han;
  final double tong;
  final double daTra;
  final double conNo;

  /// sent · overdue · paid — bản nháp của chủ nhà không bao giờ tới đây.
  final String trangThai;
  final DateTime? traLuc;

  bool get daTraXong => trangThai == 'paid';
  bool get quaHan => trangThai == 'overdue';
}
