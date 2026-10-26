import 'package:house_booking/data/services/api_client.dart';

/// Contract đọc dữ liệu cho Activity/Management V2.
///
/// Lớp này không thay thế [QuanLyApi] hoặc bất kỳ command lịch xem/hợp đồng
/// hiện hữu nào. Màn hiện tại chỉ có thể chọn dùng dữ liệu này khi backend trả
/// feature flag tương ứng; nhờ vậy app cũ và backend cũ cùng an toàn fallback.
class ManagementReadModelApi {
  const ManagementReadModelApi({ApiClient? client})
    : _client = client ?? const ApiClient();

  final ApiClient _client;

  Future<ManagementCapabilities> capabilities() async =>
      ManagementCapabilities.fromMap(
        await _client.get('/api/v2/me/capabilities'),
      );

  Future<ManagementSummary> summary({required ManagementMode mode}) async =>
      ManagementSummary.fromMap(
        await _client.get(
          '/api/v2/manage/summary',
          queryParameters: {'mode': mode.value},
        ),
      );

  Future<ManagementWorkItems> workItems({
    required ManagementMode mode,
    ManagementBucket? bucket,
    int page = 1,
    int pageSize = 20,
  }) async => ManagementWorkItems.fromMap(
    await _client.get(
      '/api/v2/manage/work-items',
      queryParameters: {
        'mode': mode.value,
        if (bucket != null) 'bucket': bucket.value,
        'page': page,
        'page_size': pageSize,
      },
    ),
  );

  Future<List<ManagementTimelineEvent>> timeline({
    required ManagementMode mode,
    int limit = 30,
  }) async {
    final data = await _client.get(
      '/api/v2/manage/timeline',
      queryParameters: {'mode': mode.value, 'limit': limit},
    );
    return [
      for (final value in (data['data'] as List? ?? const <dynamic>[]))
        ManagementTimelineEvent.fromMap((value as Map).cast<String, dynamic>()),
    ];
  }
}

enum ManagementMode {
  customer('customer'),
  sale('sale'),
  owner('owner');

  const ManagementMode(this.value);
  final String value;

  static ManagementMode fromValue(String value) => switch (value) {
    'sale' => sale,
    'owner' => owner,
    _ => customer,
  };
}

enum ManagementBucket {
  actionRequired('ACTION_REQUIRED'),
  waitingExternal('WAITING_EXTERNAL'),
  upcoming('UPCOMING'),
  afterViewing('AFTER_VIEWING'),
  history('HISTORY');

  const ManagementBucket(this.value);
  final String value;

  static ManagementBucket? fromValue(String? value) {
    for (final bucket in values) {
      if (bucket.value == value) return bucket;
    }
    return null;
  }
}

class ManagementCapabilities {
  const ManagementCapabilities({
    required this.activeMode,
    required this.modes,
    required this.managementV2Enabled,
    required this.managementV2WritesEnabled,
    this.viewingV2Enabled = false,
    this.viewingV2WritesEnabled = false,
    this.saleCrmV2Enabled = false,
    this.saleCrmV2WritesEnabled = false,
    this.stayV2Enabled = false,
    this.stayV2WritesEnabled = false,
    this.moneyLedgerV2Enabled = false,
    this.shortStayInventoryV2Enabled = false,
    this.buySellV2Enabled = false,
  });

  factory ManagementCapabilities.fromMap(Map<String, dynamic> map) {
    final flags =
        (map['feature_flags'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ManagementCapabilities(
      activeMode: map['active_mode'] as String? ?? 'customer',
      modes: [
        for (final value in (map['modes'] as List? ?? const [])) '$value',
      ],
      managementV2Enabled: flags['management_v2_enabled'] as bool? ?? false,
      managementV2WritesEnabled:
          flags['management_v2_writes_enabled'] as bool? ?? false,
      viewingV2Enabled: flags['viewing_v2_enabled'] as bool? ?? false,
      viewingV2WritesEnabled:
          flags['viewing_v2_writes_enabled'] as bool? ?? false,
      saleCrmV2Enabled: flags['sale_crm_v2_enabled'] as bool? ?? false,
      saleCrmV2WritesEnabled:
          flags['sale_crm_v2_writes_enabled'] as bool? ?? false,
      stayV2Enabled: flags['stay_v2_enabled'] as bool? ?? false,
      stayV2WritesEnabled: flags['stay_v2_writes_enabled'] as bool? ?? false,
      moneyLedgerV2Enabled: flags['money_ledger_v2_enabled'] as bool? ?? false,
      shortStayInventoryV2Enabled:
          flags['short_stay_inventory_v2_enabled'] as bool? ?? false,
      buySellV2Enabled: flags['buy_sell_v2_enabled'] as bool? ?? false,
    );
  }

  final String activeMode;
  final List<String> modes;
  final bool managementV2Enabled;
  final bool managementV2WritesEnabled;
  final bool viewingV2Enabled;
  final bool viewingV2WritesEnabled;
  final bool saleCrmV2Enabled;
  final bool saleCrmV2WritesEnabled;
  final bool stayV2Enabled;
  final bool stayV2WritesEnabled;
  final bool moneyLedgerV2Enabled;
  final bool shortStayInventoryV2Enabled;
  final bool buySellV2Enabled;
}

class ManagementSummary {
  const ManagementSummary({
    required this.contractVersion,
    required this.mode,
    required this.counters,
    required this.viewings,
    required this.rentalJourneys,
    required this.reservations,
    required this.contracts,
    required this.invoices,
    this.shortStay = const ShortStayCounters(),
    this.longTerm = const LongTermCounters(),
  });

  factory ManagementSummary.fromMap(Map<String, dynamic> map) {
    final values =
        (map['counters'] as Map?)?.cast<String, dynamic>() ?? const {};
    final totals = (map['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    final shortStay =
        (map['short_stay'] as Map?)?.cast<String, dynamic>() ?? const {};
    final longTerm =
        (map['long_term'] as Map?)?.cast<String, dynamic>() ?? const {};
    int number(Map<String, dynamic> source, String key) =>
        (source[key] as num?)?.toInt() ?? 0;
    return ManagementSummary(
      contractVersion: map['contract_version'] as String? ?? '',
      mode: ManagementMode.fromValue(map['mode'] as String? ?? 'customer'),
      counters: {
        for (final bucket in ManagementBucket.values)
          bucket: number(values, bucket.value),
      },
      viewings: number(totals, 'viewings'),
      rentalJourneys: number(totals, 'rental_journeys'),
      reservations: number(totals, 'reservations'),
      contracts: number(totals, 'contracts'),
      invoices: number(totals, 'invoices'),
      shortStay: ShortStayCounters.fromMap(shortStay),
      longTerm: LongTermCounters.fromMap(longTerm),
    );
  }

  final String contractVersion;
  final ManagementMode mode;
  final Map<ManagementBucket, int> counters;
  final int viewings;
  final int rentalJourneys;
  final int reservations;
  final int contracts;
  final int invoices;
  final ShortStayCounters shortStay;
  final LongTermCounters longTerm;

  int count(ManagementBucket bucket) => counters[bucket] ?? 0;
}

class LongTermCounters {
  const LongTermCounters({this.total = 0, this.counters = const {}});

  factory LongTermCounters.fromMap(Map<String, dynamic> map) {
    final values =
        (map['counters'] as Map?)?.cast<String, dynamic>() ?? const {};
    return LongTermCounters(
      total: (map['total'] as num?)?.toInt() ?? 0,
      counters: {
        for (final bucket in ManagementBucket.values)
          bucket: (values[bucket.value] as num?)?.toInt() ?? 0,
      },
    );
  }

  final int total;
  final Map<ManagementBucket, int> counters;

  int count(ManagementBucket bucket) => counters[bucket] ?? 0;
}

class ShortStayCounters {
  const ShortStayCounters({
    this.total = 0,
    this.pending = 0,
    this.confirmed = 0,
    this.checkedIn = 0,
    this.history = 0,
  });

  factory ShortStayCounters.fromMap(Map<String, dynamic> map) {
    int value(String key) => (map[key] as num?)?.toInt() ?? 0;
    return ShortStayCounters(
      total: value('total'),
      pending: value('pending'),
      confirmed: value('confirmed'),
      checkedIn: value('checked_in'),
      history: value('history'),
    );
  }

  final int total;
  final int pending;
  final int confirmed;
  final int checkedIn;
  final int history;
}

class ManagementWorkItems {
  const ManagementWorkItems({
    required this.items,
    required this.totalItems,
    required this.page,
    required this.totalPages,
  });

  factory ManagementWorkItems.fromMap(Map<String, dynamic> map) {
    final pagination =
        (map['pagination'] as Map?)?.cast<String, dynamic>() ?? const {};
    int number(String key) => (pagination[key] as num?)?.toInt() ?? 0;
    return ManagementWorkItems(
      items: [
        for (final value in (map['data'] as List? ?? const <dynamic>[]))
          ManagementWorkItem.fromMap((value as Map).cast<String, dynamic>()),
      ],
      totalItems: number('total_items'),
      page: number('page'),
      totalPages: number('total_pages'),
    );
  }

  final List<ManagementWorkItem> items;
  final int totalItems;
  final int page;
  final int totalPages;
}

class ManagementWorkItem {
  const ManagementWorkItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.bucket,
    required this.needsAction,
    required this.allowedActions,
    required this.detailRoute,
  });

  factory ManagementWorkItem.fromMap(Map<String, dynamic> map) =>
      ManagementWorkItem(
        id: map['id'] as String? ?? '',
        kind: map['kind'] as String? ?? '',
        title: map['title'] as String? ?? '',
        subtitle: map['subtitle'] as String? ?? '',
        bucket: ManagementBucket.fromValue(map['bucket'] as String?),
        needsAction: map['needs_action'] as bool? ?? false,
        allowedActions: [
          for (final value in (map['allowed_actions'] as List? ?? const []))
            '$value',
        ],
        detailRoute: map['detail_route'] as String? ?? '',
      );

  final String id;
  final String kind;
  final String title;
  final String subtitle;
  final ManagementBucket? bucket;
  final bool needsAction;
  final List<String> allowedActions;
  final String detailRoute;
}

class ManagementTimelineEvent {
  const ManagementTimelineEvent({
    required this.id,
    required this.kind,
    required this.eventType,
    required this.journeyId,
    required this.occurredAt,
    required this.payload,
  });

  factory ManagementTimelineEvent.fromMap(Map<String, dynamic> map) =>
      ManagementTimelineEvent(
        id: map['id'] as String? ?? '',
        kind: map['kind'] as String? ?? '',
        eventType: map['event_type'] as String? ?? '',
        journeyId: (map['journey_id'] as num?)?.toInt() ?? 0,
        occurredAt: DateTime.tryParse(map['occurred_at'] as String? ?? ''),
        payload: (map['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  final String id;
  final String kind;
  final String eventType;
  final int journeyId;
  final DateTime? occurredAt;
  final Map<String, dynamic> payload;
}
