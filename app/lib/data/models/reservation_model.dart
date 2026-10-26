/// Phase 07 — Homestay reservation record.
///
/// Mirror backend `app/schemas/reservation.py` ReservationResponse.
/// Status lifecycle:
///   pending → approved → checked_in → checked_out
///                 ↓
///             rejected | cancelled | no_show
library;

class ReservationModel {
  final int id;
  final int
  hostId; // 0 when the API intentionally omits private owner identity.
  final String? bookingMode, bookingCode, checkInAt, checkOutAt, statusLabel;
  final Map<String, dynamic>? priceBreakdown;
  final bool canCancel;
  final int roomId;
  final int? guestUserId;
  final String guestName;
  final String guestPhone;
  final String? guestEmail;
  final String checkInDate; // ISO YYYY-MM-DD inclusive
  final String checkOutDate; // exclusive (= day after last stay)
  final int nights;
  final double totalAmount;
  final double depositPaid;
  final String status;
  final String? cancelPolicySnapshot; // raw JSON string from server
  final DateTime? cancelledAt;
  final double? refundAmount;
  final String? rejectionReason;
  final String source; // marketplace | direct | manual
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Denormalised display fields.
  final String? roomCode;
  final String? buildingName;

  const ReservationModel({
    this.bookingMode,
    this.bookingCode,
    this.checkInAt,
    this.checkOutAt,
    this.statusLabel,
    this.priceBreakdown,
    this.canCancel = false,
    required this.id,
    required this.hostId,
    required this.roomId,
    required this.guestUserId,
    required this.guestName,
    required this.guestPhone,
    required this.guestEmail,
    required this.checkInDate,
    required this.checkOutDate,
    required this.nights,
    required this.totalAmount,
    required this.depositPaid,
    required this.status,
    required this.cancelPolicySnapshot,
    required this.cancelledAt,
    required this.refundAmount,
    required this.rejectionReason,
    required this.source,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.roomCode,
    required this.buildingName,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isCheckedIn => status == 'checked_in';
  bool get isCheckedOut => status == 'checked_out';
  bool get isCancelled => status == 'cancelled';
  bool get isRejected => status == 'rejected';
  bool get isActive =>
      status == 'pending' || status == 'approved' || status == 'checked_in';

  factory ReservationModel.fromJson(Map<String, dynamic> json) =>
      ReservationModel(
        id: json['id'] as int,
        hostId: json['host_id'] as int? ?? 0,
        bookingMode: json['booking_mode'] as String?,
        bookingCode: json['booking_code'] as String?,
        checkInAt: json['check_in_at'] as String?,
        checkOutAt: json['check_out_at'] as String?,
        statusLabel: json['status_label'] as String?,
        canCancel: json['can_cancel'] == true,
        priceBreakdown: (json['price_breakdown'] as Map?)
            ?.cast<String, dynamic>(),
        roomId: json['room_id'] as int,
        guestUserId: json['guest_user_id'] as int?,
        guestName: json['guest_name'] as String,
        guestPhone: json['guest_phone'] as String? ?? '',
        guestEmail: json['guest_email'] as String?,
        checkInDate: json['check_in_date'] as String,
        checkOutDate: json['check_out_date'] as String,
        nights: json['nights'] as int,
        totalAmount: (json['total_amount'] as num).toDouble(),
        depositPaid: (json['deposit_paid'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String,
        cancelPolicySnapshot: json['cancel_policy_snapshot'] as String?,
        cancelledAt: json['cancelled_at'] != null
            ? DateTime.parse(json['cancelled_at'] as String)
            : null,
        refundAmount: (json['refund_amount'] as num?)?.toDouble(),
        rejectionReason: json['rejection_reason'] as String?,
        source: json['source'] as String? ?? 'manual',
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        roomCode: json['room_code'] as String?,
        buildingName: json['building_name'] as String?,
      );
}
