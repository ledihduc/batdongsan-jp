import 'package:house_booking/data/services/api_client.dart';

/// Dự án CÔNG KHAI (`/api/buildings/public`) — dự án + bảng giá từng phòng.
///
/// Mọi lời gọi nuốt lỗi và trả rỗng/null: đây là một dải phụ trên trang cá
/// nhân, hỏng nó không được làm vỡ cả trang.
class BuildingPublicApi {
  const BuildingPublicApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<List<DuAnTomTat>> cuaNguoi(int ownerId) async {
    try {
      final r = await _c.getList(
        '/api/buildings/public',
        queryParameters: {'owner_id': ownerId},
      );
      return r
          .whereType<Map>()
          .map((e) => DuAnTomTat.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<DuAnChiTiet?> chiTiet(int id) async {
    try {
      final r = await _c.get('/api/buildings/$id/public');
      return DuAnChiTiet.fromMap(r);
    } catch (_) {
      return null;
    }
  }
}

class DuAnTomTat {
  const DuAnTomTat({
    required this.id,
    required this.ten,
    required this.diaChi,
    required this.quan,
    required this.tinh,
    required this.soPhong,
    required this.soPhongTrong,
    this.giaTu,
    this.anhBia,
    this.anh = const [],
  });

  final int id;
  final String ten;
  final String diaChi;
  final String quan;
  final String tinh;
  final int soPhong;
  final int soPhongTrong;

  /// Giá thấp nhất trong các phòng CÒN TRỐNG. null = không phòng nào có giá.
  final double? giaTu;
  final String? anhBia;

  /// Ảnh nền thẻ dự án, gom từ ảnh các TIN đã gắn. Nhiều ảnh thì thẻ kéo
  /// trượt được. Rỗng = chưa gắn tin nào có ảnh.
  final List<String> anh;

  String get diaChiDay =>
      [diaChi, quan, tinh].where((s) => s.isNotEmpty).join(' · ');

  factory DuAnTomTat.fromMap(Map<String, dynamic> m) => DuAnTomTat(
    id: (m['id'] as num).toInt(),
    ten: m['ten'] as String? ?? '',
    diaChi: m['dia_chi'] as String? ?? '',
    quan: m['quan'] as String? ?? '',
    tinh: m['tinh'] as String? ?? '',
    soPhong: (m['so_phong'] as num?)?.toInt() ?? 0,
    soPhongTrong: (m['so_phong_trong'] as num?)?.toInt() ?? 0,
    giaTu: (m['gia_tu'] as num?)?.toDouble(),
    anhBia: m['anh_bia'] as String?,
    anh: (m['anh'] as List? ?? const [])
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toList(),
  );
}

class DuAnChiTiet extends DuAnTomTat {
  const DuAnChiTiet({
    required super.id,
    required super.ten,
    required super.diaChi,
    required super.quan,
    required super.tinh,
    required super.soPhong,
    required super.soPhongTrong,
    this.saleId,
    this.saleTen,
    required this.phong,
    super.giaTu,
    super.anhBia,
    super.anh,
    this.ghiChu,
    this.toiDungTen = false,
    this.daBanGiao,
    this.toiQuanLy = false,
  });

  /// SALE PHỤ TRÁCH — mặt tiền công khai của dự án.
  ///
  /// Cố ý KHÔNG phải chủ nhà. Sale bỏ công tìm ra chủ nhà nên quan hệ đó là thứ
  /// họ sở hữu; khách chỉ được liên hệ qua sale. Trước 08/09/2026 hai trường
  /// này tên `chuId`/`chuTen` và nhận `Building.host_id` — sau khi bàn giao toà
  /// thì đó là CHỦ NHÀ, và app dựng nút "Nhắn cho <chủ nhà>" trỏ vào hồ sơ họ.
  ///
  /// null = toà đã bàn giao mà chủ nhà chưa liên kết sale nào → ẩn khối liên hệ,
  /// KHÔNG rơi về chủ nhà.
  final int? saleId;
  final String? saleTen;
  final String? ghiChu;
  final List<PhongCongKhai> phong;

  /// Tôi có phải người ĐANG ĐỨNG TÊN toà không (backend tự đối chiếu token).
  ///
  /// Chỉ nói về chính người hỏi: `false` cho khách vãng lai, và cả cho sale
  /// phụ trách sau khi đã bàn giao. Đây là điều kiện DUY NHẤT được phép dùng
  /// để vẽ nút "Mã bàn giao" — endpoint lấy mã gác theo `host_id`, nên suy từ
  /// "tôi phụ trách mọi phòng" là vẽ ra một nút chỉ để bấm vào rồi báo lỗi.
  final bool toiDungTen;

  /// Toà đã có chủ nhận. `null` với người ngoài cuộc.
  final bool? daBanGiao;

  /// Tôi mở được SỔ PHÒNG của toà này không (chủ · sale phụ trách · sale giữ
  /// một phòng). Backend tính bằng đúng điều kiện mà API danh sách phòng dùng
  /// để gác, nên nút mở sổ không bao giờ dẫn tới 404.
  final bool toiQuanLy;

  factory DuAnChiTiet.fromMap(Map<String, dynamic> m) {
    final tt = DuAnTomTat.fromMap(m);
    return DuAnChiTiet(
      id: tt.id,
      ten: tt.ten,
      diaChi: tt.diaChi,
      quan: tt.quan,
      tinh: tt.tinh,
      soPhong: tt.soPhong,
      soPhongTrong: tt.soPhongTrong,
      giaTu: tt.giaTu,
      anhBia: tt.anhBia,
      anh: tt.anh,
      saleId: (m['sale_id'] as num?)?.toInt(),
      saleTen: m['sale_ten'] as String?,
      ghiChu: m['ghi_chu'] as String?,
      toiDungTen: m['toi_dung_ten'] == true,
      daBanGiao: m['da_ban_giao'] as bool?,
      toiQuanLy: m['toi_quan_ly'] == true,
      phong: (m['phong'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => PhongCongKhai.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// Một KÊNH BÁN của phòng: bán thế nào, giá bao nhiêu, **đơn vị gì**.
///
/// `donVi` là trường quan trọng nhất. Thiếu nó, app lấy giá THÁNG nhân với số
/// ĐÊM — lỗi tính tiền đã xảy ra thật (5,5tr/tháng × 3 đêm = 16,5tr).
class KenhBan {
  const KenhBan({
    required this.kenh,
    required this.gia,
    required this.donVi,
    this.toiThieu,
    this.products = const [],
  });

  /// 'ngan_han' | 'dai_han' | 'ban'
  final String kenh;
  final double gia;

  /// 'dem' | 'thang' | 'm2_thang' | 'tong'
  final String donVi;
  final int? toiThieu;
  final List<Map<String, dynamic>> products;

  bool get laNganHan => kenh == 'ngan_han';
  bool get laBan => kenh == 'ban';

  /// Hậu tố hiển thị sau giá. Bán thì KHÔNG có hậu tố — "3 tỷ/tổng" vô nghĩa.
  String get hauTo => switch (donVi) {
    'dem' => '/đêm',
    'thang' => '/tháng',
    'm2_thang' => '/m²/tháng',
    _ => '',
  };

  String get nhan => switch (kenh) {
    'ngan_han' => 'Ở ngắn hạn',
    'ban' => 'Bán',
    _ => 'Thuê dài hạn',
  };

  factory KenhBan.fromMap(Map<String, dynamic> m) => KenhBan(
    kenh: m['kenh'] as String? ?? 'dai_han',
    gia: (m['gia'] as num?)?.toDouble() ?? 0,
    donVi: m['don_vi'] as String? ?? 'thang',
    toiThieu: (m['toi_thieu'] as num?)?.toInt(),
    products: (m['products'] as List? ?? [])
        .map((p) => Map<String, dynamic>.from(p))
        .toList(),
  );
}

class PhongCongKhai {
  const PhongCongKhai({
    required this.id,
    required this.ma,
    required this.gia,
    required this.sucChua,
    required this.conTrong,
    this.dienTich,
    this.anh = const [],
    this.kenh = const [],
    this.saleId,
    this.saleTen,
  });

  final int id;
  final String ma;
  final double gia;
  final double? dienTich;
  final int sucChua;
  final bool conTrong;
  final List<String> anh;

  /// Các kênh đang bật. **Rỗng = phòng chưa rao bán kiểu nào** → không được mở
  /// luồng đặt nào cả.
  final List<KenhBan> kenh;
  final int? saleId;
  final String? saleTen;

  /// Kênh đặt-theo-đêm, nếu có. Chỉ kênh này mới mở màn chọn ngày.
  KenhBan? get kenhNganHan => kenh.where((k) => k.laNganHan).firstOrNull;

  factory PhongCongKhai.fromMap(Map<String, dynamic> m) => PhongCongKhai(
    id: (m['id'] as num).toInt(),
    ma: m['ma'] as String? ?? '',
    gia: (m['gia'] as num?)?.toDouble() ?? 0,
    dienTich: (m['dien_tich'] as num?)?.toDouble(),
    sucChua: (m['suc_chua'] as num?)?.toInt() ?? 1,
    conTrong: m['con_trong'] == true,
    anh: (m['anh'] as List? ?? const []).whereType<String>().toList(),
    kenh: (m['kenh'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => KenhBan.fromMap(Map<String, dynamic>.from(e)))
        .toList(),
    saleId: (m['sale_id'] as num?)?.toInt(),
    saleTen: m['sale_ten'] as String?,
  );
}
