import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/dat_phong_api.dart' show gioVN;

/// TRANG "QUẢN LÝ" — `GET /api/quan-ly?goc=cua_toi|khach_thue` (18/09/2026).
///
/// Server quyết định hết: mục thuộc nhóm nào, nhãn, câu trạng thái, việc nào
/// "chờ bạn xác nhận", mốc nào lên lịch. App chỉ vẽ theo — cùng tinh thần với
/// trang Đã đặt (`DaDatApi`).
class QuanLyApi {
  const QuanLyApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<TongHopQuanLy> tongHop(GocQuanLy goc) async => TongHopQuanLy.fromMap(
    await _c.get('/api/quan-ly', queryParameters: {'goc': goc.ma}),
  );
}

/// Hai góc nhìn của trang: việc CỦA TÔI khi đi đặt / đi thuê, và việc KHÁCH
/// làm trên phòng / tin tôi phụ trách.
enum GocQuanLy {
  cuaToi('cua_toi', 'Của tôi'),
  khachThue('khach_thue', 'Khách thuê');

  const GocQuanLy(this.ma, this.nhan);

  final String ma;
  final String nhan;
}

/// Nhóm của một mục. Khớp khoá `nhom` server trả.
abstract final class NhomQuanLy {
  static const dangDat = 'dang_dat';
  static const daDat = 'da_dat';
  static const dangO = 'dang_o';
  static const lichSu = 'lich_su';
}

class MucQuanLy {
  const MucQuanLy({
    required this.loai,
    required this.id,
    required this.tieuDe,
    this.roomId,
    this.ma = '',
    this.diaChi = '',
    this.anh,
    this.nhom = NhomQuanLy.dangDat,
    this.nhan = '',
    this.tong = 'xam',
    this.dong = '',
    this.canXuLy = false,
    this.nhac = false,
    this.kenh,
    this.khach,
    this.batDau,
    this.ketThuc,
    this.trangThai = '',
    this.saleTen,
    this.saleAnh,
    this.ketQua,
  });

  factory MucQuanLy.fromMap(Map<String, dynamic> m) => MucQuanLy(
    loai: m['loai'] as String? ?? '',
    id: (m['id'] as num?)?.toInt() ?? 0,
    roomId: (m['room_id'] as num?)?.toInt(),
    ma: m['ma'] as String? ?? '',
    tieuDe: m['tieu_de'] as String? ?? '',
    diaChi: m['dia_chi'] as String? ?? '',
    anh: m['anh'] as String?,
    nhom: m['nhom'] as String? ?? NhomQuanLy.dangDat,
    nhan: m['nhan'] as String? ?? '',
    tong: m['tong'] as String? ?? 'xam',
    dong: m['dong'] as String? ?? '',
    canXuLy: m['can_xu_ly'] as bool? ?? false,
    nhac: m['nhac'] as bool? ?? false,
    kenh: m['kenh'] as String?,
    khach: m['khach'] as String?,
    batDau: gioVN(m['bat_dau'] as String?),
    ketThuc: gioVN(m['ket_thuc'] as String?),
    trangThai: m['trang_thai'] as String? ?? '',
    saleTen: (m['sale'] as Map?)?['ten'] as String?,
    saleAnh: (m['sale'] as Map?)?['anh'] as String?,
    ketQua: m['ket_qua'] as String?,
  );

  /// dat_phong · xem_nha · hen_chot · de_nghi_thue · thue_dai_han
  final String loai;

  /// Id của ĐƠN / LỊCH / HỢP ĐỒNG, tuỳ [loai].
  final int id;
  final int? roomId;
  final String ma;
  final String tieuDe;
  final String diaChi;
  final String? anh;
  final String nhom;

  /// Chữ trên huy hiệu góc phải thẻ: "Đang đặt", "Đã đặt", "Đang ở"...
  final String nhan;

  /// Tông màu huy hiệu: do · cam · xanh · lam · xam.
  final String tong;

  /// Câu trạng thái dưới địa chỉ: "Đã đặt lịch xem nhà · 19/09 · 14:00".
  final String dong;
  final bool canXuLy;

  /// Sắp tới hạn (hợp đồng còn ≤30 ngày, ca còn ≤1 tiếng, quá giờ) — tô cam
  /// dòng trạng thái nhưng KHÔNG đếm là "cần xử lý".
  final bool nhac;

  /// Loại thuê: ngan_han · dai_han · mat_bang · ban. `null` = không rõ (lịch
  /// neo thẳng vào phòng) → không vẽ thẻ loại.
  final String? kenh;

  /// Tên khách — chỉ có ở góc "Khách thuê", và chỉ khi màn chi tiết của mục
  /// này cũng cho người đang xem thấy tên (server quyết).
  final String? khach;
  final DateTime? batDau;
  final DateTime? ketThuc;

  /// Trạng thái THÔ của đơn / lịch (pending · approved · completed…).
  final String trangThai;

  /// Sale phụ trách lịch xem — chỉ có ở góc "Của tôi".
  final String? saleTen;
  final String? saleAnh;

  /// Kết quả khách tự ghi sau buổi xem: 'chot' · 'khong_chot' · null.
  final String? ketQua;

  bool get laDatPhong => loai == 'dat_phong';
  bool get laLichHen => loai == 'xem_nha' || loai == 'hen_chot';
  bool get laDeNghiThue => loai == 'de_nghi_thue';
  bool get laThueDaiHan => loai == 'thue_dai_han';
}

/// Một mốc trên "Lịch sắp tới". Trỏ về mục sinh ra nó qua [mucLoai]/[mucId].
class SuKienQuanLy {
  const SuKienQuanLy({
    required this.loai,
    required this.tieuDe,
    required this.noi,
    required this.mucLoai,
    required this.mucId,
    this.batDau,
    this.ketThuc,
    this.coGio = true,
  });

  factory SuKienQuanLy.fromMap(Map<String, dynamic> m) => SuKienQuanLy(
    loai: m['loai'] as String? ?? '',
    tieuDe: m['tieu_de'] as String? ?? '',
    noi: m['noi'] as String? ?? '',
    batDau: gioVN(m['bat_dau'] as String?),
    ketThuc: gioVN(m['ket_thuc'] as String?),
    coGio: m['co_gio'] as bool? ?? true,
    mucLoai: m['muc_loai'] as String? ?? '',
    mucId: (m['muc_id'] as num?)?.toInt() ?? 0,
  );

  /// xem_nha · hen_chot · nhan_phong · tra_phong · vao_o · het_han
  final String loai;
  final String tieuDe;
  final String noi;
  final DateTime? batDau;
  final DateTime? ketThuc;

  /// Mốc hợp đồng chỉ có NGÀY — đừng in "00:00".
  final bool coGio;
  final String mucLoai;
  final int mucId;
}

class DemQuanLy {
  const DemQuanLy({
    this.daDat = 0,
    this.dangDat = 0,
    this.dangO = 0,
    this.sapToi = 0,
    this.lichSu = 0,
    this.canXuLy = 0,
  });

  factory DemQuanLy.fromMap(Map<String, dynamic> m) {
    int so(String k) => (m[k] as num?)?.toInt() ?? 0;
    return DemQuanLy(
      daDat: so('da_dat'),
      dangDat: so('dang_dat'),
      dangO: so('dang_o'),
      sapToi: so('sap_toi'),
      lichSu: so('lich_su'),
      canXuLy: so('can_xu_ly'),
    );
  }

  final int daDat;
  final int dangDat;
  final int dangO;

  /// Số mốc trong 7 ngày tới.
  final int sapToi;
  final int lichSu;
  final int canXuLy;
}

class TongHopQuanLy {
  const TongHopQuanLy({
    this.dem = const DemQuanLy(),
    this.lich = const [],
    this.danhSach = const [],
  });

  factory TongHopQuanLy.fromMap(Map<String, dynamic> m) => TongHopQuanLy(
    dem: DemQuanLy.fromMap(
      (m['dem'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    lich: [
      for (final x in (m['lich'] as List? ?? const []))
        SuKienQuanLy.fromMap((x as Map).cast<String, dynamic>()),
    ],
    danhSach: [
      for (final x in (m['danh_sach'] as List? ?? const []))
        MucQuanLy.fromMap((x as Map).cast<String, dynamic>()),
    ],
  );

  final DemQuanLy dem;
  final List<SuKienQuanLy> lich;
  final List<MucQuanLy> danhSach;

  /// Mục mà một mốc lịch trỏ tới. Null nếu không còn (vd vừa bị huỷ).
  MucQuanLy? mucCua(SuKienQuanLy e) {
    for (final m in danhSach) {
      if (m.loai == e.mucLoai && m.id == e.mucId) return m;
    }
    return null;
  }
}
