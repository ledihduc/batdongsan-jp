import 'package:house_booking/data/models/su_kien_lich_su.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/lich_xem_api.dart'
    show DiemDon, SalePhuTrach;
import 'package:house_booking/data/services/short_stay_api.dart' show stayIso;

/// ĐẶT PHÒNG NGẮN HẠN — màn đặt phòng + phiếu đặt phòng (16/09/2026).
///
///     GET  /api/short-stays/rooms/{id}/thong-tin-dat?house_id=
///     GET  /api/short-stays/rooms/{id}/lich-ban?tu_ngay=&so_ngay=
///     POST /api/short-stays/quote
///
/// Tin bán theo HẠNG PHÒNG (backend 0130) đi bộ endpoint song song
/// `/api/short-stays/tin/{house_id}/…` — khách chọn hạng, SERVER bốc phòng
/// trống. App không tự chọn phòng: nó không biết phòng nào vừa có người giữ,
/// và "còn trống" ở chợ phải là cùng một con số với quầy lễ tân.
///
///     GET  /api/short-stays/tin/{id}/thong-tin-dat
///     GET  /api/short-stays/tin/{id}/lich-ban?tu_ngay=&so_ngay=
///     POST /api/short-stays/tin/{id}/quote
///     POST /api/short-stays/tin/{id}/dat
///     POST /api/guest/reservations
///     GET  /api/guest/reservations/{id}/phieu
///     POST /api/guest/reservations/{id}/cancel
///
/// Mọi mốc giờ ở đây là GIỜ TƯỜNG Việt Nam (các trường năm/tháng/ngày/giờ của
/// `DateTime` chính là giờ VN), đi ra server qua `stayIso` (+07:00). Máy khách ở
/// múi giờ khác vẫn thấy đúng giờ nhận phòng ghi trên phiếu.
class DatPhongApi {
  const DatPhongApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<ThongTinDatPhong> thongTinDat(int roomId, {int? houseId}) async =>
      ThongTinDatPhong.fromMap(
        await _c.get(
          '/api/short-stays/rooms/$roomId/thong-tin-dat',
          queryParameters: {if (houseId != null) 'house_id': '$houseId'},
        ),
      );

  Future<List<KhoangBan>> lichBan(
    int roomId,
    DateTime tuNgay, {
    int soNgay = 14,
  }) async {
    final m = await _c.get(
      '/api/short-stays/rooms/$roomId/lich-ban',
      queryParameters: {
        'tu_ngay':
            '${tuNgay.year}-${_hai(tuNgay.month)}-${_hai(tuNgay.day)}',
        'so_ngay': '$soNgay',
      },
    );
    return [
      for (final x in (m['ban'] as List? ?? const []))
        KhoangBan.fromMap((x as Map).cast<String, dynamic>()),
    ];
  }

  /// Tin neo hạng: phiếu đặt dựng trên một phòng ĐẠI DIỆN của hạng, kèm khối
  /// `hang_phong` (còn mấy phòng) — app không hiện số phòng cụ thể.
  Future<ThongTinDatPhong> thongTinDatTheoTin(int houseId) async =>
      ThongTinDatPhong.fromMap(
        await _c.get('/api/short-stays/tin/$houseId/thong-tin-dat'),
      );

  /// Khoảng bận của CẢ HẠNG = khoảng mà mọi phòng trong hạng đều bận.
  Future<List<KhoangBan>> lichBanTheoTin(
    int houseId,
    DateTime tuNgay, {
    int soNgay = 14,
  }) async {
    final m = await _c.get(
      '/api/short-stays/tin/$houseId/lich-ban',
      queryParameters: {
        'tu_ngay': '${tuNgay.year}-${_hai(tuNgay.month)}-${_hai(tuNgay.day)}',
        'so_ngay': '$soNgay',
      },
    );
    return [
      for (final x in (m['ban'] as List? ?? const []))
        KhoangBan.fromMap((x as Map).cast<String, dynamic>()),
    ];
  }

  Future<BaoGiaPhong> baoGiaTheoTin(
    int houseId,
    String hinhThuc,
    DateTime nhan,
    DateTime tra,
  ) async => BaoGiaPhong.fromMap(
    await _c.post(
      '/api/short-stays/tin/$houseId/quote',
      body: {
        'booking_mode': hinhThuc,
        'check_in_at': stayIso(nhan),
        'check_out_at': stayIso(tra),
      },
    ),
  );

  /// Đặt theo hạng — KHÔNG gửi `room_id`: server bốc phòng trống rồi ghi đơn.
  Future<int> datTheoTin({
    required int houseId,
    required BaoGiaPhong baoGia,
    required String ten,
    required String sdt,
    required int soKhach,
    String ghiChu = '',
  }) async {
    final m = await _c.post(
      '/api/short-stays/tin/$houseId/dat',
      body: {
        'booking_mode': baoGia.hinhThuc,
        'check_in_at': baoGia.nhanIso,
        'check_out_at': baoGia.traIso,
        'quote_token': baoGia.maBaoGia,
        'guest_name': ten,
        'guest_phone': sdt,
        'so_khach': soKhach,
        'note': ghiChu,
      },
    );
    return (m['id'] as num).toInt();
  }

  Future<BaoGiaPhong> baoGia(
    int roomId,
    String hinhThuc,
    DateTime nhan,
    DateTime tra,
  ) async => BaoGiaPhong.fromMap(
    await _c.post(
      '/api/short-stays/quote',
      body: {
        'room_id': roomId,
        'booking_mode': hinhThuc,
        'check_in_at': stayIso(nhan),
        'check_out_at': stayIso(tra),
      },
    ),
  );

  /// Đặt phòng — trả id đơn để mở phiếu. KHÔNG gửi sale: server tự xác định
  /// sale phụ trách phòng, app không được tự ghi công cho ai.
  Future<int> datPhong({
    required BaoGiaPhong baoGia,
    required String ten,
    required String sdt,
    required int soKhach,
    String ghiChu = '',
    int? houseId,
  }) async {
    final m = await _c.post(
      '/api/guest/reservations',
      body: {
        if (houseId != null) 'house_id': houseId,
        'room_id': baoGia.roomId,
        'booking_mode': baoGia.hinhThuc,
        'check_in_at': baoGia.nhanIso,
        'check_out_at': baoGia.traIso,
        'quote_token': baoGia.maBaoGia,
        'guest_name': ten,
        'guest_phone': sdt,
        'so_khach': soKhach,
        'note': ghiChu,
        'source': 'marketplace',
      },
    );
    return (m['id'] as num).toInt();
  }

  Future<PhieuDatPhong> phieu(int id) async =>
      PhieuDatPhong.fromMap(await _c.get('/api/guest/reservations/$id/phieu'));

  /// Dòng thời gian của đơn — mới nhất trước.
  Future<List<SuKienLichSu>> lichSu(int id) async =>
      suKienTuList(await _c.getList('/api/guest/reservations/$id/lich-su'));

  /// Sửa tên / SĐT / số khách / ghi chú. Chỉ gửi trường có đổi.
  Future<PhieuDatPhong> suaThongTin(
    int id, {
    String? ten,
    String? sdt,
    int? soKhach,
    String? ghiChu,
  }) async => PhieuDatPhong.fromMap(
    await _c.patch(
      '/api/guest/reservations/$id',
      body: {
        if (ten != null) 'guest_name': ten,
        if (sdt != null) 'guest_phone': sdt,
        if (soKhach != null) 'so_khach': soKhach,
        if (ghiChu != null) 'note': ghiChu,
      },
    ),
  );

  /// Báo giá cho giờ mới — server BỎ QUA chính đơn này khi xét trùng lịch.
  Future<BaoGiaPhong> baoGiaDoiGio(
    int id,
    String hinhThuc,
    DateTime nhan,
    DateTime tra,
  ) async => BaoGiaPhong.fromMap(
    await _c.post(
      '/api/guest/reservations/$id/doi-gio/bao-gia',
      body: {
        'booking_mode': hinhThuc,
        'check_in_at': stayIso(nhan),
        'check_out_at': stayIso(tra),
      },
    ),
  );

  /// Đổi giờ theo báo giá vừa xem → đơn về chờ sale xác nhận lại.
  Future<PhieuDatPhong> doiGio(int id, BaoGiaPhong baoGia) async =>
      PhieuDatPhong.fromMap(
        await _c.post(
          '/api/guest/reservations/$id/doi-gio',
          body: {
            'booking_mode': baoGia.hinhThuc,
            'check_in_at': baoGia.nhanIso,
            'check_out_at': baoGia.traIso,
            'quote_token': baoGia.maBaoGia,
          },
        ),
      );

  Future<void> huy(int id, {String lyDo = ''}) async {
    await _c.post(
      '/api/guest/reservations/$id/cancel',
      body: {if (lyDo.isNotEmpty) 'reason': lyDo},
    );
  }
}

String _hai(int n) => n.toString().padLeft(2, '0');
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
double? _dn(dynamic v) => (v as num?)?.toDouble();

/// '2026-09-18T14:00:00+07:00' → DateTime mang giờ tường VN (14:00).
DateTime? gioVN(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final d = DateTime.tryParse(iso);
  if (d == null) return null;
  final vn = d.toUtc().add(const Duration(hours: 7));
  return DateTime(vn.year, vn.month, vn.day, vn.hour, vn.minute);
}

class GoiLuuTru {
  const GoiLuuTru({
    required this.hinhThuc,
    required this.nhan,
    required this.donVi,
    required this.donGia,
    this.quyTac = '',
    this.chinhSachHuy = '',
    this.huyTruocGio = 0,
  });

  factory GoiLuuTru.fromMap(Map<String, dynamic> m) => GoiLuuTru(
    hinhThuc: m['booking_mode'] as String? ?? '',
    nhan: m['label'] as String? ?? '',
    donVi: m['unit'] as String? ?? '',
    donGia: _dn(m['unit_price']) ?? 0,
    quyTac: m['stay_rule'] as String? ?? '',
    chinhSachHuy: m['cancellation_policy'] as String? ?? '',
    huyTruocGio: _i(m['free_cancel_hours']),
  );

  /// theo_gio · qua_dem · theo_ngay
  final String hinhThuc;
  final String nhan;
  final String donVi;
  final double donGia;
  final String quyTac;
  final String chinhSachHuy;
  final int huyTruocGio;
}

class PhongDat {
  const PhongDat({
    required this.roomId,
    required this.ma,
    this.hang = 'Phòng',
    this.toa = '',
    this.anh,
    this.dienTich,
    this.sucChua,
    this.diaChi = '',
    this.houseId,
  });

  factory PhongDat.fromMap(Map<String, dynamic> m) => PhongDat(
    roomId: _i(m['room_id']),
    ma: m['ma'] as String? ?? '',
    hang: m['hang'] as String? ?? 'Phòng',
    toa: m['toa'] as String? ?? '',
    anh: m['anh'] as String?,
    dienTich: _dn(m['dien_tich']),
    sucChua: (m['suc_chua'] as num?)?.toInt(),
    diaChi: m['dia_chi'] as String? ?? '',
    houseId: (m['house_id'] as num?)?.toInt(),
  );

  final int roomId;
  final String ma;
  final String hang;
  final String toa;
  final String? anh;
  final double? dienTich;
  final int? sucChua;
  final String diaChi;
  final int? houseId;
}

SalePhuTrach? _sale(dynamic m) => m == null
    ? null
    : SalePhuTrach.fromMap({
        ...(m as Map).cast<String, dynamic>(),
        // Thẻ sale dùng chung với lịch xem đếm "lượt xem"; ở đây là lượt ở.
        'so_lan_xem_xong': 0,
      });

class ThongTinDatPhong {
  const ThongTinDatPhong({
    required this.phong,
    this.goi = const [],
    this.sale,
    this.soDonXong = 0,
    this.nhanDat = true,
    this.diemDen = const DiemDon(),
    this.gioTra = 12,
    this.chinhSach = const [],
    this.hangPhong,
    this.datTheoHang = false,
    this.conTrongBayGio = true,
  });

  factory ThongTinDatPhong.fromMap(Map<String, dynamic> m) => ThongTinDatPhong(
    phong: PhongDat.fromMap((m['phong'] as Map).cast<String, dynamic>()),
    goi: [
      for (final g in (m['goi'] as List? ?? const []))
        GoiLuuTru.fromMap((g as Map).cast<String, dynamic>()),
    ],
    sale: _sale(m['sale']),
    soDonXong: _i((m['sale'] as Map?)?['so_don_xong']),
    nhanDat: m['nhan_dat'] as bool? ?? true,
    hangPhong: (m['hang_phong'] as Map?)?.cast<String, dynamic>(),
    datTheoHang: m['dat_theo_hang'] == true,
    conTrongBayGio: m['con_trong_bay_gio'] as bool? ?? true,
    diemDen: DiemDon.fromMap(
      (m['diem_den'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    gioTra: _i(m['gio_tra']) == 0 ? 12 : _i(m['gio_tra']),
    chinhSach: [for (final s in (m['chinh_sach'] as List? ?? const [])) '$s'],
  );

  final PhongDat phong;
  final List<GoiLuuTru> goi;
  final SalePhuTrach? sale;

  /// Lượt khách đã ở xong qua sale này.
  final int soDonXong;

  /// false = phòng chưa có sale phụ trách → server không nhận đặt online.
  final bool nhanDat;
  final DiemDon diemDen;
  final int gioTra;
  final List<String> chinhSach;

  /// Hạng đang bán (tin neo hạng): ten · suc_chua · giuong · so_phong · giá.
  final Map<String, dynamic>? hangPhong;

  /// true = khách đặt HẠNG, lễ tân gán số phòng lúc nhận → màn đặt phòng
  /// không hiện mã phòng, vì mã ấy có thể đổi trước khi khách tới.
  final bool datTheoHang;

  /// Hạng còn phòng trống NGAY BÂY GIỜ. false không chặn đặt — khách vẫn chọn
  /// ngày khác được, chỉ nói rõ hiện đang kín.
  final bool conTrongBayGio;

  /// Số phòng của hạng (tin neo hạng); 0 khi tin neo theo phòng lẻ.
  int get soPhongCuaHang => (hangPhong?['so_phong'] as num?)?.toInt() ?? 0;

  String get tenHang => (hangPhong?['ten'] as String?) ?? '';

  GoiLuuTru? goiCua(String hinhThuc) {
    for (final g in goi) {
      if (g.hinhThuc == hinhThuc) return g;
    }
    return null;
  }

  double? get giaThapNhat => goi.isEmpty
      ? null
      : goi.map((g) => g.donGia).reduce((a, b) => a < b ? a : b);
}

class KhoangBan {
  const KhoangBan(this.tu, this.den);

  factory KhoangBan.fromMap(Map<String, dynamic> m) =>
      KhoangBan(gioVN(m['tu'] as String?)!, gioVN(m['den'] as String?)!);

  final DateTime tu;
  final DateTime den;

  bool chong(DateTime a, DateTime b) => a.isBefore(den) && tu.isBefore(b);
}

class BaoGiaPhong {
  const BaoGiaPhong({
    required this.roomId,
    required this.hinhThuc,
    required this.nhanIso,
    required this.traIso,
    required this.maBaoGia,
    required this.soLuong,
    required this.donVi,
    required this.donGia,
    required this.tong,
    this.phuPhi = 0,
    this.huyMienPhiDen,
  });

  factory BaoGiaPhong.fromMap(Map<String, dynamic> m) => BaoGiaPhong(
    roomId: _i(m['room_id']),
    hinhThuc: m['booking_mode'] as String? ?? '',
    nhanIso: m['check_in_at'] as String? ?? '',
    traIso: m['check_out_at'] as String? ?? '',
    maBaoGia: m['quote_token'] as String? ?? '',
    soLuong: _i(m['quantity']),
    donVi: m['unit'] as String? ?? '',
    donGia: _dn(m['unit_price']) ?? 0,
    tong: _dn(m['total_amount']) ?? 0,
    phuPhi: _dn(m['fees']) ?? 0,
    huyMienPhiDen: gioVN(m['free_cancel_until'] as String?),
  );

  final int roomId;
  final String hinhThuc;
  final String nhanIso;
  final String traIso;

  /// Phiên bản giá server vừa báo — giá đổi giữa chừng thì server từ chối đặt.
  final String maBaoGia;
  final int soLuong;
  final String donVi;
  final double donGia;
  final double tong;
  final double phuPhi;
  final DateTime? huyMienPhiDen;

  DateTime? get nhan => gioVN(nhanIso);
  DateTime? get tra => gioVN(traIso);
}

class PhieuDatPhong {
  const PhieuDatPhong({
    required this.id,
    required this.ma,
    required this.phong,
    this.trangThai = 'pending',
    this.nhanTrangThai = '',
    this.hinhThuc = 'theo_gio',
    this.nhan,
    this.tra,
    this.soLuong = 0,
    this.donVi = '',
    this.donGia = 0,
    this.tong = 0,
    this.huyMienPhiDen,
    this.huyDuoc = false,
    this.soKhach,
    this.tenKhach = '',
    this.sdtKhach = '',
    this.ghiChu = '',
    this.lyDoTuChoi = '',
    this.sale,
    this.diemDen = const DiemDon(),
    this.chinhSach = const [],
  });

  factory PhieuDatPhong.fromMap(Map<String, dynamic> m) => PhieuDatPhong(
    id: _i(m['id']),
    ma: m['ma'] as String? ?? '',
    trangThai: m['trang_thai'] as String? ?? 'pending',
    nhanTrangThai: m['nhan_trang_thai'] as String? ?? '',
    hinhThuc: m['hinh_thuc'] as String? ?? 'theo_gio',
    nhan: gioVN(m['nhan_luc'] as String?),
    tra: gioVN(m['tra_luc'] as String?),
    soLuong: _i(m['so_luong']),
    donVi: m['don_vi'] as String? ?? '',
    donGia: _dn(m['don_gia']) ?? 0,
    tong: _dn(m['tong']) ?? 0,
    huyMienPhiDen: gioVN(m['huy_mien_phi_den'] as String?),
    huyDuoc: m['huy_duoc'] as bool? ?? false,
    soKhach: (m['so_khach'] as num?)?.toInt(),
    tenKhach: m['ten_khach'] as String? ?? '',
    sdtKhach: m['sdt_khach'] as String? ?? '',
    ghiChu: m['ghi_chu'] as String? ?? '',
    lyDoTuChoi: m['ly_do_tu_choi'] as String? ?? '',
    phong: PhongDat.fromMap((m['phong'] as Map).cast<String, dynamic>()),
    sale: _sale(m['sale']),
    diemDen: DiemDon.fromMap(
      (m['diem_den'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    chinhSach: [for (final s in (m['chinh_sach'] as List? ?? const [])) '$s'],
  );

  final int id;
  final String ma;

  /// pending · approved · checked_in · checked_out · cancelled · rejected · no_show
  final String trangThai;
  final String nhanTrangThai;
  final String hinhThuc;
  final DateTime? nhan;
  final DateTime? tra;
  final int soLuong;
  final String donVi;
  final double donGia;
  final double tong;
  final DateTime? huyMienPhiDen;
  final bool huyDuoc;
  final int? soKhach;
  final String tenKhach;
  final String sdtKhach;
  final String ghiChu;
  final String lyDoTuChoi;
  final PhongDat phong;
  final SalePhuTrach? sale;
  final DiemDon diemDen;
  final List<String> chinhSach;

  bool get daXacNhan =>
      trangThai == 'approved' ||
      trangThai == 'checked_in' ||
      trangThai == 'checked_out';
  bool get daDong =>
      trangThai == 'cancelled' ||
      trangThai == 'rejected' ||
      trangThai == 'no_show';
}
