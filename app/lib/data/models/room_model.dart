List<String> _chuoi(dynamic raw) =>
    (raw as List?)?.whereType<String>().toList() ?? const [];

/// RoomModel — mirrors RoomResponse schema from backend.
///
/// Status values: 'vacant' | 'occupied' | 'maintenance'
class RoomModel {
  final int id;
  final int buildingId;
  final String code;
  final double? areaM2;
  final int capacity;
  final double basePrice;
  final String status;
  final String? maintenanceStart;
  final String? maintenanceEnd;
  final List<String> images;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? ownerId;
  final int? managedBySaleId;

  /// Giá tiện ích RIÊNG của phòng. `null` = chưa khai, lấy theo toà.
  ///
  /// `null` KHÁC `0`: `0` là miễn phí (nhà trọ bao nước). Ô nhập phải để trống
  /// khi `null` và điền `0` khi bằng 0 — gộp hai thứ là mất hẳn khả năng khai
  /// "phòng này bao nước".
  final double? giaDien;
  final double? giaNuoc;
  final double? phiDichVu;

  /// Giá ĐÃ GIẢI QUYẾT (phòng → toà → hằng số), backend tính sẵn. Đây là số
  /// để HIỂN THỊ; đừng tự suy lại thứ tự ưu tiên ở app.
  final double giaDienHieuLuc;
  final double giaNuocHieuLuc;
  final double phiDichVuHieuLuc;

  /// Key (không phải nhãn) — nhãn tra ở `data/services/tien_ich_phong.dart`.
  final List<String> dichVuGom;
  final List<String> doTrongPhong;

  /// SỔ PHÒNG — chỉ `GET /buildings/{id}/rooms` điền (backend
  /// `services/so_phong.py`, cùng luật "đang thuê" với Trang chủ chủ nhà).
  ///
  /// 'dang_o' | 'sap_tra' | 'trong' | 'bao_tri'. `null` = server bản cũ chưa
  /// trả → dùng [tinhTrangHien], suy tạm từ [status].
  final String? tinhTrang;

  /// Nhãn chip lọc: 'ngan_han' | 'dai_han' | 'kinh_doanh' | 'khach_san'.
  final List<String> loai;

  /// Giá + đơn vị của kênh phòng đang chạy ('thang' | 'dem' | 'm2_thang').
  /// `null` = phòng chưa bật kênh nào → hiện [basePrice] theo tháng.
  final double? giaKenh;
  final String? donVi;

  /// Chỉ chủ phòng / admin nhận được — sale phụ trách nhận `null`.
  final String? khachThue;

  /// `YYYY-MM-DD`.
  final String? hopDongTu;

  /// `YYYY-MM-DD`.
  final String? hopDongDen;

  /// Dòng tiền tháng: chữ đọc cho người ("Đóng tiền 05/10 · còn 12 ngày"),
  /// mức màu ('xam' | 'cam' | 'do') và NGÀY phải thu tiếp theo để xếp lịch.
  final String? dongTien;
  final String? dongTienMuc;
  final String? dongTienNgay;

  /// Giờ trả phòng của khách lưu trú ngắn hạn đang ở.
  final DateTime? traPhongLuc;

  /// Hồ sơ phòng (migration 0107). `tang` là chữ ("Trệt", "Lửng").
  final String? tang;

  /// Slug 8 hướng, chung bộ với hướng nhà của tin đăng — nhãn ở [nhanHuong].
  final String? huong;

  /// "Studio 1PN" — nhãn loại phòng khai ở kênh phòng đang chạy.
  final String? loaiPhong;

  /// Có = phòng đã lên chợ, chia sẻ được link tin.
  final int? marketplaceHouseId;

  static const nhanHuong = {
    'north': 'Bắc',
    'northeast': 'Đông Bắc',
    'east': 'Đông',
    'southeast': 'Đông Nam',
    'south': 'Nam',
    'southwest': 'Tây Nam',
    'west': 'Tây',
    'northwest': 'Tây Bắc',
  };

  const RoomModel({
    required this.id,
    required this.buildingId,
    required this.code,
    this.areaM2,
    required this.capacity,
    required this.basePrice,
    required this.status,
    this.maintenanceStart,
    this.maintenanceEnd,
    required this.images,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.ownerId,
    this.managedBySaleId,
    this.giaDien,
    this.giaNuoc,
    this.phiDichVu,
    this.giaDienHieuLuc = 3500,
    this.giaNuocHieuLuc = 15000,
    this.phiDichVuHieuLuc = 0,
    this.dichVuGom = const [],
    this.doTrongPhong = const [],
    this.tinhTrang,
    this.loai = const [],
    this.giaKenh,
    this.donVi,
    this.khachThue,
    this.hopDongTu,
    this.hopDongDen,
    this.dongTien,
    this.dongTienMuc,
    this.dongTienNgay,
    this.traPhongLuc,
    this.tang,
    this.huong,
    this.loaiPhong,
    this.marketplaceHouseId,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'] as int,
      buildingId: json['building_id'] as int,
      code: json['code'] as String,
      areaM2: (json['area_m2'] as num?)?.toDouble(),
      capacity: json['capacity'] as int? ?? 1,
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'vacant',
      maintenanceStart: json['maintenance_start'] as String?,
      maintenanceEnd: json['maintenance_end'] as String?,
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      ownerId: (json['owner_id'] as num?)?.toInt(),
      managedBySaleId: (json['managed_by_sale_id'] as num?)?.toInt(),
      giaDien: (json['gia_dien'] as num?)?.toDouble(),
      giaNuoc: (json['gia_nuoc'] as num?)?.toDouble(),
      phiDichVu: (json['phi_dich_vu'] as num?)?.toDouble(),
      giaDienHieuLuc: (json['gia_dien_hieu_luc'] as num?)?.toDouble() ?? 3500,
      giaNuocHieuLuc: (json['gia_nuoc_hieu_luc'] as num?)?.toDouble() ?? 15000,
      phiDichVuHieuLuc: (json['phi_dich_vu_hieu_luc'] as num?)?.toDouble() ?? 0,
      dichVuGom: _chuoi(json['dich_vu_gom']),
      doTrongPhong: _chuoi(json['do_trong_phong']),
      tinhTrang: json['tinh_trang'] as String?,
      loai: _chuoi(json['loai']),
      giaKenh: (json['gia_kenh'] as num?)?.toDouble(),
      donVi: json['don_vi'] as String?,
      khachThue: json['khach_thue'] as String?,
      hopDongTu: json['hop_dong_tu'] as String?,
      hopDongDen: json['hop_dong_den'] as String?,
      dongTien: json['dong_tien'] as String?,
      dongTienMuc: json['dong_tien_muc'] as String?,
      dongTienNgay: json['dong_tien_ngay'] as String?,
      traPhongLuc: DateTime.tryParse(json['tra_phong_luc'] as String? ?? ''),
      tang: json['tang'] as String?,
      huong: json['huong'] as String?,
      loaiPhong: json['loai_phong'] as String?,
      marketplaceHouseId: (json['marketplace_house_id'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'building_id': buildingId,
    'code': code,
    'area_m2': areaM2,
    'capacity': capacity,
    'base_price': basePrice,
    'status': status,
    'maintenance_start': maintenanceStart,
    'maintenance_end': maintenanceEnd,
    'images': images,
    'note': note,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  bool get isVacant => status == 'vacant';
  bool get isOccupied => status == 'occupied';
  bool get isMaintenance => status == 'maintenance';

  /// Tình trạng để hiện. Server chưa trả [tinhTrang] (bản cũ) thì suy tạm từ
  /// [status] — không có hạn hợp đồng nên không bao giờ ra 'sap_tra'.
  String get tinhTrangHien =>
      tinhTrang ??
      switch (status) {
        'occupied' => 'dang_o',
        'maintenance' => 'bao_tri',
        _ => 'trong',
      };

  /// Có người ở — "Sắp trả" vẫn là đang thuê.
  bool get dangThue => tinhTrangHien == 'dang_o' || tinhTrangHien == 'sap_tra';
}
