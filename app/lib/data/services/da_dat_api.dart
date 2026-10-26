import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/dat_phong_api.dart' show gioVN;

/// TRANG "ĐÃ ĐẶT" — `GET /api/guest/da-dat` (16/09/2026).
///
/// Server quyết định hết: mục nào "sắp tới" hay "lịch sử", nhãn trạng thái, bước
/// tiến trình, việc cần làm, còn sửa được gì. App chỉ vẽ theo — không tự suy
/// "đơn này còn huỷ được không" từ giờ trên máy khách.
class DaDatApi {
  const DaDatApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<TongHopDaDat> tongHop() async =>
      TongHopDaDat.fromMap(await _c.get('/api/guest/da-dat'));
}

class SuaDuoc {
  const SuaDuoc({this.doiGio = false, this.suaThongTin = false, this.huy = false});

  factory SuaDuoc.fromMap(Map<String, dynamic> m) => SuaDuoc(
    doiGio: m['doi_gio'] as bool? ?? false,
    suaThongTin: m['sua_thong_tin'] as bool? ?? false,
    huy: m['huy'] as bool? ?? false,
  );

  final bool doiGio;
  final bool suaThongTin;
  final bool huy;

  bool get coGi => doiGio || suaThongTin || huy;
}

class MucDaDat {
  const MucDaDat({
    required this.loai,
    required this.id,
    required this.tieuDe,
    this.ma = '',
    this.phuDe = '',
    this.anh,
    this.batDau,
    this.ketThuc,
    this.hinhThuc = '',
    this.tien,
    this.trangThai = '',
    this.nhanTrangThai = '',
    this.tong = 'cho',
    this.buoc = 1,
    this.cacBuoc = const [],
    this.viec = '',
    this.canXuLy,
    this.dangMo = true,
    this.suaDuoc = const SuaDuoc(),
    this.capNhatLuc,
  });

  factory MucDaDat.fromMap(Map<String, dynamic> m) => MucDaDat(
    loai: m['loai'] as String? ?? '',
    id: (m['id'] as num?)?.toInt() ?? 0,
    ma: m['ma'] as String? ?? '',
    tieuDe: m['tieu_de'] as String? ?? '',
    phuDe: m['phu_de'] as String? ?? '',
    anh: m['anh'] as String?,
    batDau: gioVN(m['bat_dau'] as String?),
    ketThuc: gioVN(m['ket_thuc'] as String?),
    hinhThuc: m['hinh_thuc'] as String? ?? '',
    tien: (m['tien'] as num?)?.toDouble(),
    trangThai: m['trang_thai'] as String? ?? '',
    nhanTrangThai: m['nhan_trang_thai'] as String? ?? '',
    tong: m['tong'] as String? ?? 'cho',
    buoc: (m['buoc'] as num?)?.toInt() ?? 1,
    cacBuoc: [for (final b in (m['cac_buoc'] as List? ?? const [])) '$b'],
    viec: m['viec'] as String? ?? '',
    canXuLy: m['can_xu_ly'] as String?,
    dangMo: m['dang_mo'] as bool? ?? true,
    suaDuoc: SuaDuoc.fromMap(
      (m['sua_duoc'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    capNhatLuc: DateTime.tryParse(m['cap_nhat_luc'] as String? ?? '')?.toLocal(),
  );

  /// dat_phong · xem_nha · hen_chot
  final String loai;
  final int id;
  final String ma;
  final String tieuDe;
  final String phuDe;
  final String? anh;

  /// Giờ tường VN.
  final DateTime? batDau;
  final DateTime? ketThuc;
  final String hinhThuc;
  final double? tien;
  final String trangThai;
  final String nhanTrangThai;

  /// cho · xac_nhan · doi · dang · xong · huy · tu_choi
  final String tong;
  final int buoc;
  final List<String> cacBuoc;
  final String viec;
  final String? canXuLy;
  final bool dangMo;
  final SuaDuoc suaDuoc;
  final DateTime? capNhatLuc;

  bool get laDatPhong => loai == 'dat_phong';
}

class TongHopDaDat {
  const TongHopDaDat({this.sapToi = const [], this.lichSu = const []});

  factory TongHopDaDat.fromMap(Map<String, dynamic> m) => TongHopDaDat(
    sapToi: [
      for (final x in (m['sap_toi'] as List? ?? const []))
        MucDaDat.fromMap((x as Map).cast<String, dynamic>()),
    ],
    lichSu: [
      for (final x in (m['lich_su'] as List? ?? const []))
        MucDaDat.fromMap((x as Map).cast<String, dynamic>()),
    ],
  );

  final List<MucDaDat> sapToi;
  final List<MucDaDat> lichSu;

  List<MucDaDat> get canXuLy => [for (final m in sapToi) if (m.canXuLy != null) m];
}
