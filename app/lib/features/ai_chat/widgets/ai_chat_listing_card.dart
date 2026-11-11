/// Thẻ tin trung tính thị trường (Phase 10, F-4c, T15): giá theo `currency`, dòng phụ ga/phút
/// đi bộ (jp) hoặc số phòng ngủ + thành phố (vn). Dùng chung cho chat AI và kết quả tìm JP ở home.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/format/currency.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/ai/ai_chat_models.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class AiChatListingCard extends StatelessWidget {
  const AiChatListingCard({super.key, required this.card, this.onTap});

  final AiListingCard card;
  final VoidCallback? onTap;

  static String? priceText(AiListingCard c) {
    final p = c.price;
    if (p == null) return null;
    return formatPrice(p, locale: c.currency == 'VND' ? 'vi_VN' : 'ja_JP');
  }

  static String? subtitle(AiListingCard c, AppLocalizations l) {
    final station = c.stationName;
    if (station != null && station.isNotEmpty) {
      final walk = c.walkMin;
      return walk == null ? station : l.jpStationWalk(station, walk);
    }
    final parts = [
      if (c.bedrooms != null) l.aiCardBedrooms(c.bedrooms!),
      if (c.city != null && c.city!.isNotEmpty) c.city!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final price = priceText(card);
    final sub = subtitle(card, l);
    final meta = [if (card.layout != null && card.layout!.isNotEmpty) card.layout!,
                  if (card.areaM2 != null) '${card.areaM2!.toStringAsFixed(card.areaM2! % 1 == 0 ? 0 : 1)}㎡'];
    return Padding(
      padding: const EdgeInsets.only(top: HD.s8),
      child: DsCard(
        onTap: onTap,
        padding: const EdgeInsets.all(HD.s12),
        child: Row(
          children: [
            const Icon(Icons.home_work_outlined, color: HD.inkMuted),
            const SizedBox(width: HD.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: HD.ink)),
                  if (price != null)
                    Text(price, style: const TextStyle(fontWeight: FontWeight.w700, color: HD.accent)),
                  if (sub != null) Text(sub, style: const TextStyle(color: HD.inkSoft)),
                  if (meta.isNotEmpty) Text(meta.join(' · '), style: const TextStyle(color: HD.inkMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: HD.inkMuted),
          ],
        ),
      ),
    );
  }
}
