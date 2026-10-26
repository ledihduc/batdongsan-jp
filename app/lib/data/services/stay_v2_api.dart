import 'dart:math';

import 'package:house_booking/data/services/api_client.dart';

enum StayRole { customer, sale, owner }

extension StayRoleValue on StayRole {
  String get value => name;
}

class StayV2Api {
  const StayV2Api({ApiClient client = const ApiClient()}) : _client = client;
  final ApiClient _client;

  Future<List<StayRecord>> list(StayRole role) async {
    final data = await _client.get('/api/v2/stays', queryParameters: {'mode': role.value});
    return [
      for (final item in data['items'] as List? ?? const [])
        StayRecord.fromMap((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<StayRecord> detail(int contractId, StayRole role) async => StayRecord.fromMap(
    await _client.get('/api/v2/stays/$contractId', queryParameters: {'mode': role.value}),
  );

  Future<List<StayInvoice>> invoices(int contractId, StayRole role) async {
    final data = await _client.get(
      '/api/v2/stays/$contractId/invoices',
      queryParameters: {'mode': role.value},
    );
    return [
      for (final item in data['items'] as List? ?? const [])
        StayInvoice.fromMap((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<List<StaySupportCase>> support(int contractId, StayRole role) async {
    final data = await _client.get(
      '/api/v2/stays/$contractId/support',
      queryParameters: {'mode': role.value},
    );
    return [
      for (final item in data['items'] as List? ?? const [])
        StaySupportCase.fromMap((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<StaySupportCase> createSupport({
    required int contractId,
    required StayRole role,
    required String category,
    required String priority,
    required String title,
    required String description,
    List<String> evidenceUrls = const [],
  }) async => StaySupportCase.fromMap(
    await _client.post(
      '/api/v2/stays/$contractId/support?mode=${role.value}',
      body: {
        'category': category,
        'priority': priority,
        'title': title,
        'description': description,
        'evidence_urls': evidenceUrls,
      },
      extraHeaders: {'Idempotency-Key': _key('support-$contractId')},
    ),
  );

  Future<Map<String, dynamic>> requestChange({
    required int contractId,
    required StayRole role,
    required String type,
    String? proposedEndDate,
    String note = '',
  }) => _client.post(
    '/api/v2/stays/$contractId/change-requests?mode=${role.value}',
    body: {
      'request_type': type,
      if (proposedEndDate != null) 'proposed_end_date': proposedEndDate,
      'note': note,
    },
    extraHeaders: {'Idempotency-Key': _key('change-$contractId-$type')},
  );

  String _key(String action) =>
      'stay-$action-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}';
}

class StayRecord {
  const StayRecord({
    required this.contractId,
    required this.status,
    required this.role,
    required this.roomId,
    required this.roomCode,
    required this.buildingName,
    required this.address,
    required this.images,
    required this.monthlyRent,
    required this.startDate,
    required this.endDate,
    required this.openSupportCount,
    required this.allowedActions,
  });

  factory StayRecord.fromMap(Map<String, dynamic> map) {
    final room = (map['room'] as Map?)?.cast<String, dynamic>() ?? const {};
    final contract = (map['contract'] as Map?)?.cast<String, dynamic>() ?? const {};
    return StayRecord(
      contractId: (map['contract_id'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? '',
      role: map['role_projection'] as String? ?? 'customer',
      roomId: (room['id'] as num?)?.toInt() ?? 0,
      roomCode: room['code'] as String? ?? '',
      buildingName: room['building_name'] as String? ?? '',
      address: room['address'] as String? ?? '',
      images: [for (final value in room['images'] as List? ?? const []) '$value'],
      monthlyRent: (contract['monthly_rent'] as num?)?.toDouble() ?? 0,
      startDate: contract['start_date'] as String? ?? '',
      endDate: contract['end_date'] as String? ?? '',
      openSupportCount: (map['open_support_count'] as num?)?.toInt() ?? 0,
      allowedActions: {for (final value in map['allowed_actions'] as List? ?? const []) '$value'},
    );
  }

  final int contractId;
  final String status;
  final String role;
  final int roomId;
  final String roomCode;
  final String buildingName;
  final String address;
  final List<String> images;
  final double monthlyRent;
  final String startDate;
  final String endDate;
  final int openSupportCount;
  final Set<String> allowedActions;
}

class StayInvoice {
  const StayInvoice({
    required this.id,
    required this.status,
    required this.total,
    required this.paid,
    required this.dueDate,
    required this.immutable,
  });
  factory StayInvoice.fromMap(Map<String, dynamic> map) => StayInvoice(
    id: (map['invoice_id'] as num?)?.toInt() ?? 0,
    status: map['status'] as String? ?? '',
    total: (map['total_amount'] as num?)?.toDouble() ?? 0,
    paid: (map['paid_amount'] as num?)?.toDouble() ?? 0,
    dueDate: map['due_date'] as String? ?? '',
    immutable: map['immutable'] as bool? ?? false,
  );
  final int id;
  final String status;
  final double total;
  final double paid;
  final String dueDate;
  final bool immutable;
}

class StaySupportCase {
  const StaySupportCase({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.slaDueAt,
    required this.slaBreached,
  });
  factory StaySupportCase.fromMap(Map<String, dynamic> map) => StaySupportCase(
    id: (map['id'] as num?)?.toInt() ?? 0,
    title: map['title'] as String? ?? '',
    status: map['status'] as String? ?? 'OPEN',
    priority: map['priority'] as String? ?? 'NORMAL',
    slaDueAt: DateTime.tryParse(map['sla_due_at'] as String? ?? ''),
    slaBreached: map['sla_breached'] as bool? ?? false,
  );
  final int id;
  final String title;
  final String status;
  final String priority;
  final DateTime? slaDueAt;
  final bool slaBreached;
}
