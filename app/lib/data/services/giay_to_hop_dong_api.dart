import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Giấy tờ của MỘT hợp đồng — ảnh/PDF hợp đồng đã ký + minh chứng cọc.
///
/// Chủ nhà, khách thuê và sale phụ trách cùng xem và cùng tải lên; thuê trước,
/// bổ sung sau (thiếu chỉ là cảnh báo).
///
///     GET    /api/hop-dong/{id}/giay-to
///     POST   /api/hop-dong/{id}/giay-to          {loai, urls}
///     DELETE /api/hop-dong/{id}/giay-to/{tepId}
class GiayToHopDongApi {
  const GiayToHopDongApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<GiayToHopDong> xem(int contractId) async =>
      GiayToHopDong.fromMap(await _c.get('/api/hop-dong/$contractId/giay-to'));

  Future<GiayToHopDong> them(int contractId, String loai, List<String> urls) async =>
      GiayToHopDong.fromMap(
        await _c.post('/api/hop-dong/$contractId/giay-to', body: {'loai': loai, 'urls': urls}),
      );

  Future<GiayToHopDong> xoa(int contractId, int tepId) async =>
      GiayToHopDong.fromMap(await _c.delete('/api/hop-dong/$contractId/giay-to/$tepId'));
}

const kHopDong = 'hop_dong';
const kMinhChungCoc = 'minh_chung_coc';

String nhanGiayTo(String loai) => loai == kHopDong ? 'Hợp đồng' : 'Minh chứng cọc';

class TepGiayTo {
  const TepGiayTo({
    required this.id,
    required this.url,
    required this.nhanVai,
    this.nguoiTai,
    this.luc,
    this.xoaDuoc = false,
  });

  /// null = tệp nộp trong hồ sơ chốt thuê qua sale (không gỡ ở đây).
  final int? id;
  final String url;
  final String nhanVai;
  final String? nguoiTai;
  final DateTime? luc;
  final bool xoaDuoc;

  bool get laPdf => url.toLowerCase().endsWith('.pdf');

  /// URL đầy đủ để hiển thị — server lưu đường dẫn '/uploads/…'.
  String get day => url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

  factory TepGiayTo.fromMap(Map<String, dynamic> m) => TepGiayTo(
    id: (m['id'] as num?)?.toInt(),
    url: '${m['url'] ?? ''}',
    nhanVai: '${m['nhan_vai'] ?? ''}',
    nguoiTai: m['nguoi_tai'] as String?,
    luc: DateTime.tryParse('${m['luc'] ?? ''}'),
    xoaDuoc: m['xoa_duoc'] == true,
  );
}

class GiayToHopDong {
  const GiayToHopDong({
    required this.contractId,
    required this.vai,
    required this.hopDong,
    required this.minhChungCoc,
    required this.thieu,
  });

  final int contractId;

  /// Vai của người đang xem: chu_nha · khach · sale · admin.
  final String vai;
  final List<TepGiayTo> hopDong;
  final List<TepGiayTo> minhChungCoc;

  /// Loại còn thiếu ('hop_dong' | 'minh_chung_coc').
  final List<String> thieu;

  List<TepGiayTo> cua(String loai) => loai == kHopDong ? hopDong : minhChungCoc;

  factory GiayToHopDong.fromMap(Map<String, dynamic> m) {
    List<TepGiayTo> ds(Object? v) => [
      for (final x in (v as List? ?? const []))
        if (x is Map) TepGiayTo.fromMap(Map<String, dynamic>.from(x)),
    ];
    return GiayToHopDong(
      contractId: (m['contract_id'] as num?)?.toInt() ?? 0,
      vai: '${m['vai'] ?? ''}',
      hopDong: ds(m['hop_dong']),
      minhChungCoc: ds(m['minh_chung_coc']),
      thieu: [for (final x in (m['thieu'] as List? ?? const [])) '$x'],
    );
  }
}
