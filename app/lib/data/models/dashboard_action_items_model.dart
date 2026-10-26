/// Dashboard 'cần action' aggregated payload (Phase 06 D5).
class DashboardActionItemsModel {
  final List<ExpiringContractRow> expiringContracts;
  final List<OverdueInvoiceRow> overdueInvoices;
  final List<OverdueKhaiBaoRow> overdueKhaiBao;
  final List<MaintenanceRoomRow> maintenanceRooms;
  final ActionItemsSummary summary;

  const DashboardActionItemsModel({
    required this.expiringContracts,
    required this.overdueInvoices,
    required this.overdueKhaiBao,
    required this.maintenanceRooms,
    required this.summary,
  });

  static const DashboardActionItemsModel empty = DashboardActionItemsModel(
    expiringContracts: [],
    overdueInvoices: [],
    overdueKhaiBao: [],
    maintenanceRooms: [],
    summary: ActionItemsSummary.empty,
  );

  bool get hasAny =>
      expiringContracts.isNotEmpty ||
      overdueInvoices.isNotEmpty ||
      overdueKhaiBao.isNotEmpty ||
      maintenanceRooms.isNotEmpty;

  factory DashboardActionItemsModel.fromJson(Map<String, dynamic> json) {
    List<T> mapList<T>(String key, T Function(Map<String, dynamic>) ctor) =>
        ((json[key] as List?) ?? const [])
            .map((e) => ctor(Map<String, dynamic>.from(e as Map)))
            .toList();
    return DashboardActionItemsModel(
      expiringContracts: mapList(
        'expiring_contracts',
        ExpiringContractRow.fromJson,
      ),
      overdueInvoices: mapList('overdue_invoices', OverdueInvoiceRow.fromJson),
      overdueKhaiBao: mapList('overdue_khai_bao', OverdueKhaiBaoRow.fromJson),
      maintenanceRooms: mapList(
        'maintenance_rooms',
        MaintenanceRoomRow.fromJson,
      ),
      summary: ActionItemsSummary.fromJson(
        Map<String, dynamic>.from((json['summary'] as Map?) ?? const {}),
      ),
    );
  }
}

class ActionItemsSummary {
  final int expiringCount;
  final int overdueInvoiceCount;
  final int overdueKhaiBaoCount;
  final int maintenanceCount;

  const ActionItemsSummary({
    required this.expiringCount,
    required this.overdueInvoiceCount,
    required this.overdueKhaiBaoCount,
    required this.maintenanceCount,
  });

  static const ActionItemsSummary empty = ActionItemsSummary(
    expiringCount: 0,
    overdueInvoiceCount: 0,
    overdueKhaiBaoCount: 0,
    maintenanceCount: 0,
  );

  int get total =>
      expiringCount +
      overdueInvoiceCount +
      overdueKhaiBaoCount +
      maintenanceCount;

  factory ActionItemsSummary.fromJson(
    Map<String, dynamic> json,
  ) => ActionItemsSummary(
    expiringCount: (json['expiring_count'] as num? ?? 0).toInt(),
    overdueInvoiceCount: (json['overdue_invoice_count'] as num? ?? 0).toInt(),
    overdueKhaiBaoCount: (json['overdue_khai_bao_count'] as num? ?? 0).toInt(),
    maintenanceCount: (json['maintenance_count'] as num? ?? 0).toInt(),
  );
}

class ExpiringContractRow {
  final int contractId;
  final int roomId;
  final String endDate;
  final double monthlyRent;

  const ExpiringContractRow({
    required this.contractId,
    required this.roomId,
    required this.endDate,
    required this.monthlyRent,
  });

  factory ExpiringContractRow.fromJson(Map<String, dynamic> json) =>
      ExpiringContractRow(
        contractId: json['contract_id'] as int,
        roomId: json['room_id'] as int,
        endDate: json['end_date'] as String? ?? '',
        monthlyRent: (json['monthly_rent'] as num? ?? 0).toDouble(),
      );
}

class OverdueInvoiceRow {
  final int invoiceId;
  final String invoiceNumber;
  final int contractId;
  final String dueDate;
  final double totalAmount;
  final double paidAmount;

  const OverdueInvoiceRow({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.contractId,
    required this.dueDate,
    required this.totalAmount,
    required this.paidAmount,
  });

  double get remaining => totalAmount - paidAmount;

  factory OverdueInvoiceRow.fromJson(Map<String, dynamic> json) =>
      OverdueInvoiceRow(
        invoiceId: json['invoice_id'] as int,
        invoiceNumber: json['invoice_number'] as String? ?? '',
        contractId: json['contract_id'] as int,
        dueDate: json['due_date'] as String? ?? '',
        totalAmount: (json['total_amount'] as num? ?? 0).toDouble(),
        paidAmount: (json['paid_amount'] as num? ?? 0).toDouble(),
      );
}

class OverdueKhaiBaoRow {
  final int khaiBaoId;
  final int tenantId;
  final int? contractId;
  final String checkInAt;

  const OverdueKhaiBaoRow({
    required this.khaiBaoId,
    required this.tenantId,
    required this.contractId,
    required this.checkInAt,
  });

  factory OverdueKhaiBaoRow.fromJson(Map<String, dynamic> json) =>
      OverdueKhaiBaoRow(
        khaiBaoId: json['khai_bao_id'] as int,
        tenantId: json['tenant_id'] as int,
        contractId: json['contract_id'] as int?,
        checkInAt: json['check_in_at'] as String? ?? '',
      );
}

class MaintenanceRoomRow {
  final int roomId;
  final String roomCode;
  final int buildingId;
  final String buildingName;
  final String? maintenanceStart;
  final String? maintenanceEnd;

  const MaintenanceRoomRow({
    required this.roomId,
    required this.roomCode,
    required this.buildingId,
    required this.buildingName,
    required this.maintenanceStart,
    required this.maintenanceEnd,
  });

  factory MaintenanceRoomRow.fromJson(Map<String, dynamic> json) =>
      MaintenanceRoomRow(
        roomId: json['room_id'] as int,
        roomCode: json['room_code'] as String? ?? '',
        buildingId: json['building_id'] as int,
        buildingName: json['building_name'] as String? ?? '',
        maintenanceStart: json['maintenance_start'] as String?,
        maintenanceEnd: json['maintenance_end'] as String?,
      );
}

/// Zalo reminder response from POST /api/host/dashboard/invoices/{id}/zalo-reminder.
class ZaloReminderModel {
  final String zaloLink;
  final String phone;
  final String message;

  const ZaloReminderModel({
    required this.zaloLink,
    required this.phone,
    required this.message,
  });

  factory ZaloReminderModel.fromJson(Map<String, dynamic> json) =>
      ZaloReminderModel(
        zaloLink: json['zalo_link'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );
}
