/// BuildingModel — mirrors BuildingResponse schema from backend.
class BuildingModel {
  final int id;
  final int hostId;
  final int? saleId;
  final String name;
  final String address;
  final String city;
  final String district;
  final String ward;
  final String? note;

  /// Mã bàn giao cho chủ nhà (migration 0083). null khi toà đã có chủ nhận —
  /// mã dùng một lần rồi xoá, nên null cũng có nghĩa là "đã bàn giao xong".
  final String? claimCode;

  /// Giá tiện ích MẶC ĐỊNH cho mọi phòng của toà chưa khai riêng.
  /// `null` = chưa đặt → phòng rơi về hằng số của hệ thống (3.500đ · 15.000đ).
  final double? giaDien;
  final double? giaNuoc;
  final double? phiDichVu;
  final DateTime? claimedAt;

  /// Số liệu tóm tắt — chỉ có ở endpoint danh sách; tạo/sửa trả về 0.
  final int soPhong;
  final int soPhongTrong;

  /// Ảnh phòng đầu tiên, dùng làm bìa thẻ. null → vẽ nền màu thay ảnh.
  final String? anhBia;

  final DateTime createdAt;
  final DateTime updatedAt;

  const BuildingModel({
    required this.id,
    required this.hostId,
    required this.name,
    required this.address,
    required this.city,
    required this.district,
    required this.ward,
    this.note,
    this.saleId,
    this.claimCode,
    this.giaDien,
    this.giaNuoc,
    this.phiDichVu,
    this.claimedAt,
    this.soPhong = 0,
    this.soPhongTrong = 0,
    this.anhBia,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BuildingModel.fromJson(Map<String, dynamic> json) {
    return BuildingModel(
      id: json['id'] as int,
      hostId: json['host_id'] as int,
      saleId: (json['sale_id'] as num?)?.toInt(),
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      district: json['district'] as String? ?? '',
      ward: json['ward'] as String? ?? '',
      note: json['note'] as String?,
      claimCode: json['claim_code'] as String?,
      giaDien: (json['gia_dien'] as num?)?.toDouble(),
      giaNuoc: (json['gia_nuoc'] as num?)?.toDouble(),
      phiDichVu: (json['phi_dich_vu'] as num?)?.toDouble(),
      claimedAt: json['claimed_at'] == null
          ? null
          : DateTime.tryParse(json['claimed_at'] as String),
      soPhong: (json['so_phong'] as num?)?.toInt() ?? 0,
      soPhongTrong: (json['so_phong_trong'] as num?)?.toInt() ?? 0,
      anhBia: json['anh_bia'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'host_id': hostId,
    'sale_id': saleId,
    'name': name,
    'address': address,
    'city': city,
    'district': district,
    'ward': ward,
    'note': note,
    'claim_code': claimCode,
    'claimed_at': claimedAt?.toIso8601String(),
    'so_phong': soPhong,
    'so_phong_trong': soPhongTrong,
    'anh_bia': anhBia,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
