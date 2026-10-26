/// TenantModel — mirrors TenantResponse schema from backend.
///
/// CCCD paths are never returned; only upload booleans.
class TenantModel {
  final int id;
  final int hostId;
  final String fullName;
  final String phone;
  final String? email;
  final String? birthday;
  final String? addressOrigin;
  final bool cccdFrontUploaded;
  final bool cccdBackUploaded;
  final DateTime createdAt;

  // is_primary only populated in contract context (ContractTenantResponse)
  final bool? isPrimary;

  const TenantModel({
    required this.id,
    required this.hostId,
    required this.fullName,
    required this.phone,
    this.email,
    this.birthday,
    this.addressOrigin,
    required this.cccdFrontUploaded,
    required this.cccdBackUploaded,
    required this.createdAt,
    this.isPrimary,
  });

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: json['id'] as int,
      hostId: json['host_id'] as int,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      birthday: json['birthday'] as String?,
      addressOrigin: json['address_origin'] as String?,
      cccdFrontUploaded: json['cccd_front_uploaded'] as bool? ?? false,
      cccdBackUploaded: json['cccd_back_uploaded'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      isPrimary: json['is_primary'] as bool?,
    );
  }
}
