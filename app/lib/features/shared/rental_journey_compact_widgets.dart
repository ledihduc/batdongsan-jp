import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';

String rentalJourneyStatusLabel(String status) => switch (status) {
  RentalJourneyStatus.customerInterested => 'Chờ hợp đồng',
  RentalJourneyStatus.contractReady => 'Chờ ảnh cọc',
  RentalJourneyStatus.depositsPending => 'Chờ ảnh cọc',
  RentalJourneyStatus.customerConfirmationPending => 'Sẵn sàng chốt',
  RentalJourneyStatus.completed => 'Đã hoàn tất',
  RentalJourneyStatus.cancelled => 'Đã hủy',
  RentalJourneyStatus.disputed => 'Cần hỗ trợ',
  _ => 'Đang xử lý',
};

Color rentalJourneyStatusColor(String status) => switch (status) {
  RentalJourneyStatus.completed => HD.positive,
  RentalJourneyStatus.cancelled || RentalJourneyStatus.disputed => HD.negative,
  RentalJourneyStatus.customerConfirmationPending => HD.svcBlue,
  _ => HD.warning,
};

String _absoluteUrl(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

class RentalJourneyCompactHeader extends StatelessWidget {
  const RentalJourneyCompactHeader({
    super.key,
    required this.journey,
    this.subtitle,
  });

  final RentalJourney journey;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final image = journey.subject.image;
    final statusColor = rentalJourneyStatusColor(journey.status);
    return Container(
      padding: const EdgeInsets.all(HD.s12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(HD.r8),
            child: SizedBox(
              width: 64,
              height: 64,
              child: image == null || image.isEmpty
                  ? const ColoredBox(
                      color: HD.paperSunken,
                      child: Icon(Icons.apartment_rounded, color: HD.inkMuted),
                    )
                  : CachedNetworkImage(
                      imageUrl: _absoluteUrl(image),
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          const ColoredBox(color: HD.paperSunken),
                      errorWidget: (_, _, _) => const ColoredBox(
                        color: HD.paperSunken,
                        child: Icon(
                          Icons.apartment_rounded,
                          color: HD.inkMuted,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  journey.subject.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HD.bodyBold(size: 14),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 11.5, color: HD.inkMuted),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: HD.s8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (journey.totalDeposit > 0)
                      Text(
                        'Cọc ${PriceFormat.full(journey.totalDeposit.toDouble())}',
                        style: HD.bodyBold(size: 12.5, color: HD.accent),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(HD.rPill),
                      ),
                      child: Text(
                        rentalJourneyStatusLabel(journey.status),
                        style: HD.bodyBold(size: 11, color: statusColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RentalEvidenceCard extends StatelessWidget {
  const RentalEvidenceCard({
    super.key,
    required this.journey,
    required this.keyPrefix,
    this.title = 'Hợp đồng & cọc',
  });

  final RentalJourney journey;
  final String keyPrefix;
  final String title;

  @override
  Widget build(BuildContext context) {
    final app = journey.payment('APP_DEPOSIT');
    final owner = journey.payment('OWNER_DEPOSIT');
    return Container(
      padding: const EdgeInsets.all(HD.s12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: HD.bodyBold(size: 14)),
          const SizedBox(height: HD.s12),
          _EvidenceRow(
            key: Key('$keyPrefix-hop-dong-minh-chung'),
            keyPrefix: '$keyPrefix-hop-dong-anh',
            icon: Icons.description_outlined,
            color: HD.svcBlue,
            label: 'Hợp đồng',
            urls: journey.contractUrls,
          ),
          const Divider(height: HD.s20, color: HD.hairline),
          _EvidenceRow(
            keyPrefix: '$keyPrefix-APP_DEPOSIT-anh',
            icon: Icons.account_balance_wallet_outlined,
            color: HD.accent,
            label: 'Cọc Vua Nhà',
            urls: app?.proofUrls ?? const [],
          ),
          const Divider(height: HD.s20, color: HD.hairline),
          _EvidenceRow(
            keyPrefix: '$keyPrefix-OWNER_DEPOSIT-anh',
            icon: Icons.home_outlined,
            color: HD.positive,
            label: 'Cọc chủ nhà',
            urls: owner?.proofUrls ?? const [],
            acknowledged: owner?.acknowledged ?? false,
          ),
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    super.key,
    required this.keyPrefix,
    required this.icon,
    required this.color,
    required this.label,
    required this.urls,
    this.acknowledged = false,
  });

  final String keyPrefix;
  final IconData icon;
  final Color color;
  final String label;
  final List<String> urls;
  final bool acknowledged;

  @override
  Widget build(BuildContext context) {
    final absolute = [for (final url in urls) _absoluteUrl(url)];
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(HD.r8),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: HD.s8),
        SizedBox(
          width: 92,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: HD.bodyBold(size: 12.5)),
              Text(
                urls.isEmpty
                    ? 'Chưa có'
                    : acknowledged
                    ? 'Đã nhận'
                    : '${urls.length} ảnh',
                style: HD.body(
                  size: 11,
                  color: urls.isEmpty ? HD.inkMuted : HD.positive,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: HD.s8),
        Expanded(
          child: urls.isEmpty
              ? const Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.radio_button_unchecked,
                    size: 18,
                    color: HD.inkMuted,
                  ),
                )
              : SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    itemCount: absolute.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) => Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: Key('$keyPrefix-$index'),
                        onTap: () => showImageGallery(
                          context,
                          absolute,
                          initialIndex: index,
                        ),
                        borderRadius: BorderRadius.circular(HD.r8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(HD.r8),
                          child: CachedNetworkImage(
                            imageUrl: absolute[index],
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => const SizedBox(
                              width: 52,
                              height: 52,
                              child: ColoredBox(color: HD.paperSunken),
                            ),
                            errorWidget: (_, _, _) => const SizedBox(
                              width: 52,
                              height: 52,
                              child: ColoredBox(
                                color: HD.paperSunken,
                                child: Icon(
                                  Icons.description_outlined,
                                  color: HD.inkMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
