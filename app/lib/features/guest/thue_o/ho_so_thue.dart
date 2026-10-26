import 'package:house_booking/core/config/api_config.dart';

/// Hồ sơ phòng KHÁCH đang thuê — đọc từ `GET /api/guest/dang-thue/{id}/ho-so`.
///
/// Một lần tải cho cả chuỗi màn của khách (mockup 04/10/2026): chi tiết phòng ·
/// hợp đồng · hoá đơn · chi tiết hoá đơn · điện nước. Các màn con nhận lại
/// đúng đối tượng này, không tự gọi lại API.
class HoSoThue {
  HoSoThue(this.raw);

  final Map<String, dynamic> raw;

  Map<String, dynamic> get _room => _map(raw['room']);
  Map<String, dynamic> get _toa => _map(raw['toa']);
  Map<String, dynamic> get _hd => _map(raw['hop_dong']);
  Map<String, dynamic> get _dn => _map(raw['dien_nuoc']);

  int get contractId => _int(_hd['id']);
  String get maPhong => _str(_room['code']);
  String get tenToa => _str(_toa['ten']);

  /// "Phòng 305 – Vạn Phúc Residence".
  String get tieuDe => [
    if (maPhong.isNotEmpty)
      'Phòng ${maPhong.replaceFirst(RegExp(r'^[Pp](?=\d)'), '')}',
    if (tenToa.isNotEmpty) tenToa,
  ].join(' – ');

  /// "Quận 7, TP.HCM" — hai vế cuối của địa chỉ toà.
  String get diaChiNgan {
    final ve = _str(_toa['dia_chi'])
        .split(RegExp(r'[,·]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return ve.length <= 2
        ? ve.join(', ')
        : ve.sublist(ve.length - 2).join(', ');
  }

  String get diaChi => _str(_toa['dia_chi']).replaceAll(' · ', ', ');

  List<String> get anh => [
    for (final x in (_room['images'] as List? ?? const []))
      if (x is String && x.isNotEmpty) duongDanAnh(x),
  ];

  // Thông tin phòng
  String get loaiPhong {
    final lp = _room['loai_phong'];
    if (lp is Map && _str(lp['ten']).isNotEmpty) return _str(lp['ten']);
    if (lp is String && lp.isNotEmpty) return lp;
    return 'Phòng trọ';
  }

  String get tang => _str(_room['tang']).isEmpty ? '—' : _str(_room['tang']);
  String get dienTich {
    final a = _room['area_m2'];
    if (a is! num || a <= 0) return '—';
    return '${a % 1 == 0 ? a.toInt() : a} m²';
  }

  String get noiThat {
    final ds = [
      for (final x in (raw['tai_san'] as List? ?? const []))
        if (x is Map) _str(x['ten']),
      for (final x in (_room['do_trong_phong'] as List? ?? const []))
        if (x is String) x,
    ].where((s) => s.isNotEmpty).toList();
    if (ds.isEmpty) return 'Cơ bản';
    return ds.length >= 4 ? 'Đầy đủ' : ds.join(', ');
  }

  // Hợp đồng
  DateTime? get batDau => _ngay(_hd['bat_dau']);
  DateTime? get ketThuc => _ngay(_hd['ket_thuc']);
  double get tienThue => _num(_hd['tien_thue']);
  double get tienCoc => _num(_hd['tien_coc']);
  int? get ngayThanhToan => (_hd['ngay_thanh_toan'] as num?)?.toInt();
  String get hinhThucThanhToan {
    final s = _str(_hd['hinh_thuc_thanh_toan']);
    return switch (s) {
      '' => 'Chuyển khoản',
      'chuyen_khoan' => 'Chuyển khoản',
      'tien_mat' => 'Tiền mặt',
      _ => s,
    };
  }

  DateTime? get ngayKy => _ngay(raw['ngay_ky']) ?? batDau;
  List<String> get anhHopDong => [
    for (final x in (raw['anh_hop_dong'] as List? ?? const []))
      if (x is String && x.isNotEmpty) duongDanAnh(x),
  ];

  /// "HD305_01092024.pdf" — tên hiển thị của tệp hợp đồng.
  String get tenTepHopDong {
    final d = ngayKy;
    final ngay = d == null ? '' : '_${hai(d.day)}${hai(d.month)}${d.year}';
    final so = maPhong.replaceAll(RegExp(r'[^0-9]'), '');
    return 'HD$so$ngay.pdf';
  }

  // Liên hệ & thanh toán (khối riêng của màn khách)
  Map<String, dynamic>? get lienHe =>
      raw['lien_he'] is Map ? _map(raw['lien_he']) : null;
  Map<String, dynamic>? get taiKhoan =>
      raw['thanh_toan'] is Map ? _map(raw['thanh_toan']) : null;

  // Hoá đơn
  List<HoaDonThue> get hoaDon => [
    for (final x in (raw['hoa_don'] as List? ?? const []))
      if (x is Map) HoaDonThue(_map(x)),
  ];

  /// Giấy tờ hợp đồng còn thiếu ('hop_dong' · 'minh_chung_coc') — cảnh báo,
  /// không chặn: khách tự chụp và tải bổ sung được.
  List<String> get giayToThieu => [
    for (final x in (raw['giay_to_thieu'] as List? ?? const [])) '$x',
  ];

  // Điện nước
  String get thangDienNuoc => _str(_dn['thang']);
  String get trangThaiDienNuoc => _str(_dn['trang_thai']);

  /// Ai đưa ra số kỳ này: 'khach' | 'chu_nha' | '' (chưa có).
  String get nguoiGhiDienNuoc => _str(_dn['nguoi_ghi']);
  String get lyDoTraVeDienNuoc => _str(_dn['ly_do_tra_ve']);

  /// Nước tính theo người — khách chỉ gửi ảnh công tơ điện.
  bool get nuocTheoNguoi => _dn['nuoc_theo_nguoi'] == true;
  List<KyDienNuoc> get lichSuDienNuoc => [
    for (final x in (raw['dien_nuoc_lich_su'] as List? ?? const []))
      if (x is Map) KyDienNuoc(_map(x)),
  ];
}

class HoaDonThue {
  HoaDonThue(this.raw);

  final Map<String, dynamic> raw;

  int get id => _int(raw['id']);
  String get so => _str(raw['so']);

  /// "2024-10" → "10/2024".
  String get ky {
    final k = _str(raw['ky']);
    final p = k.split('-');
    return p.length == 2 ? '${p[1]}/${p[0]}' : k;
  }

  double get tong => _num(raw['tong']);
  double get daTra => _num(raw['da_tra']);
  String get trangThai => _str(raw['trang_thai']);
  DateTime? get han => _ngay(raw['han_dong']);

  bool get daThanhToan => trangThai == 'paid' || (tong > 0 && daTra >= tong);

  bool get quaHan {
    final h = han;
    if (daThanhToan || h == null) return false;
    final n = DateTime.now();
    return h.isBefore(DateTime(n.year, n.month, n.day));
  }
}

class KyDienNuoc {
  KyDienNuoc(this.raw);

  final Map<String, dynamic> raw;

  /// "2024-10" → "10/2024".
  String get ky {
    final p = _str(raw['thang']).split('-');
    return p.length == 2 ? '${p[1]}/${p[0]}' : _str(raw['thang']);
  }

  String get thang => _str(raw['thang']);
  DateTime? get ngayGui => _ngay(raw['ngay_gui']);
  String get trangThai => _str(raw['trang_thai']);

  /// false = chủ nhà tự ghi số kỳ này (khách không gửi).
  bool get nguoiThueGui => raw['nguoi_thue_gui'] != false;

  /// Ảnh công tơ của kỳ — của khách HOẶC của chủ nhà, hai bên xem chung.
  List<String> get anh => [
    for (final k in const ['anh_dien', 'anh_nuoc'])
      if (_str(raw[k]).isNotEmpty) _str(raw[k]),
  ];
}

// ── Định dạng dùng chung cho các màn thuê ở ───────────────────────────────
String hai(int n) => n.toString().padLeft(2, '0');

String ngayVN(DateTime? d) =>
    d == null ? '—' : '${hai(d.day)}/${hai(d.month)}/${d.year}';

/// 5090000 → "5.090.000đ".
String tienVN(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}${b}đ';
}

/// "Còn 10 tháng" (hoặc "Còn 12 ngày" khi dưới một tháng).
String conLai(DateTime? het) {
  if (het == null) return '';
  final n = DateTime.now();
  final ngay = het.difference(DateTime(n.year, n.month, n.day)).inDays;
  if (ngay < 0) return 'Đã hết hạn';
  if (ngay < 31) return 'Còn $ngay ngày';
  var thang = (het.year - n.year) * 12 + het.month - n.month;
  if (het.day < n.day) thang -= 1;
  return 'Còn ${thang < 1 ? 1 : thang} tháng';
}

String duongDanAnh(String u) =>
    u.startsWith('http') ? u : '${ApiConfig.baseUrl}$u';

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};
String _str(dynamic v) => v == null ? '' : v.toString().trim();
int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;
DateTime? _ngay(dynamic v) {
  final s = _str(v);
  if (s.length < 10) return null;
  return DateTime.tryParse(s.substring(0, 10));
}
