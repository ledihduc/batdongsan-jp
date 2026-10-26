import 'dart:convert';

import 'package:house_booking/data/services/api_client.dart';

/// eKYC chủ nhà — CCCD hai mặt + chân dung + giấy phép kinh doanh, admin duyệt.
///
/// [token] có giá trị khi mở từ LINK `/ekyc?t=…` (thiết bị khác, không đăng
/// nhập): mọi lệnh gửi kèm `X-Ekyc-Token`. Không có token thì dùng phiên đăng
/// nhập như thường.
///
///     POST /api/ekyc/link · GET /api/ekyc/ho-so · PUT /api/ekyc/thong-tin
///     POST /api/ekyc/anh/{loai} · POST /api/ekyc/nop
class EkycApi {
  const EkycApi({this.token, ApiClient client = const ApiClient()}) : _c = client;

  final String? token;
  final ApiClient _c;

  Map<String, String> get _h => {if (token != null) 'X-Ekyc-Token': token!};

  Future<HoSoEkyc> xem() async => HoSoEkyc.fromMap(await _c.getVoiHeader('/api/ekyc/ho-so', _h));

  Future<HoSoEkyc> luuThongTin({
    required String hoTen,
    required String soCccd,
    required String tenKinhDoanh,
    required String soGpkd,
  }) async => HoSoEkyc.fromMap(
    await _c.putVoiHeader('/api/ekyc/thong-tin', {
      'ho_ten': hoTen,
      'so_cccd': soCccd,
      'ten_kinh_doanh': tenKinhDoanh,
      'so_gpkd': soGpkd,
    }, _h),
  );

  Future<HoSoEkyc> guiAnh(String loai, List<int> bytes) async => HoSoEkyc.fromMap(
    await _c.post('/api/ekyc/anh/$loai', body: {'anh_base64': base64Encode(bytes)}, extraHeaders: _h),
  );

  Future<HoSoEkyc> nop() async =>
      HoSoEkyc.fromMap(await _c.post('/api/ekyc/nop', extraHeaders: _h));

  /// Link làm eKYC trên điện thoại khác (cần đăng nhập, hết hạn sau 24 giờ).
  Future<String> taoLink() async =>
      '${(await _c.post('/api/ekyc/link'))['url'] ?? ''}';
}

/// Ảnh xác minh theo thứ tự chụp: (khoá, nhãn, gợi ý, chụp camera trước?).
/// Chủ dự án 14/10/2026: CCCD chỉ để tự xác thực thông tin (không eKYC chân
/// dung); giấy phép kinh doanh không bắt buộc — thiếu thì chỉ cảnh báo.
const cacAnhEkyc = <(String, String, String, bool)>[
  ('cccd_truoc', 'CCCD mặt trước', 'Đặt thẻ trên nền tối, đủ 4 góc, không lóa', false),
  ('cccd_sau', 'CCCD mặt sau', 'Rõ mã QR và dòng chữ dưới cùng', false),
  (
    'gpkd',
    'Giấy phép kinh doanh (không bắt buộc)',
    'Nếu có: trang có số giấy phép và tên hộ / doanh nghiệp',
    false,
  ),
];

class HoSoEkyc {
  const HoSoEkyc({
    required this.trangThai,
    required this.hoTen,
    required this.soCccdCuoi,
    required this.tenKinhDoanh,
    required this.soGpkd,
    required this.anh,
    required this.thieu,
    required this.suaDuoc,
    this.lyDoTuChoi,
    this.canhBao = const [],
  });

  /// Không chặn nộp — vd "Chưa có ảnh giấy phép kinh doanh".
  final List<String> canhBao;

  /// nhap · cho_duyet · da_duyet · tu_choi
  final String trangThai;
  final String hoTen;
  final String soCccdCuoi;
  final String tenKinhDoanh;
  final String soGpkd;

  /// loại ảnh → đã có chưa (ảnh nhạy cảm KHÔNG trả về app).
  final Map<String, bool> anh;
  final List<String> thieu;
  final bool suaDuoc;
  final String? lyDoTuChoi;

  factory HoSoEkyc.fromMap(Map<String, dynamic> m) => HoSoEkyc(
    trangThai: '${m['trang_thai'] ?? 'nhap'}',
    hoTen: '${m['ho_ten'] ?? ''}',
    soCccdCuoi: '${m['so_cccd_cuoi'] ?? ''}',
    tenKinhDoanh: '${m['ten_kinh_doanh'] ?? ''}',
    soGpkd: '${m['so_gpkd'] ?? ''}',
    anh: {
      for (final e in ((m['anh'] as Map?) ?? const {}).entries) '${e.key}': e.value == true,
    },
    thieu: [for (final x in (m['thieu'] as List? ?? const [])) '$x'],
    suaDuoc: m['sua_duoc'] == true,
    lyDoTuChoi: m['ly_do_tu_choi'] as String?,
    canhBao: [for (final x in (m['canh_bao'] as List? ?? const [])) '$x'],
  );
}
