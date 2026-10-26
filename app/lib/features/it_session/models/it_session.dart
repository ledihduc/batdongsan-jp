/// IT重説 (IT-mediated explanation) session model.
///
/// Maps to the it_sessions table/endpoint.
library;

class ItSession {
  const ItSession({
    required this.id,
    required this.viewingId,
    required this.takkenShiName,
    required this.takkenShiLicenseNumber,
    this.takkenShiPhotoUrl,
    required this.zoomUrl,
    this.scheduledAt,
    this.status,
  });

  final int id;
  final int viewingId;

  /// 宅建士の氏名.
  final String takkenShiName;

  /// 宅建士証番号.
  final String takkenShiLicenseNumber;

  /// Optional profile photo URL.
  final String? takkenShiPhotoUrl;

  /// Zoom meeting URL.
  final String zoomUrl;

  final String? scheduledAt;

  /// 'scheduled' | 'in_progress' | 'completed' | 'cancelled'.
  final String? status;

  factory ItSession.fromJson(Map<String, dynamic> json) {
    return ItSession(
      id: json['id'] as int,
      viewingId: json['viewing_id'] as int,
      takkenShiName: json['takken_shi_name'] as String? ?? '',
      takkenShiLicenseNumber:
          json['takken_shi_license_number'] as String? ?? '',
      takkenShiPhotoUrl: json['takken_shi_photo_url'] as String?,
      zoomUrl: json['zoom_url'] as String? ?? '',
      scheduledAt: json['scheduled_at'] as String?,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'viewing_id': viewingId,
        'takken_shi_name': takkenShiName,
        'takken_shi_license_number': takkenShiLicenseNumber,
        if (takkenShiPhotoUrl != null)
          'takken_shi_photo_url': takkenShiPhotoUrl,
        'zoom_url': zoomUrl,
        if (scheduledAt != null) 'scheduled_at': scheduledAt,
        if (status != null) 'status': status,
      };
}
