class ViewingAppointmentModel {
  final int? id;

  /// Tin đăng của lịch hẹn — NULL khi khách đặt xem thẳng một PHÒNG trong dự án
  /// chưa gắn tin nào. Luồng "dựng dự án trước, gắn tin sau" sinh ra đúng loại
  /// phòng đó, nên đây không phải trường hợp hiếm.
  final int? houseId;

  /// Phòng của lịch hẹn. Có cả `houseId` lẫn `roomId` là trường hợp thường gặp
  /// nhất (tin sinh từ phòng).
  final int? roomId;
  final String? kenh;

  /// 'xem' — khách đi xem · 'chot' — hẹn gặp để chốt phòng (R7).
  final String loai;
  final int guestId;
  final String bookingDate; // YYYY-MM-DD
  final String bookingTime; // HH:MM
  final String message;
  final String
  status; // 'pending', 'approved', 'doi_gio', 'rejected', 'completed', 'cancelled'
  final DateTime createdAt;

  // Relations loaded dynamically
  final int? hostId;
  final String? houseTitle;
  final String? houseAddress;
  final String? houseImage;
  final double? housePrice;

  /// 'rent' | 'sale' — để hiển thị giá đúng loại (thuê có /tháng, bán thì không).
  final String houseTransactionType;
  final String? guestName;
  final String? guestPhone;
  // Uy tín khách thuê cho chủ nhà xem khi nhận lịch hẹn (Đợt 3).
  final double? guestRating;
  final int guestCompletedDeals;
  final String? hostName;
  final String? hostPhone;

  /// True khi guest đã viết review cho house. Backend chỉ compute khi
  /// `status == 'completed'` (xem helpers.viewing_appointment_to_dict).
  final bool hasReviewed;

  /// Bên bán bận xin đổi giờ: giờ cũ ('2026-09-16 10:00-11:00') + lý do.
  final String? gioCu;
  final String? lyDoDoi;

  ViewingAppointmentModel({
    this.id,
    this.houseId,
    this.roomId,
    this.kenh,
    this.loai = 'xem',
    required this.guestId,
    required this.bookingDate,
    required this.bookingTime,
    required this.message,
    this.status = 'pending',
    DateTime? createdAt,
    this.hostId,
    this.houseTitle,
    this.houseAddress,
    this.houseImage,
    this.housePrice,
    this.houseTransactionType = 'rent',
    this.guestName,
    this.guestPhone,
    this.guestRating,
    this.guestCompletedDeals = 0,
    this.hostName,
    this.hostPhone,
    this.hasReviewed = false,
    this.gioCu,
    this.lyDoDoi,
  }) : this.createdAt = createdAt ?? DateTime.now();

  /// Lịch này là hẹn gặp để CHỐT phòng, không phải đi xem.
  bool get laHenChot => loai == 'chot';

  /// Bên bán đã báo bận, đang chờ khách chọn giờ mới.
  bool get choKhachChonGio => status == 'doi_gio';

  /// Bên bán còn xin đổi giờ được: lịch chưa diễn ra, chưa đóng.
  bool get doiGioDuoc => status == 'pending' || status == 'approved';

  /// Mở được trang tin không. Lịch neo thẳng vào phòng thì không có tin để mở —
  /// đẩy `/house/null` là ra trang lỗi.
  bool get moDuocTin => houseId != null;

  /// Hậu tố kỳ giá của tin đính kèm: thuê → '/tháng', bán → '' (không có).
  String get housePricePeriodSuffix =>
      houseTransactionType == 'sale' ? '' : '/tháng';

  factory ViewingAppointmentModel.fromMap(Map<String, dynamic> map) {
    return ViewingAppointmentModel(
      id: map['id'],
      houseId: map['house_id'],
      roomId: map['room_id'],
      kenh: map['kenh'] as String?,
      loai: (map['loai'] as String?) ?? 'xem',
      guestId: map['guest_id'],
      bookingDate: map['booking_date'],
      bookingTime: map['booking_time'],
      message: map['message'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: DateTime.parse(map['created_at']),
      hostId: map['host_id'],
      houseTitle: map['house_title'],
      houseAddress: map['house_address'],
      houseImage: map['house_image'],
      housePrice: map['house_price'] != null
          ? (map['house_price'] as num).toDouble()
          : null,
      houseTransactionType:
          (map['house_transaction_type'] as String?) ?? 'rent',
      guestName: map['guest_name'],
      guestPhone: map['guest_phone'],
      guestRating: (map['guest_rating'] as num?)?.toDouble(),
      guestCompletedDeals: (map['guest_completed_deals'] as int?) ?? 0,
      hostName: map['host_name'],
      hostPhone: map['host_phone'],
      hasReviewed: map['has_reviewed'] ?? false,
      gioCu: map['gio_cu'] as String?,
      lyDoDoi: map['ly_do_doi'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (houseId != null) 'house_id': houseId,
      if (roomId != null) 'room_id': roomId,
      if (kenh != null) 'kenh': kenh,
      'loai': loai,
      'guest_id': guestId,
      'booking_date': bookingDate,
      'booking_time': bookingTime,
      'message': message,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
