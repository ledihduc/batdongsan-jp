import 'package:house_booking/data/services/api_client.dart';

/// Lịch phòng trống của chủ nhà (`/api/host/.../lich-phong`).
///
/// Thay cho cờ `vacant/occupied` — một bóng đèn bật/tắt không trả lời được câu
/// người ta thật sự hỏi khi nhấc máy: **"trống từ ngày nào?"**
class LichPhongApi {
  const LichPhongApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<List<PhongCoLich>> cuaToa(
    int buildingId, {
    DateTime? tu,
    DateTime? den,
  }) async {
    final r = await _c.getList(
      '/api/host/buildings/$buildingId/lich-phong',
      queryParameters: {
        if (tu != null) 'tu': _iso(tu),
        if (den != null) 'den': _iso(den),
      },
    );
    return r
        .whereType<Map>()
        .map((e) => PhongCoLich.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<KhoangBan> chan(
    int roomId, {
    required DateTime tuNgay,
    required DateTime denNgay,
    String? ghiChu,
  }) async => KhoangBan.fromMap(
    await _c.post(
      '/api/host/rooms/$roomId/chan',
      body: {
        'tu_ngay': _iso(tuNgay),
        'den_ngay': _iso(denNgay),
        if (ghiChu != null && ghiChu.isNotEmpty) 'ghi_chu': ghiChu,
      },
    ),
  );

  Future<void> boChan(int khoangId) async =>
      _c.delete('/api/host/chan/$khoangId');

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class PhongCoLich {
  const PhongCoLich({
    required this.roomId,
    required this.ma,
    required this.khoang,
  });

  final int roomId;
  final String ma;
  final List<KhoangBan> khoang;

  /// Phòng trống suốt khoảng đang xem — không có khoảng bận nào.
  bool get trongCaKy => khoang.isEmpty;

  /// Ngày phòng trống trở lại: cuối khoảng bận muộn nhất. Null nếu đang trống.
  DateTime? get trongTuNgay {
    if (khoang.isEmpty) return null;
    return khoang
        .map((k) => k.denNgay)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  factory PhongCoLich.fromMap(Map<String, dynamic> m) => PhongCoLich(
    roomId: (m['room_id'] as num?)?.toInt() ?? 0,
    ma: m['ma'] as String? ?? '',
    khoang: (m['khoang'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => KhoangBan.fromMap(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

class KhoangBan {
  const KhoangBan({
    required this.id,
    required this.roomId,
    required this.tuNgay,
    required this.denNgay,
    required this.kenh,
    required this.nguon,
    required this.goDuoc,
    this.ghiChu,
  });

  final int id;
  final int roomId;
  final DateTime tuNgay;

  /// Ngày TRẢ phòng — không tính vào khoảng bận.
  final DateTime denNgay;
  final String kenh;

  /// 'contract' | 'reservation' | 'thu_cong'
  final String nguon;

  /// Gỡ được ngay ở màn lịch, hay phải huỷ chứng từ gốc.
  final bool goDuoc;
  final String? ghiChu;

  String get nhanNguon => switch (nguon) {
    'contract' => 'Hợp đồng thuê',
    'reservation' => 'Đơn đặt phòng',
    _ => ghiChu?.isNotEmpty == true ? ghiChu! : 'Tự chặn',
  };

  /// Số đêm/ngày bị chiếm. `denNgay` không tính nên đây là hiệu hai mốc.
  int get soNgay => denNgay.difference(tuNgay).inDays;

  factory KhoangBan.fromMap(Map<String, dynamic> m) => KhoangBan(
    id: (m['id'] as num?)?.toInt() ?? 0,
    roomId: (m['room_id'] as num?)?.toInt() ?? 0,
    tuNgay: DateTime.parse(m['tu_ngay'] as String),
    denNgay: DateTime.parse(m['den_ngay'] as String),
    kenh: m['kenh'] as String? ?? 'dai_han',
    nguon: m['nguon'] as String? ?? 'thu_cong',
    goDuoc: m['go_duoc'] as bool? ?? false,
    ghiChu: m['ghi_chu'] as String?,
  );
}
