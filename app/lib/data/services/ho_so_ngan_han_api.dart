import 'package:house_booking/data/services/api_client.dart';

/// Hồ sơ & quản trị phòng NGẮN HẠN — một lượt gọi cho cả màn.
///
///     GET  /api/host/rooms/{id}/ho-so-ngan-han?ngay=YYYY-MM-DD
///     POST /api/host/rooms/{id}/ca-thue          mở ca cho khách vãng lai
///
/// Check-in · check-out · khoá phòng vẫn đi bằng [ShortStayApi]: một việc một
/// đường, không đẻ đường ghi thứ hai.
class HoSoNganHanApi {
  const HoSoNganHanApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<HoSoNganHan> lay(int roomId, {String? ngay}) async =>
      HoSoNganHan.fromMap(
        await _c.get(
          '/api/host/rooms/$roomId/ho-so-ngan-han',
          queryParameters: {if (ngay != null) 'ngay': ngay},
        ),
      );

  /// `kieu`: 'theo_gio' | 'qua_dem' | 'theo_ngay'. `soLuong` = số giờ hoặc số
  /// ngày; qua đêm luôn là một ca 21:00 → 09:00.
  Future<CaMoi> themCa(
    int roomId, {
    required String ten,
    String sdt = '',
    String kieu = 'theo_gio',
    String? batDau,
    int soLuong = 1,
    String? ghiChu,
  }) async => CaMoi.fromMap(
    await _c.post(
      '/api/host/rooms/$roomId/ca-thue',
      body: {
        'ten': ten,
        'sdt': sdt,
        'kieu': kieu,
        'bat_dau': ?batDau,
        'so_luong': soLuong,
        'ghi_chu': ?ghiChu,
      },
    ),
  );
}

double? _d(dynamic v) => (v as num?)?.toDouble();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

String? _s(dynamic v) {
  final s = (v as String?)?.trim();
  return s == null || s.isEmpty ? null : s;
}

/// Một mục trên lịch trong ngày: ca thuê, hoặc khoảng khoá tay (dọn/sửa).
class MucLich {
  const MucLich({
    required this.loai,
    required this.id,
    this.tu,
    this.den,
    this.kieu = '',
    this.nhanKieu = '',
    this.trangThai = '',
    this.nguon = '',
    this.ten,
    this.sdt,
    this.maDat,
    this.tong,
    this.coc,
    this.ghiChu,
  });

  factory MucLich.fromMap(Map<String, dynamic> m) => MucLich(
    loai: m['loai'] as String? ?? 'dat',
    id: _i(m['id']),
    tu: _s(m['tu']),
    den: _s(m['den']),
    kieu: m['kieu'] as String? ?? '',
    nhanKieu: m['nhan_kieu'] as String? ?? '',
    trangThai: m['trang_thai'] as String? ?? '',
    nguon: m['nguon'] as String? ?? '',
    ten: _s(m['ten']),
    sdt: _s(m['sdt']),
    maDat: _s(m['ma_dat']),
    tong: _d(m['tong']),
    coc: _d(m['coc']),
    ghiChu: _s(m['ghi_chu']),
  );

  /// 'dat' = ca thuê · 'chan' = khoảng khoá tay.
  final String loai;
  final int id;

  /// ISO tới phút.
  final String? tu;
  final String? den;
  final String kieu;
  final String nhanKieu;

  /// 'pending' | 'approved' | 'checked_in'.
  final String trangThai;
  final String nguon;

  /// Chỉ có khi người xem được phép thấy người và tiền.
  final String? ten;
  final String? sdt;
  final String? maDat;
  final double? tong;
  final double? coc;
  final String? ghiChu;

  bool get laChan => loai == 'chan';
}

/// Khách đang trong phòng + tiến độ ca.
class KhachDangO {
  const KhachDangO({
    required this.reservationId,
    this.trangThai = '',
    this.kieu = '',
    this.nhanKieu = '',
    this.vao,
    this.ra,
    this.soDem = 1,
    this.nguon = '',
    this.ten,
    this.sdt,
    this.maDat,
    this.tong,
    this.coc,
    this.conThu,
    this.ghiChu,
    this.tongPhut = 0,
    this.daOPhut = 0,
    this.conPhut = 0,
    this.phanTram = 0,
    this.quaGio = false,
  });

  factory KhachDangO.fromMap(Map<String, dynamic> m) {
    final td = (m['tien_do'] as Map?)?.cast<String, dynamic>() ?? const {};
    return KhachDangO(
      reservationId: _i(m['reservation_id']),
      trangThai: m['trang_thai'] as String? ?? '',
      kieu: m['kieu'] as String? ?? '',
      nhanKieu: m['nhan_kieu'] as String? ?? '',
      vao: _s(m['vao']),
      ra: _s(m['ra']),
      soDem: _i(m['so_dem']),
      nguon: m['nguon'] as String? ?? '',
      ten: _s(m['ten']),
      sdt: _s(m['sdt']),
      maDat: _s(m['ma_dat']),
      tong: _d(m['tong']),
      coc: _d(m['coc']),
      conThu: _d(m['con_thu']),
      ghiChu: _s(m['ghi_chu']),
      tongPhut: _i(td['tong_phut']),
      daOPhut: _i(td['da_o_phut']),
      conPhut: _i(td['con_phut']),
      phanTram: _d(td['phan_tram']) ?? 0,
      quaGio: td['qua_gio'] == true,
    );
  }

  final int reservationId;

  /// 'approved' = đã duyệt, chưa nhận phòng · 'checked_in' = đang trong phòng.
  final String trangThai;
  final String kieu;
  final String nhanKieu;
  final String? vao;
  final String? ra;
  final int soDem;
  final String nguon;
  final String? ten;
  final String? sdt;
  final String? maDat;
  final double? tong;
  final double? coc;

  /// Số phải thu khi trả phòng = tổng − cọc đã nhận.
  final double? conThu;
  final String? ghiChu;
  final int tongPhut;
  final int daOPhut;
  final int conPhut;
  final double phanTram;

  /// Đã quá giờ trả phòng — việc chủ nhà phải xử lý ngay.
  final bool quaGio;

  bool get daNhanPhong => trangThai == 'checked_in';
}

class HoSoNganHan {
  const HoSoNganHan({
    required this.ngay,
    required this.roomId,
    this.bayGio,
    this.xemTaiChinh = false,
    this.maPhong = '',
    this.trangThaiPhong = '',
    this.dienTich,
    this.tang,
    this.sucChua = 1,
    this.loaiPhong,
    this.hangId,
    this.hangGiuong,
    this.hangSucChua = 0,
    this.hangDangBan = true,
    this.hangSoPhong = 0,
    this.hangCoKhach = 0,
    this.hangBaoTri = 0,
    this.hangTrong = 0,
    this.doTrongPhong = const [],
    this.anh = const [],
    this.buildingId = 0,
    this.tenToa = '',
    this.diaChi = '',
    this.giaGio,
    this.giaQuaDem,
    this.giaNgay,
    this.giaNiemYet = 0,
    this.kenhBat = false,
    this.giaDien = 0,
    this.giaNuoc = 0,
    this.khach,
    this.lich = const [],
    this.soCa = 0,
    this.soChan = 0,
    this.doanhThuNgay = 0,
  });

  factory HoSoNganHan.fromMap(Map<String, dynamic> m) {
    final r = (m['room'] as Map?)?.cast<String, dynamic>() ?? const {};
    final t = (m['toa'] as Map?)?.cast<String, dynamic>() ?? const {};
    final g = (m['gia'] as Map?)?.cast<String, dynamic>() ?? const {};
    final tk = (m['thong_ke_ngay'] as Map?)?.cast<String, dynamic>() ?? const {};
    final k = (m['khach'] as Map?)?.cast<String, dynamic>();
    return HoSoNganHan(
      ngay: m['ngay'] as String? ?? '',
      bayGio: _s(m['bay_gio']),
      xemTaiChinh: m['xem_tai_chinh'] == true,
      roomId: _i(r['id']),
      maPhong: r['ma'] as String? ?? '',
      trangThaiPhong: r['trang_thai'] as String? ?? '',
      dienTich: _d(r['dien_tich']),
      tang: _s(r['tang']),
      sucChua: _i(r['suc_chua']),
      loaiPhong: _s(r['loai_phong']),
      hangId: (m['loai'] as Map?) == null ? null : _i((m['loai'] as Map)['id']),
      hangGiuong: (m['loai'] as Map?) == null ? null : _s((m['loai'] as Map)['giuong']),
      hangSucChua: (m['loai'] as Map?) == null ? 0 : _i((m['loai'] as Map)['suc_chua']),
      hangDangBan: (m['loai'] as Map?) == null || (m['loai'] as Map)['dang_ban'] != false,
      hangSoPhong: (m['loai'] as Map?) == null ? 0 : _i((m['loai'] as Map)['so_phong']),
      hangCoKhach: (m['loai'] as Map?) == null ? 0 : _i((m['loai'] as Map)['dang_co_khach']),
      hangBaoTri: (m['loai'] as Map?) == null ? 0 : _i((m['loai'] as Map)['bao_tri']),
      hangTrong: (m['loai'] as Map?) == null ? 0 : _i((m['loai'] as Map)['trong']),
      doTrongPhong: [for (final x in (r['do_trong_phong'] as List? ?? const [])) '$x'],
      anh: [for (final x in (r['anh'] as List? ?? const [])) '$x'],
      buildingId: _i(t['id']),
      tenToa: t['ten'] as String? ?? '',
      diaChi: t['dia_chi'] as String? ?? '',
      giaGio: _d(g['gio']),
      giaQuaDem: _d(g['qua_dem']),
      giaNgay: _d(g['ngay']),
      giaNiemYet: _d(g['niem_yet']) ?? 0,
      kenhBat: g['dang_bat'] == true,
      giaDien: _d(g['gia_dien']) ?? 0,
      giaNuoc: _d(g['gia_nuoc']) ?? 0,
      khach: k == null ? null : KhachDangO.fromMap(k),
      lich: [
        for (final x in (m['lich'] as List? ?? const []))
          MucLich.fromMap((x as Map).cast<String, dynamic>()),
      ],
      soCa: _i(tk['so_ca']),
      soChan: _i(tk['so_chan']),
      doanhThuNgay: _d(tk['doanh_thu']) ?? 0,
    );
  }

  /// 'YYYY-MM-DD' — ngày đang xem trên lịch.
  final String ngay;
  final String? bayGio;
  final bool xemTaiChinh;
  final int roomId;
  final String maPhong;
  final String trangThaiPhong;
  final double? dienTich;
  final String? tang;
  final int sucChua;
  final String? loaiPhong;

  /// HẠNG phòng (mig 0111) — `null` = phòng chưa xếp hạng, khách không đặt
  /// được theo hạng. Kèm tồn kho của cả hạng: người trực ở quầy hỏi "hạng này
  /// còn phòng không", không hỏi về đúng căn đang mở.
  final int? hangId;
  final String? hangGiuong;
  final int hangSucChua;
  final bool hangDangBan;
  final int hangSoPhong;
  final int hangCoKhach;
  final int hangBaoTri;
  final int hangTrong;

  final List<String> doTrongPhong;
  final List<String> anh;
  final int buildingId;
  final String tenToa;
  final String diaChi;

  /// `null` = chưa khai giá cho hình thức đó (không phải 0đ).
  final double? giaGio;
  final double? giaQuaDem;
  final double? giaNgay;
  final double giaNiemYet;
  final bool kenhBat;
  final double giaDien;
  final double giaNuoc;
  final KhachDangO? khach;
  final List<MucLich> lich;
  final int soCa;
  final int soChan;
  final double doanhThuNgay;

  bool get coKhach => khach != null;
}

class CaMoi {
  const CaMoi({
    required this.reservationId,
    this.maDat = '',
    this.trangThai = '',
    this.vao,
    this.ra,
    this.tong = 0,
  });

  factory CaMoi.fromMap(Map<String, dynamic> m) => CaMoi(
    reservationId: _i(m['reservation_id']),
    maDat: m['ma_dat'] as String? ?? '',
    trangThai: m['trang_thai'] as String? ?? '',
    vao: _s(m['vao']),
    ra: _s(m['ra']),
    tong: _d(m['tong']) ?? 0,
  );

  final int reservationId;
  final String maDat;
  final String trangThai;
  final String? vao;
  final String? ra;
  final double tong;
}
