/// Khối kết quả tìm kiếm JP ở home sau khi áp bộ lọc 間取り/家賃/駅徒歩 (Phase 10, F-2).
/// API: GET /api/jp/listings (gọi ở `GuestHomeScreen`). Bấm thẻ ⇒ `/house/:id`.
/// Gọi lỗi ⇒ [failed] hiện thông báo lỗi + nút thử lại, tách khỏi trạng thái "không có tin".
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/ai/ai_chat_models.dart';
import 'package:house_booking/data/models/jp/jp_listing.dart';
import 'package:house_booking/features/ai_chat/widgets/ai_chat_listing_card.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class JpSearchResultsSection extends StatelessWidget {
  const JpSearchResultsSection({super.key, required this.items, required this.loading,
      this.failed = false, this.onRetry, this.onOpen});

  final List<JpListingSummary> items;
  final bool loading;
  final bool failed;
  final VoidCallback? onRetry;
  final void Function(int listingId)? onOpen;

  /// Tin JP ⇒ thẻ trung tính (giá yên, ga + phút đi bộ) để dùng chung [AiChatListingCard].
  static AiListingCard toCard(JpListingSummary s) => AiListingCard(
        listingId: s.listingId,
        title: s.title,
        price: s.monthlyRent,
        currency: 'JPY',
        areaM2: s.floorAreaM2 > 0 ? s.floorAreaM2 : null,
        layout: s.layout,
        stationName: s.nearestStationName,
        walkMin: s.nearestStationWalkMin,
        city: s.city,
        thumbnailUrl: s.thumbnailUrl,
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(HD.s20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, HD.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (failed)
            Row(children: [
              const Icon(Icons.error_outline, color: HD.negative),
              const SizedBox(width: HD.s8),
              Expanded(child: Text(l.aiChatErrorNetwork, style: const TextStyle(color: HD.negative))),
              DsButton(label: l.aiChatRetry, variant: DsButtonVariant.ghost, size: DsButtonSize.compact, onPressed: onRetry),
            ])
          else if (items.isEmpty)
            Text(l.jpSearchResultsEmpty, style: const TextStyle(color: HD.inkMuted))
          else ...[
            Text(l.jpSearchResultsTitle(items.length),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: HD.ink)),
            for (final s in items)
              AiChatListingCard(card: toCard(s), onTap: onOpen == null ? null : () => onOpen!(s.listingId)),
          ],
        ],
      ),
    );
  }
}
