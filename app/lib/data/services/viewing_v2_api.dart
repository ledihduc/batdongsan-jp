import 'dart:math';

import 'package:house_booking/data/services/api_client.dart';

enum ViewingMode { customer, sale, owner }

class ViewingV2Api {
  const ViewingV2Api({ApiClient client = const ApiClient()}) : _client = client;

  final ApiClient _client;

  Future<List<CanonicalViewing>> list({
    required ViewingMode mode,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _client.get(
      '/api/v2/viewings',
      queryParameters: {
        'mode': mode.name,
        if (status != null) 'status': status,
        'page': page,
        'page_size': pageSize,
      },
    );
    return [
      for (final item in response['data'] as List? ?? const [])
        CanonicalViewing.fromMap((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<CanonicalViewing> detail(int id) async =>
      CanonicalViewing.fromMap(await _client.get('/api/v2/viewings/$id'));

  Future<List<CanonicalViewingEvent>> timeline(int id) async {
    final response = await _client.get('/api/v2/viewings/$id/timeline');
    return [
      for (final item in response['data'] as List? ?? const [])
        CanonicalViewingEvent.fromMap((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<CanonicalViewing> confirm(int id) => _command(id, 'confirm');

  /// Khách chọn thuê trước giờ xem; lịch vẫn giữ trạng thái đã xác nhận.
  Future<CanonicalViewing> rentNow(int id) => _command(id, 'rent-now');

  Future<CanonicalViewing> acceptProposal(int id, int proposalId) =>
      _command(id, 'accept-proposal/$proposalId');

  Future<CanonicalViewing> propose(
    int id, {
    required String bookingDate,
    required String bookingTime,
    String? note,
  }) => _command(
    id,
    'proposals',
    body: {
      'booking_date': bookingDate,
      'booking_time': bookingTime,
      if (note != null) 'note': note,
    },
  );

  Future<CanonicalViewing> cancel(
    int id, {
    required String reasonCode,
    String? reasonNote,
    List<String> evidenceUrls = const [],
  }) => _command(
    id,
    'cancel',
    body: {
      'reason_code': reasonCode,
      if (reasonNote != null) 'reason_note': reasonNote,
      'evidence_urls': evidenceUrls,
    },
  );

  Future<CanonicalViewing> submitResult(
    int id, {
    required String status,
    String? reasonCode,
    String? reasonNote,
  }) => _command(
    id,
    'result',
    body: {
      'status': status,
      if (reasonCode != null) 'reason_code': reasonCode,
      if (reasonNote != null) 'reason_note': reasonNote,
    },
  );

  Future<CanonicalViewing> reportIssue(
    int id, {
    required String issueCode,
    String? detail,
    List<String> evidenceUrls = const [],
  }) => _command(
    id,
    'issues',
    body: {
      'issue_code': issueCode,
      if (detail != null) 'detail': detail,
      'evidence_urls': evidenceUrls,
    },
  );

  Future<CanonicalViewing> _command(
    int id,
    String action, {
    Map<String, dynamic>? body,
  }) async => CanonicalViewing.fromMap(
    await _client.post(
      '/api/v2/viewings/$id/$action',
      body: body,
      extraHeaders: {'Idempotency-Key': _idempotencyKey(action, id)},
    ),
  );

  String _idempotencyKey(String action, int id) =>
      'viewing-$id-$action-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}';
}

class CanonicalViewing {
  const CanonicalViewing({
    required this.id,
    required this.mode,
    required this.status,
    required this.legacyStatus,
    required this.bookingDate,
    required this.bookingTime,
    required this.resultStatus,
    required this.allowedActions,
    required this.title,
    required this.customerName,
    this.image,
    this.price,
    this.resultReasonCode,
    this.resultReasonNote,
    this.rentalJourneyId,
    this.cancelledByRole,
    this.cancelReasonCode,
    this.cancelReasonNote,
    this.cancelledAt,
    this.proposals = const [],
    this.issues = const [],
  });

  factory CanonicalViewing.fromMap(Map<String, dynamic> map) {
    final subject =
        (map['subject'] as Map?)?.cast<String, dynamic>() ?? const {};
    final participants =
        (map['participants'] as Map?)?.cast<String, dynamic>() ?? const {};
    final customer =
        (participants['customer'] as Map?)?.cast<String, dynamic>() ?? const {};
    final result = (map['result'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cancellation =
        (map['cancellation'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CanonicalViewing(
      id: (map['id'] as num?)?.toInt() ?? 0,
      mode: map['mode'] as String? ?? 'customer',
      status: map['status'] as String? ?? 'FAILED',
      legacyStatus: map['legacy_status'] as String? ?? '',
      bookingDate: map['booking_date'] as String? ?? '',
      bookingTime: map['booking_time'] as String? ?? '',
      resultStatus: result['status'] as String? ?? 'NONE',
      resultReasonCode: result['reason_code'] as String?,
      resultReasonNote: result['reason_note'] as String?,
      rentalJourneyId: (result['rental_journey_id'] as num?)?.toInt(),
      allowedActions: [
        for (final value in map['allowed_actions'] as List? ?? const [])
          '$value',
      ],
      title: subject['title'] as String? ?? 'Căn nhà đang xem',
      image: subject['image'] as String?,
      price: (subject['price'] as num?)?.toInt(),
      customerName: customer['name'] as String? ?? 'Khách thuê',
      cancelledByRole: cancellation['cancelled_by_role'] as String?,
      cancelReasonCode: cancellation['reason_code'] as String?,
      cancelReasonNote: cancellation['reason_note'] as String?,
      cancelledAt: DateTime.tryParse(
        cancellation['cancelled_at'] as String? ?? '',
      ),
      proposals: [
        for (final item in map['proposals'] as List? ?? const [])
          ViewingProposal.fromMap((item as Map).cast<String, dynamic>()),
      ],
      issues: [
        for (final item in map['issues'] as List? ?? const [])
          ViewingIssue.fromMap((item as Map).cast<String, dynamic>()),
      ],
    );
  }

  final int id;
  final String mode;
  final String status;
  final String legacyStatus;
  final String bookingDate;
  final String bookingTime;
  final String resultStatus;
  final String? resultReasonCode;
  final String? resultReasonNote;
  final int? rentalJourneyId;
  final List<String> allowedActions;
  final String title;
  final String? image;
  final int? price;
  final String customerName;
  final String? cancelledByRole;
  final String? cancelReasonCode;
  final String? cancelReasonNote;
  final DateTime? cancelledAt;
  final List<ViewingProposal> proposals;
  final List<ViewingIssue> issues;

  bool can(String action) => allowedActions.contains(action);
}

class ViewingProposal {
  const ViewingProposal({
    required this.id,
    required this.bookingDate,
    required this.bookingTime,
    required this.status,
    required this.proposedByRole,
    this.note,
  });

  factory ViewingProposal.fromMap(Map<String, dynamic> map) => ViewingProposal(
    id: (map['id'] as num?)?.toInt() ?? 0,
    bookingDate: map['booking_date'] as String? ?? '',
    bookingTime: map['booking_time'] as String? ?? '',
    status: map['status'] as String? ?? '',
    proposedByRole: map['proposed_by_role'] as String? ?? '',
    note: map['note'] as String?,
  );

  final int id;
  final String bookingDate;
  final String bookingTime;
  final String status;
  final String proposedByRole;
  final String? note;
}

class ViewingIssue {
  const ViewingIssue({
    required this.code,
    required this.status,
    required this.reporterRole,
  });

  factory ViewingIssue.fromMap(Map<String, dynamic> map) => ViewingIssue(
    code: map['issue_code'] as String? ?? 'OTHER',
    status: map['status'] as String? ?? 'OPEN',
    reporterRole: map['reporter_role'] as String? ?? '',
  );

  final String code;
  final String status;
  final String reporterRole;
}

class CanonicalViewingEvent {
  const CanonicalViewingEvent({
    required this.type,
    required this.actorRole,
    required this.payload,
    this.fromStatus,
    this.toStatus,
    this.occurredAt,
  });

  factory CanonicalViewingEvent.fromMap(Map<String, dynamic> map) =>
      CanonicalViewingEvent(
        type: map['event_type'] as String? ?? '',
        actorRole: map['actor_role'] as String? ?? '',
        fromStatus: map['from_status'] as String?,
        toStatus: map['to_status'] as String?,
        payload: (map['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        occurredAt: DateTime.tryParse(map['occurred_at'] as String? ?? ''),
      );

  final String type;
  final String actorRole;
  final String? fromStatus;
  final String? toStatus;
  final Map<String, dynamic> payload;
  final DateTime? occurredAt;
}
