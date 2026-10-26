import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/l10n/app_localizations.dart';

String _abs(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

/// Thẻ tin đăng dạng hàng ngang (ảnh trái · nội dung phải).
///
/// Tách ra khỏi [PropertyListingScreen] để màn Mua/Bán dùng lại đúng CÙNG một
/// thẻ — hai màn cùng liệt kê tin mà thẻ khác nhau thì người dùng phải học lại
/// cách đọc ở mỗi màn.
class PropertyListCard extends StatelessWidget {
  const PropertyListCard({required this.house, super.key});

  final HouseModel house;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: () => context.push('/house/${house.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: HD.paperRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HD.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 118,
                height: 104,
                child: house.images.isEmpty
                    ? Container(
                        color: HD.paperSunken,
                        child: const Icon(
                          Icons.home_outlined,
                          color: HD.inkMuted,
                          size: 30,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: _abs(house.images.first),
                        fit: BoxFit.cover,
                        memCacheWidth: 300,
                        placeholder: (_, __) =>
                            Container(color: HD.paperSunken),
                        errorWidget: (_, __, ___) => Container(
                          color: HD.paperSunken,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: HD.inkMuted,
                          ),
                        ),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          if (house.isTrusted) ...[
                            const Icon(
                              Icons.verified,
                              size: 14,
                              color: HD.positive,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              house.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: HD.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: HD.inkMuted,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              '${house.district}, ${house.city}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: HD.inkMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            house.priceCompactLabel,
                            style: const TextStyle(
                              color: HD.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Text(
                            '  ·  ',
                            style: TextStyle(color: HD.inkMuted, fontSize: 12),
                          ),
                          Text(
                            l.plistAreaSqm(house.area.toStringAsFixed(0)),
                            style: const TextStyle(
                              color: HD.inkSoft,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          // Chỉ hiện khi tin CÓ toạ độ — nút mở bản đồ rồi đưa
                          // người dùng ra giữa biển thì thà không có.
                          if (house.latitude != null && house.longitude != null)
                            _NutBanDo(house: house),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút nhỏ "xem trên bản đồ" trên thẻ tin.
///
/// Tách thành widget riêng để vùng chạm của nó KHÔNG lồng trong vùng chạm mở
/// chi tiết tin: bấm xem vị trí mà lại mở nhầm trang chi tiết là lỗi khó chịu,
/// và rất dễ mắc khi nhét thẳng một nút vào giữa thẻ vốn đã là một nút.
class _NutBanDo extends StatelessWidget {
  const _NutBanDo({required this.house});

  final HouseModel house;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: HD.accentTint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          '/map?lat=${house.latitude}&lng=${house.longitude}'
          '&zoom=16&houseId=${house.id}',
        ),
        child: Tooltip(
          message: l.cardOnMap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Icon(Icons.place_outlined, size: 16, color: HD.accent),
          ),
        ),
      ),
    );
  }
}
