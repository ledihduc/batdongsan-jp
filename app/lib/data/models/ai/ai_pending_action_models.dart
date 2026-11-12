/// Model action ghi AI chờ xác nhận (plan 20261027-1102 Phase 11; schema backend Phase 09
/// `backend/app/schemas/ai_actions.py`). Token chỉ giữ trong bộ nhớ, không lưu máy, không log.
library;

Map<String, dynamic> _map(Object? v) => v is Map<String, dynamic> ? v : const {};

/// Thẻ chờ xác nhận đi kèm câu trả lời chat (`pending_actions[]`).
class AiPendingAction {
  const AiPendingAction({
    required this.token,
    required this.action,
    required this.title,
    required this.params,
    required this.expiresAt,
  });

  final String token;
  final String action;
  final String title;
  final Map<String, dynamic> params;
  final DateTime expiresAt;

  factory AiPendingAction.fromJson(Map<String, dynamic> j) => AiPendingAction(
        token: j['token'] as String,
        action: j['action'] as String? ?? '',
        title: j['title'] as String? ?? '',
        params: _map(j['params']),
        expiresAt: DateTime.parse(j['expires_at'] as String),
      );
}

/// Tin đính kèm bản xem trước; giá theo [currency] (`JPY` | `VND`).
class AiPendingListing {
  const AiPendingListing({required this.listingId, required this.title, this.price, this.currency, this.layout});

  final int listingId;
  final String title;
  final int? price;
  final String? currency;
  final String? layout;

  factory AiPendingListing.fromJson(Map<String, dynamic> j) => AiPendingListing(
        listingId: (j['listing_id'] as num).toInt(),
        title: j['title'] as String? ?? '',
        price: (j['price'] as num?)?.toInt(),
        currency: j['currency'] as String?,
        layout: j['layout'] as String?,
      );
}

/// `GET /api/ai/actions/{token}` — xem trước, không ghi gì.
class AiPendingPreview {
  const AiPendingPreview({
    required this.action,
    required this.title,
    required this.description,
    required this.params,
    this.listing,
    required this.status,
    required this.expiresAt,
    required this.ownerBound,
  });

  final String action;
  final String title;
  final String description;
  final Map<String, dynamic> params;
  final AiPendingListing? listing;
  final String status;
  final DateTime expiresAt;
  final bool ownerBound;

  factory AiPendingPreview.fromJson(Map<String, dynamic> j) => AiPendingPreview(
        action: j['action'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        params: _map(j['params']),
        listing: j['listing'] is Map<String, dynamic> ? AiPendingListing.fromJson(j['listing'] as Map<String, dynamic>) : null,
        status: j['status'] as String? ?? '',
        expiresAt: DateTime.parse(j['expires_at'] as String),
        ownerBound: j['owner_bound'] as bool? ?? false,
      );
}

/// `POST /api/ai/actions/{token}/confirm` — kết quả thực thi.
class AiConfirmResult {
  const AiConfirmResult({required this.status, required this.action, required this.result});

  final String status;
  final String action;
  final Map<String, dynamic> result;

  factory AiConfirmResult.fromJson(Map<String, dynamic> j) => AiConfirmResult(
        status: j['status'] as String? ?? '',
        action: j['action'] as String? ?? '',
        result: _map(j['result']),
      );
}
