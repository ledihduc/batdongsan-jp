/// Model cho báo cáo lỗi dữ liệu thửa đất — body của
/// `POST /api/planning/report-error`.
class ParcelReport {
  final String parcelId;
  final String reason;

  /// URL ảnh minh chứng (tùy chọn).
  final String? imageUrl;

  const ParcelReport({
    required this.parcelId,
    required this.reason,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
    'parcel_id': parcelId,
    'reason': reason,
    if (imageUrl != null) 'image_url': imageUrl,
  };

  factory ParcelReport.fromJson(Map<String, dynamic> j) => ParcelReport(
    parcelId: j['parcel_id'] as String,
    reason: j['reason'] as String,
    imageUrl: j['image_url'] as String?,
  );
}
