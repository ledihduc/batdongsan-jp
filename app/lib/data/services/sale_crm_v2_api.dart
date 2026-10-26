import 'dart:math';

import 'package:house_booking/data/services/api_client.dart';

class SaleCrmV2Api {
  const SaleCrmV2Api({ApiClient client = const ApiClient()}) : _client = client;

  final ApiClient _client;

  Future<SaleCrmDashboard> dashboard() async =>
      SaleCrmDashboard.fromMap(await _client.get('/api/v2/sale-crm/dashboard'));

  Future<List<SaleCrmContact>> contacts({String? type}) async {
    final data = await _client.get(
      '/api/v2/sale-crm/contacts',
      queryParameters: {if (type != null) 'contact_type': type},
    );
    return [
      for (final item in data['items'] as List? ?? const [])
        SaleCrmContact.fromMap((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<List<SaleCrmTask>> tasks({String? status}) async {
    final data = await _client.get(
      '/api/v2/sale-crm/tasks',
      queryParameters: {if (status != null) 'status': status},
    );
    return [
      for (final item in data['items'] as List? ?? const [])
        SaleCrmTask.fromMap((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<List<SaleCrmProperty>> properties() async {
    final data = await _client.get('/api/v2/sale-crm/properties');
    return [
      for (final item in data['items'] as List? ?? const [])
        SaleCrmProperty.fromMap((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<List<SaleCrmDeal>> deals() async {
    final data = await _client.get('/api/v2/sale-crm/deals');
    return [
      for (final item in data['items'] as List? ?? const [])
        SaleCrmDeal.fromMap((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<List<SaleStaySupport>> staySupport() async {
    final data = await _client.get('/api/v2/sale-crm/stay-support');
    return [
      for (final item in data['items'] as List? ?? const [])
        SaleStaySupport.fromMap((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<SaleCrmTask> createTask({
    required String title,
    required DateTime dueAt,
    required String deepLink,
    int? contactId,
    int? rentalJourneyId,
    String? description,
  }) async => SaleCrmTask.fromMap(
    await _client.post(
      '/api/v2/sale-crm/tasks',
      body: {
        'title': title,
        'due_at': dueAt.toIso8601String(),
        'deep_link': deepLink,
        if (contactId != null) 'contact_id': contactId,
        if (rentalJourneyId != null) 'rental_journey_id': rentalJourneyId,
        if (description != null) 'description': description,
      },
      extraHeaders: {'Idempotency-Key': _key('task')},
    ),
  );

  Future<SaleCrmTask> updateTask(int id, String status) async =>
      SaleCrmTask.fromMap(
        await _client.patch(
          '/api/v2/sale-crm/tasks/$id',
          body: {'status': status},
          extraHeaders: {'Idempotency-Key': _key('task-$id-$status')},
        ),
      );

  Future<void> addPrivateNote(int contactId, String body) async {
    await _client.post(
      '/api/v2/sale-crm/contacts/$contactId/notes',
      body: {'body': body},
      extraHeaders: {'Idempotency-Key': _key('note-$contactId')},
    );
  }

  Future<SaleCrmDeal> updateDealStage(
    int id,
    String stage, {
    String? lossReasonCode,
  }) async => SaleCrmDeal.fromMap(
    await _client.patch(
      '/api/v2/sale-crm/deals/$id/stage',
      body: {
        'stage': stage,
        if (lossReasonCode != null) 'loss_reason_code': lossReasonCode,
      },
      extraHeaders: {'Idempotency-Key': _key('deal-$id-$stage')},
    ),
  );

  String _key(String action) =>
      'sale-crm-$action-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}';
}

class SaleCrmDashboard {
  const SaleCrmDashboard({
    required this.contacts,
    required this.openTasks,
    required this.overdueTasks,
    required this.activeDeals,
    required this.propertyCount,
  });

  factory SaleCrmDashboard.fromMap(Map<String, dynamic> map) =>
      SaleCrmDashboard(
        contacts: (map['contacts'] as num?)?.toInt() ?? 0,
        openTasks: (map['open_tasks'] as num?)?.toInt() ?? 0,
        overdueTasks: (map['overdue_tasks'] as num?)?.toInt() ?? 0,
        activeDeals: (map['active_deals'] as num?)?.toInt() ?? 0,
        propertyCount: (map['property_count'] as num?)?.toInt() ?? 0,
      );

  final int contacts;
  final int openTasks;
  final int overdueTasks;
  final int activeDeals;
  final int propertyCount;
}

class SaleCrmContact {
  const SaleCrmContact({
    required this.id,
    required this.type,
    required this.name,
    required this.phone,
    required this.email,
    required this.openTasks,
    required this.deepLink,
  });

  factory SaleCrmContact.fromMap(Map<String, dynamic> map) {
    final user = (map['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    return SaleCrmContact(
      id: (map['id'] as num?)?.toInt() ?? 0,
      type: map['type'] as String? ?? 'CUSTOMER',
      name: user['name'] as String? ?? 'Chưa rõ tên',
      phone: user['phone'] as String? ?? '',
      email: user['email'] as String? ?? '',
      openTasks: (map['open_tasks'] as num?)?.toInt() ?? 0,
      deepLink: map['deep_link'] as String? ?? '',
    );
  }

  final int id;
  final String type;
  final String name;
  final String phone;
  final String email;
  final int openTasks;
  final String deepLink;
}

class SaleCrmTask {
  const SaleCrmTask({
    required this.id,
    required this.title,
    required this.dueAt,
    required this.status,
    required this.deepLink,
    this.contactId,
  });

  factory SaleCrmTask.fromMap(Map<String, dynamic> map) => SaleCrmTask(
    id: (map['id'] as num?)?.toInt() ?? 0,
    title: map['title'] as String? ?? '',
    dueAt: DateTime.tryParse(map['due_at'] as String? ?? '') ?? DateTime(2000),
    status: map['status'] as String? ?? 'OPEN',
    deepLink: map['deep_link'] as String? ?? '',
    contactId: (map['contact_id'] as num?)?.toInt(),
  );

  final int id;
  final String title;
  final DateTime dueAt;
  final String status;
  final String deepLink;
  final int? contactId;
}

class SaleCrmProperty {
  const SaleCrmProperty({
    required this.id,
    required this.name,
    required this.address,
    required this.roomCount,
    required this.occupiedCount,
    required this.listedCount,
  });

  factory SaleCrmProperty.fromMap(Map<String, dynamic> map) => SaleCrmProperty(
    id: (map['id'] as num?)?.toInt() ?? 0,
    name: map['name'] as String? ?? '',
    address: map['address'] as String? ?? '',
    roomCount: (map['room_count'] as num?)?.toInt() ?? 0,
    occupiedCount: (map['occupied_count'] as num?)?.toInt() ?? 0,
    listedCount: (map['listed_count'] as num?)?.toInt() ?? 0,
  );

  final int id;
  final String name;
  final String address;
  final int roomCount;
  final int occupiedCount;
  final int listedCount;
}

class SaleCrmDeal {
  const SaleCrmDeal({
    required this.id,
    required this.amount,
    required this.transactionStatus,
    required this.pipelineStage,
    required this.customerId,
  });

  factory SaleCrmDeal.fromMap(Map<String, dynamic> map) => SaleCrmDeal(
    id: (map['id'] as num?)?.toInt() ?? 0,
    amount: (map['amount'] as num?)?.toInt() ?? 0,
    transactionStatus: map['transaction_status'] as String? ?? '',
    pipelineStage: map['pipeline_stage'] as String? ?? 'FOLLOW_UP',
    customerId: (map['customer_id'] as num?)?.toInt() ?? 0,
  );

  final int id;
  final int amount;
  final String transactionStatus;
  final String pipelineStage;
  final int customerId;
}

class SaleStaySupport {
  const SaleStaySupport({
    required this.journeyId,
    required this.status,
    required this.roomId,
    required this.allowedActions,
  });

  factory SaleStaySupport.fromMap(Map<String, dynamic> map) => SaleStaySupport(
    journeyId: (map['journey_id'] as num?)?.toInt() ?? 0,
    status: map['status'] as String? ?? '',
    roomId: (map['room_id'] as num?)?.toInt(),
    allowedActions: [
      for (final value in map['allowed_actions'] as List? ?? const []) '$value',
    ],
  );

  final int journeyId;
  final String status;
  final int? roomId;
  final List<String> allowedActions;
}
