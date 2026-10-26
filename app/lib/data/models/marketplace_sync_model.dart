/// Phase 08 — Marketplace sync data shapes mirroring
/// `app/schemas/marketplace.py`.

class SyncStatusItem {
  final int roomId;
  final String roomCode;
  final int buildingId;
  final String buildingName;
  final bool isListed;
  final int? houseId;
  final String? houseStatus;
  final DateTime? lastSyncedAt;
  final bool outOfSync;

  const SyncStatusItem({
    required this.roomId,
    required this.roomCode,
    required this.buildingId,
    required this.buildingName,
    required this.isListed,
    required this.houseId,
    required this.houseStatus,
    required this.lastSyncedAt,
    required this.outOfSync,
  });

  factory SyncStatusItem.fromJson(Map<String, dynamic> j) => SyncStatusItem(
    roomId: j['room_id'] as int,
    roomCode: (j['room_code'] ?? '') as String,
    buildingId: j['building_id'] as int,
    buildingName: (j['building_name'] ?? '') as String,
    isListed: (j['is_listed'] ?? false) as bool,
    houseId: j['house_id'] as int?,
    houseStatus: j['house_status'] as String?,
    lastSyncedAt: j['last_synced_at'] != null
        ? DateTime.tryParse(j['last_synced_at'] as String)
        : null,
    outOfSync: (j['out_of_sync'] ?? false) as bool,
  );

  /// Visual badge classification consumed by sync_status_badge.dart.
  String get badge {
    if (!isListed) return 'not_listed';
    if (outOfSync) return 'out_of_sync';
    return 'synced';
  }
}

class PublishRoomResult {
  final int houseId;
  final int roomId;
  final String productType;
  final String status;
  final DateTime? lastSyncedAt;
  final bool created;

  const PublishRoomResult({
    required this.houseId,
    required this.roomId,
    required this.productType,
    required this.status,
    required this.lastSyncedAt,
    required this.created,
  });

  factory PublishRoomResult.fromJson(Map<String, dynamic> j) =>
      PublishRoomResult(
        houseId: j['house_id'] as int,
        roomId: j['room_id'] as int,
        productType: (j['product_type'] ?? '') as String,
        status: (j['status'] ?? '') as String,
        lastSyncedAt: j['last_synced_at'] != null
            ? DateTime.tryParse(j['last_synced_at'] as String)
            : null,
        created: (j['created'] ?? false) as bool,
      );
}

class CreateContractFromApptResult {
  final int contractId;
  final int tenantId;
  final bool placeholderTenant;
  final int roomId;

  const CreateContractFromApptResult({
    required this.contractId,
    required this.tenantId,
    required this.placeholderTenant,
    required this.roomId,
  });

  factory CreateContractFromApptResult.fromJson(Map<String, dynamic> j) =>
      CreateContractFromApptResult(
        contractId: j['contract_id'] as int,
        tenantId: j['tenant_id'] as int,
        placeholderTenant: (j['placeholder_tenant'] ?? false) as bool,
        roomId: j['room_id'] as int,
      );
}
