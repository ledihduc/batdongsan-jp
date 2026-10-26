/// Một dòng trong LỊCH SỬ đơn đặt phòng / lịch hẹn — server đã dịch sẵn câu chữ
/// (`services/lich_su_dat.py`) để khách, sale, chủ nhà đọc cùng một phiên bản.
class SuKienLichSu {
  const SuKienLichSu({
    required this.tieuDe,
    this.luc,
    this.hanhDong = '',
    this.chiTiet = '',
    this.tong = 'doi',
    this.ai = const NguoiLam(),
  });

  factory SuKienLichSu.fromMap(Map<String, dynamic> m) => SuKienLichSu(
    luc: DateTime.tryParse(m['luc'] as String? ?? '')?.toLocal(),
    hanhDong: m['hanh_dong'] as String? ?? '',
    tieuDe: m['tieu_de'] as String? ?? '',
    chiTiet: m['chi_tiet'] as String? ?? '',
    tong: m['tong'] as String? ?? 'doi',
    ai: NguoiLam.fromMap((m['ai'] as Map?)?.cast<String, dynamic>() ?? const {}),
  );

  final DateTime? luc;
  final String hanhDong;
  final String tieuDe;
  final String chiTiet;

  /// dat · cho · xac_nhan · doi · tu_choi · huy · xong
  final String tong;
  final NguoiLam ai;
}

class NguoiLam {
  const NguoiLam({this.vai = 'he_thong', this.ten = 'Hệ thống', this.laBan = false});

  factory NguoiLam.fromMap(Map<String, dynamic> m) => NguoiLam(
    vai: m['vai'] as String? ?? 'he_thong',
    ten: m['ten'] as String? ?? '',
    laBan: m['la_ban'] as bool? ?? false,
  );

  /// khach · sale · chu_nha · quan_tri · he_thong · khac
  final String vai;

  /// "Bạn" / "Sale Hoàng Minh Tuấn" / "Chủ nhà" / "Hệ thống"
  final String ten;
  final bool laBan;
}

List<SuKienLichSu> suKienTuList(List<dynamic> ds) => [
  for (final x in ds)
    if (x is Map) SuKienLichSu.fromMap(x.cast<String, dynamic>()),
];
