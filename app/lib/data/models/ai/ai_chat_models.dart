/// Model cho chat AI `POST /api/ai/chat` (plan 20261027-1102 Phase 10, T15).
///
/// [AiListingCard] là thẻ trung tính thị trường (khoá snake_case = `CARD_KEYS` của backend
/// Phase 08), không dùng `JpListingSummary` vì bản vn không có field JP.
library;

/// Một lượt hội thoại gửi lên backend (`role` = `user` | `assistant`).
class AiChatTurn {
  const AiChatTurn({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// Thẻ tin trong câu trả lời chat; giá theo [currency] (`JPY` | `VND`).
class AiListingCard {
  const AiListingCard({
    required this.listingId,
    required this.title,
    this.price,
    this.currency,
    this.areaM2,
    this.layout,
    this.bedrooms,
    this.stationName,
    this.walkMin,
    this.city,
    this.thumbnailUrl,
  });

  final int listingId;
  final String title;
  final int? price;
  final String? currency;
  final double? areaM2;
  final String? layout;
  final int? bedrooms;
  final String? stationName;
  final int? walkMin;
  final String? city;
  final String? thumbnailUrl;

  factory AiListingCard.fromJson(Map<String, dynamic> j) => AiListingCard(
        listingId: (j['listing_id'] as num).toInt(),
        title: j['title'] as String? ?? '',
        price: (j['price'] as num?)?.toInt(),
        currency: j['currency'] as String?,
        areaM2: (j['area_m2'] as num?)?.toDouble(),
        layout: j['layout'] as String?,
        bedrooms: (j['bedrooms'] as num?)?.toInt(),
        stationName: j['station_name'] as String?,
        walkMin: (j['walk_min'] as num?)?.toInt(),
        city: j['city'] as String?,
        thumbnailUrl: j['thumbnail_url'] as String?,
      );
}

/// Câu trả lời một lượt chat. `pending_actions` / `login_required` (Phase 09) dùng ở Phase 11.
class AiChatReply {
  const AiChatReply({required this.reply, required this.listings, required this.toolRounds});

  final String reply;
  final List<AiListingCard> listings;
  final int toolRounds;

  factory AiChatReply.fromJson(Map<String, dynamic> json) => AiChatReply(
        reply: json['reply'] as String? ?? '',
        listings: (json['listings'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .where((e) => e['listing_id'] is num)
            .map(AiListingCard.fromJson)
            .toList(),
        toolRounds: (json['tool_rounds'] as num?)?.toInt() ?? 0,
      );
}
