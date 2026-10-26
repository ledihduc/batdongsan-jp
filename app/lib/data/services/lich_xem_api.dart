import 'package:house_booking/data/models/su_kien_lich_su.dart';
import 'package:house_booking/data/services/api_client.dart';

/// ĐẶT LỊCH XEM NHÀ (thuê dài hạn) — màn đặt lịch + phiếu hẹn (15/09/2026).
///
///     GET  /api/viewing-appointments/thong-tin-dat?house_id=|room_id=
///     GET  /api/houses/{id}/available-slots?date=   (hoặc /api/rooms/{id}/…)
///     POST /api/viewing-appointments
///     GET  /api/viewing-appointments/{id}/phieu
///
/// BẬN GIỜ NÀY — bên bán xin đổi giờ, khách chọn lại:
///
///     GET  /api/viewing-appointments/{id}/gio-trong   (cả hai phía)
///     POST /api/viewing-appointments/{id}/doi-gio     (sale/chủ nhà)
///     POST /api/viewing-appointments/{id}/chon-gio    (khách)
///
/// SĐT sale bị CHE ở `thongTinDat` (trang ai cũng mở được) và chỉ lộ ở `phieu`
/// — sau khi khách đã có lịch hẹn thật.
class LichXemApi {
  const LichXemApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<ThongTinDatLich> thongTinDat({int? houseId, int? roomId}) async =>
      ThongTinDatLich.fromMap(
        await _c.get(
          '/api/viewing-appointments/thong-tin-dat',
          queryParameters: {
            if (houseId != null) 'house_id': '$houseId',
            if (roomId != null) 'room_id': '$roomId',
          },
        ),
      );

  /// Khung giờ một ngày. Có phòng thì hỏi theo PHÒNG (phòng chưa gắn tin vẫn
  /// đặt được), không thì theo tin.
  Future<List<KhungGio>> khungGio(
    String ngay, {
    int? houseId,
    int? roomId,
  }) async {
    final m = await _c.get(
      roomId != null
          ? '/api/rooms/$roomId/available-slots'
          : '/api/houses/$houseId/available-slots',
      queryParameters: {'date': ngay},
    );
    return [
      for (final x in (m['slots'] as List? ?? const []))
        KhungGio.fromMap((x as Map).cast<String, dynamic>()),
    ];
  }

  Future<PhieuHen> datLich({
    int? houseId,
    int? roomId,
    required String ngay,
    required String gio,
    required String hinhThuc,
    required int soNguoi,
    required String tenKhach,
    required String sdtKhach,
    String loiNhan = '',
  }) async {
    final m = await _c.post(
      '/api/viewing-appointments',
      body: {
        if (houseId != null) 'house_id': houseId,
        if (roomId != null) 'room_id': roomId,
        'booking_date': ngay,
        'booking_time': gio,
        'hinh_thuc': hinhThuc,
        'so_nguoi': soNguoi,
        'ten_khach': tenKhach,
        'sdt_khach': sdtKhach,
        'message': loiNhan,
      },
    );
    return PhieuHen.fromMap((m['phieu'] as Map).cast<String, dynamic>());
  }

  Future<PhieuHen> phieu(int id) async =>
      PhieuHen.fromMap(await _c.get('/api/viewing-appointments/$id/phieu'));

  /// Giờ còn đặt được trong vài ngày tới — đã bỏ khung bên bán báo bận.
  Future<List<NgayTrong>> gioTrong(int id, {int soNgay = 7}) async {
    final m = await _c.get(
      '/api/viewing-appointments/$id/gio-trong',
      queryParameters: {'so_ngay': '$soNgay'},
    );
    return [
      for (final x in (m['ngay'] as List? ?? const []))
        NgayTrong.fromMap((x as Map).cast<String, dynamic>()),
    ];
  }

  /// Bên bán bận → đề xuất giờ khác. Trả phiếu đã chuyển `doi_gio`.
  Future<PhieuHen> doiGio(
    int id, {
    required List<GioDeXuat> deXuat,
    String lyDo = '',
  }) async {
    final m = await _c.post(
      '/api/viewing-appointments/$id/doi-gio',
      body: {
        'de_xuat': [for (final g in deXuat) g.toMap()],
        'ly_do': lyDo,
      },
    );
    return PhieuHen.fromMap((m['phieu'] as Map).cast<String, dynamic>());
  }

  /// Dòng thời gian của lịch — mới nhất trước.
  Future<List<SuKienLichSu>> lichSu(int id) async =>
      suKienTuList(await _c.getList('/api/viewing-appointments/$id/lich-su'));

  /// Khách sửa tên / SĐT / số người / hình thức / lời nhắn. Chỉ gửi trường đổi.
  Future<PhieuHen> suaThongTin(
    int id, {
    String? ten,
    String? sdt,
    int? soNguoi,
    String? hinhThuc,
    String? loiNhan,
  }) async {
    final m = await _c.patch(
      '/api/viewing-appointments/$id/khach',
      body: {
        if (ten != null) 'ten_khach': ten,
        if (sdt != null) 'sdt_khach': sdt,
        if (soNguoi != null) 'so_nguoi': soNguoi,
        if (hinhThuc != null) 'hinh_thuc': hinhThuc,
        if (loiNhan != null) 'message': loiNhan,
      },
    );
    return PhieuHen.fromMap((m['phieu'] as Map).cast<String, dynamic>());
  }

  /// Khách tự đổi sang khung giờ trống khác → chờ bên bán duyệt lại.
  Future<PhieuHen> khachDoiLich(int id, GioDeXuat gio) async {
    final m = await _c.post(
      '/api/viewing-appointments/$id/khach-doi-lich',
      body: gio.toMap(),
    );
    return PhieuHen.fromMap((m['phieu'] as Map).cast<String, dynamic>());
  }

  /// Khách huỷ lịch của chính mình (chờ duyệt / đã duyệt / đang chờ chọn giờ).
  Future<PhieuHen> huy(int id, {String lyDo = ''}) async {
    final m = await _c.patch(
      '/api/viewing-appointments/$id/status',
      body: {'status': 'cancelled', 'ly_do': lyDo},
    );
    return PhieuHen.fromMap((m['phieu'] as Map).cast<String, dynamic>());
  }

  /// Khách chọn lại giờ. Giờ bên bán đề xuất → duyệt luôn.
  Future<PhieuHen> chonGio(int id, GioDeXuat gio) async {
    final m = await _c.post(
      '/api/viewing-appointments/$id/chon-gio',
      body: gio.toMap(),
    );
    return PhieuHen.fromMap((m['phieu'] as Map).cast<String, dynamic>());
  }
}

/// Một khung giờ trên một ngày cụ thể: ('2026-09-17', '14:00-15:00').
class GioDeXuat {
  const GioDeXuat({required this.ngay, required this.gio, this.conTrong = true});

  factory GioDeXuat.fromMap(Map<String, dynamic> m) => GioDeXuat(
    ngay: m['ngay'] as String? ?? '',
    gio: m['gio'] as String? ?? '',
    conTrong: m['con_trong'] as bool? ?? true,
  );

  final String ngay;
  final String gio;

  /// Giờ đề xuất có thể bị người khác đặt mất trong lúc khách chưa chọn.
  final bool conTrong;

  String get batDau => gio.split('-').first;
  Map<String, dynamic> toMap() => {'ngay': ngay, 'gio': gio};

  @override
  bool operator ==(Object other) =>
      other is GioDeXuat && other.ngay == ngay && other.gio == gio;

  @override
  int get hashCode => Object.hash(ngay, gio);
}

class NgayTrong {
  const NgayTrong({required this.ngay, this.gio = const []});

  factory NgayTrong.fromMap(Map<String, dynamic> m) => NgayTrong(
    ngay: m['ngay'] as String? ?? '',
    gio: [for (final g in (m['gio'] as List? ?? const [])) '$g'],
  );

  final String ngay;
  final List<String> gio;
}

/// Bên bán đã xin đổi giờ — hiện trên phiếu hẹn.
class DoiGio {
  const DoiGio({
    this.dangChoChon = false,
    this.gioCu = '',
    this.lyDo = '',
    this.nguoiDoi = '',
    this.laSale = false,
    this.deXuat = const [],
  });

  factory DoiGio.fromMap(Map<String, dynamic> m) => DoiGio(
    dangChoChon: m['dang_cho_chon'] as bool? ?? false,
    gioCu: m['gio_cu'] as String? ?? '',
    lyDo: m['ly_do'] as String? ?? '',
    nguoiDoi: m['nguoi_doi'] as String? ?? '',
    laSale: m['la_sale'] as bool? ?? false,
    deXuat: [
      for (final x in (m['de_xuat'] as List? ?? const []))
        GioDeXuat.fromMap((x as Map).cast<String, dynamic>()),
    ],
  );

  final bool dangChoChon;

  /// '2026-09-16 10:00-11:00'
  final String gioCu;
  final String lyDo;
  final String nguoiDoi;
  final bool laSale;
  final List<GioDeXuat> deXuat;
}

double? _dn(dynamic v) => (v as num?)?.toDouble();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

String? _s(dynamic v) {
  final s = v is String ? v.trim() : null;
  return s == null || s.isEmpty ? null : s;
}

class TomTatCan {
  const TomTatCan({
    required this.tieuDe,
    this.anh,
    this.anhDs = const [],
    this.dienTich,
    this.diaChi = '',
    this.gia,
    this.donVi = 'tháng',
    this.houseId,
    this.roomId,
  });

  factory TomTatCan.fromMap(Map<String, dynamic> m) => TomTatCan(
    tieuDe: m['tieu_de'] as String? ?? '',
    anh: _s(m['anh']),
    anhDs: [
      for (final x in (m['anh_ds'] as List? ?? const []))
        if (_s(x) != null) _s(x)!,
    ],
    dienTich: _dn(m['dien_tich']),
    diaChi: m['dia_chi'] as String? ?? '',
    gia: _dn(m['gia']),
    donVi: m['don_vi'] as String? ?? 'tháng',
    houseId: (m['house_id'] as num?)?.toInt(),
    roomId: (m['room_id'] as num?)?.toInt(),
  );

  final String tieuDe;
  final String? anh;

  /// Cả bộ ảnh (server cũ không gửi → rỗng, dùng [anh]).
  final List<String> anhDs;
  final double? dienTich;
  final String diaChi;
  final double? gia;

  /// 'tháng' với thuê · '' với mua bán.
  final String donVi;
  final int? houseId;
  final int? roomId;
}

class SalePhuTrach {
  const SalePhuTrach({
    required this.id,
    required this.ten,
    this.anh,
    this.sdt = '',
    this.soLanXemXong = 0,
    this.danhGia,
    this.khuVuc = '',
  });

  factory SalePhuTrach.fromMap(Map<String, dynamic> m) => SalePhuTrach(
    id: _i(m['id']),
    ten: m['ten'] as String? ?? '',
    anh: _s(m['anh']),
    sdt: m['sdt'] as String? ?? '',
    soLanXemXong: _i(m['so_lan_xem_xong']),
    danhGia: _dn(m['danh_gia']),
    khuVuc: m['khu_vuc'] as String? ?? '',
  );

  final int id;
  final String ten;
  final String? anh;

  /// Bị che (••••456) trước khi đặt; số thật trên phiếu hẹn.
  final String sdt;
  final int soLanXemXong;

  /// Điểm TB đánh giá trên tin sale đăng; `null` = chưa có đánh giá nào.
  final double? danhGia;
  final String khuVuc;

  bool get sdtDaChe => sdt.contains('•');
}

class DiemDon {
  const DiemDon({this.diaChi = '', this.lat, this.lng});

  factory DiemDon.fromMap(Map<String, dynamic> m) => DiemDon(
    diaChi: m['dia_chi'] as String? ?? '',
    lat: _dn(m['lat']),
    lng: _dn(m['lng']),
  );

  final String diaChi;
  final double? lat;
  final double? lng;

  bool get coToaDo => lat != null && lng != null;
}

class ThongTinDatLich {
  const ThongTinDatLich({
    required this.tin,
    this.sale,
    this.diemDon = const DiemDon(),
    this.soNguoiToiDa = 10,
  });

  factory ThongTinDatLich.fromMap(Map<String, dynamic> m) => ThongTinDatLich(
    tin: TomTatCan.fromMap((m['tin'] as Map).cast<String, dynamic>()),
    sale: m['sale'] == null
        ? null
        : SalePhuTrach.fromMap((m['sale'] as Map).cast<String, dynamic>()),
    diemDon: DiemDon.fromMap(
      (m['diem_don'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    soNguoiToiDa: _i(m['so_nguoi_toi_da']) == 0 ? 10 : _i(m['so_nguoi_toi_da']),
  );

  final TomTatCan tin;
  final SalePhuTrach? sale;
  final DiemDon diemDon;
  final int soNguoiToiDa;
}

class KhungGio {
  const KhungGio({required this.gio, this.daCo = false});

  factory KhungGio.fromMap(Map<String, dynamic> m) => KhungGio(
    gio: m['time'] as String? ?? '',
    daCo: m['status'] == 'taken',
  );

  /// Dạng chuẩn của server: '15:00-16:00'.
  final String gio;
  final bool daCo;

  /// '15:00' — mốc bắt đầu, thứ in trên nút.
  String get batDau => gio.split('-').first;
  int get gioBatDau => int.tryParse(batDau.split(':').first) ?? 0;
}

class PhieuHen {
  const PhieuHen({
    required this.id,
    required this.ma,
    required this.ngay,
    required this.gio,
    required this.tin,
    this.trangThai = 'pending',
    this.hinhThuc = 'truc_tiep',
    this.soNguoi = 1,
    this.tenKhach = '',
    this.sdtKhach = '',
    this.loiNhan = '',
    this.sale,
    this.chuNha,
    this.diemDon = const DiemDon(),
    this.doiGio,
    this.loai = 'xem',
    this.ketQua,
  });

  factory PhieuHen.fromMap(Map<String, dynamic> m) => PhieuHen(
    id: _i(m['id']),
    ma: m['ma'] as String? ?? '',
    trangThai: m['trang_thai'] as String? ?? 'pending',
    ngay: m['ngay'] as String? ?? '',
    gio: m['gio'] as String? ?? '',
    hinhThuc: m['hinh_thuc'] as String? ?? 'truc_tiep',
    soNguoi: _i(m['so_nguoi']) == 0 ? 1 : _i(m['so_nguoi']),
    tenKhach: m['ten_khach'] as String? ?? '',
    sdtKhach: m['sdt_khach'] as String? ?? '',
    loiNhan: m['loi_nhan'] as String? ?? '',
    tin: TomTatCan.fromMap((m['tin'] as Map).cast<String, dynamic>()),
    sale: m['sale'] == null
        ? null
        : SalePhuTrach.fromMap((m['sale'] as Map).cast<String, dynamic>()),
    chuNha: m['chu_nha'] == null
        ? null
        : SalePhuTrach.fromMap((m['chu_nha'] as Map).cast<String, dynamic>()),
    diemDon: DiemDon.fromMap(
      (m['diem_don'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    doiGio: m['doi_gio'] == null
        ? null
        : DoiGio.fromMap((m['doi_gio'] as Map).cast<String, dynamic>()),
    loai: m['loai'] as String? ?? 'xem',
    ketQua: _s(m['ket_qua']),
  );

  final int id;
  final String ma;

  /// 'xem' (đi xem nhà) · 'chot' (hẹn chốt phòng).
  final String loai;

  /// Khách đã đánh giá buổi xem: 'chot' · 'khong_chot' · null (chưa).
  final String? ketQua;

  /// pending · approved · doi_gio · rejected · completed · locked · cancelled
  final String trangThai;
  final String ngay;
  final String gio;
  final String hinhThuc;
  final int soNguoi;
  final String tenKhach;
  final String sdtKhach;
  final String loiNhan;
  final TomTatCan tin;
  final SalePhuTrach? sale;

  /// CHỦ NHÀ THẬT — suy từ toà/phòng, KHÔNG phải người đăng tin (tin do sale
  /// đăng nên `host_id` của tin trỏ về chính sale). Null khi lịch không lần ra
  /// toà nào. SĐT là số thật với sale phụ trách và chính chủ nhà, masked với
  /// khách.
  final SalePhuTrach? chuNha;
  final DiemDon diemDon;

  /// Có khi bên bán đã từng xin đổi giờ (kể cả sau khi khách đã chọn lại).
  final DoiGio? doiGio;

  bool get laVideo => hinhThuc == 'video';
  bool get choKhachChonGio => trangThai == 'doi_gio';

  /// Khách còn tự huỷ được — lịch chưa diễn ra, chưa đóng.
  bool get huyDuoc =>
      trangThai == 'pending' || trangThai == 'approved' || choKhachChonGio;

  /// Lịch đã khép lại mà không có buổi xem nào.
  bool get daDong =>
      trangThai == 'cancelled' || trangThai == 'rejected' || trangThai == 'lost';
  bool get daXacNhan => trangThai == 'approved' || trangThai == 'locked';
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
