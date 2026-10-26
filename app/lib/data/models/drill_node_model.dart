/// Drill-down models — mirrors GET /api/host/analytics/drill-down response.
///
/// JSON contract frozen in _analytics_shapes.md §5.
/// Supports 4 drill levels; each has its own item type and response class.

// ---------------------------------------------------------------------------
// Pagination envelope
// ---------------------------------------------------------------------------

/// Generic pagination wrapper used by all 4 drill levels.
class DrillPage<T> {
  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;

  const DrillPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });
}

// ---------------------------------------------------------------------------
// Level 1: room_list
// ---------------------------------------------------------------------------

class RoomListItem {
  final int roomId;
  final String roomCode;
  final String roomStatus;
  final int buildingId;
  final String buildingName;

  const RoomListItem({
    required this.roomId,
    required this.roomCode,
    required this.roomStatus,
    required this.buildingId,
    required this.buildingName,
  });

  factory RoomListItem.fromJson(Map<String, dynamic> json) {
    return RoomListItem(
      roomId: json['room_id'] as int,
      roomCode: json['room_code'] as String? ?? '',
      roomStatus: json['room_status'] as String? ?? '',
      buildingId: json['building_id'] as int? ?? 0,
      buildingName: json['building_name'] as String? ?? '',
    );
  }
}

class RoomListResponse extends DrillPage<RoomListItem> {
  const RoomListResponse({
    required super.items,
    required super.totalCount,
    required super.page,
    required super.pageSize,
  });

  factory RoomListResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? const [])
        .map((e) => RoomListItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return RoomListResponse(
      items: items,
      totalCount: json['total_count'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 50,
    );
  }
}

// ---------------------------------------------------------------------------
// Level 2: contracts_by_room
// ---------------------------------------------------------------------------

class ContractByRoomItem {
  final int contractId;
  final String startDate;
  final String endDate;
  final String status;
  final double monthlyRent;

  const ContractByRoomItem({
    required this.contractId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.monthlyRent,
  });

  factory ContractByRoomItem.fromJson(Map<String, dynamic> json) {
    return ContractByRoomItem(
      contractId: json['contract_id'] as int,
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      status: json['status'] as String? ?? '',
      monthlyRent: (json['monthly_rent'] as num? ?? 0).toDouble(),
    );
  }
}

class ContractByRoomResponse extends DrillPage<ContractByRoomItem> {
  const ContractByRoomResponse({
    required super.items,
    required super.totalCount,
    required super.page,
    required super.pageSize,
  });

  factory ContractByRoomResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? const [])
        .map(
          (e) =>
              ContractByRoomItem.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    return ContractByRoomResponse(
      items: items,
      totalCount: json['total_count'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 50,
    );
  }
}

// ---------------------------------------------------------------------------
// Level 3: tenants_by_contract
// ---------------------------------------------------------------------------

class TenantByContractItem {
  final int tenantId;
  final String fullName;
  final String phone;
  final bool isPrimary;
  final String joinedAt;

  const TenantByContractItem({
    required this.tenantId,
    required this.fullName,
    required this.phone,
    required this.isPrimary,
    required this.joinedAt,
  });

  factory TenantByContractItem.fromJson(Map<String, dynamic> json) {
    return TenantByContractItem(
      tenantId: json['tenant_id'] as int,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      isPrimary: json['is_primary'] as bool? ?? false,
      joinedAt: json['joined_at'] as String? ?? '',
    );
  }
}

class TenantByContractResponse extends DrillPage<TenantByContractItem> {
  const TenantByContractResponse({
    required super.items,
    required super.totalCount,
    required super.page,
    required super.pageSize,
  });

  factory TenantByContractResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? const [])
        .map(
          (e) => TenantByContractItem.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
    return TenantByContractResponse(
      items: items,
      totalCount: json['total_count'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 50,
    );
  }
}

// ---------------------------------------------------------------------------
// Level 4: invoices_by_tenant
// ---------------------------------------------------------------------------

class InvoiceByTenantItem {
  final int invoiceId;
  final String invoiceNumber;
  final String periodStart;
  final String periodEnd;
  final double totalAmount;
  final String status;

  /// Nullable — null when invoice is not yet paid.
  final String? paidAt;

  const InvoiceByTenantItem({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.periodStart,
    required this.periodEnd,
    required this.totalAmount,
    required this.status,
    this.paidAt,
  });

  factory InvoiceByTenantItem.fromJson(Map<String, dynamic> json) {
    return InvoiceByTenantItem(
      invoiceId: json['invoice_id'] as int,
      invoiceNumber: json['invoice_number'] as String? ?? '',
      periodStart: json['period_start'] as String? ?? '',
      periodEnd: json['period_end'] as String? ?? '',
      totalAmount: (json['total_amount'] as num? ?? 0).toDouble(),
      status: json['status'] as String? ?? '',
      paidAt: json['paid_at'] as String?,
    );
  }
}

class InvoiceByTenantResponse extends DrillPage<InvoiceByTenantItem> {
  const InvoiceByTenantResponse({
    required super.items,
    required super.totalCount,
    required super.page,
    required super.pageSize,
  });

  factory InvoiceByTenantResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? const [])
        .map(
          (e) =>
              InvoiceByTenantItem.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    return InvoiceByTenantResponse(
      items: items,
      totalCount: json['total_count'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 50,
    );
  }
}
