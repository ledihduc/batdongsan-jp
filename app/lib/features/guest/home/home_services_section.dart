import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/community_category.dart';
import 'package:house_booking/features/guest/browse/property_listing_screen.dart';
import 'package:house_booking/features/guest/service/service_catalog_screen.dart';

/// Lưới dịch vụ kiểu SIÊU APP trên trang chủ — 2 nhóm: Bất động sản + Thi công.
///
/// - Tile **Thuê nhà / Cho thuê** → về danh sách nhà cho thuê (như cũ) qua
///   [onOpenListing] (cuộn xuống feed tin đăng).
/// - Các tile dịch vụ (BĐS công nghiệp, Thiết kế, Xây dựng, Nội thất) → mở
///   danh bạ đơn vị dịch vụ ([ServiceCatalogScreen]).
/// - Lối tắt "Bảng xếp hạng nhà thầu" → [ContractorLeaderboardScreen].
class HomeServicesSection extends StatelessWidget {
  const HomeServicesSection({super.key});

  /// Ba ô Thiết kế / Xây dựng / Nội thất trước đây mở màn Cộng đồng theo khối.
  /// Màn đó đã bị bỏ, nên chúng chuyển sang DANH BẠ ĐƠN VỊ DỊCH VỤ — thứ gần
  /// nhất còn lại phục vụ đúng nhu cầu "tôi cần tìm người làm việc này".
  void _openServices(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ServiceCatalogScreen()),
    );
  }

  /// Mở trang riêng xem danh sách + tìm kiếm tin đăng BĐS (thay cho việc cuộn
  /// trang chủ). BĐS công nghiệp → lọc theo danh mục cùng tên.
  void _openListing(
    BuildContext context,
    String title, {
    String? categoryName,
    String? groupKey,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyListingScreen(
          title: title,
          categoryName: categoryName,
          groupKey: groupKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _groupHeader(l.svcRealEstate),
        Row(
          children: [
            // Rental-first: gộp "Thuê nhà"/"Cho thuê" thành 1 cửa duy nhất
            // (danh sách nhà cho thuê), tránh 2 tile trùng vào cùng 1 kho tin.
            _tile(
              context,
              communityCategoryOf('lease').icon,
              l.svcRental,
              () => _openListing(context, l.svcRental),
            ),
            _tile(
              context,
              communityCategoryOf('industrial').icon,
              l.svcIndustrial,
              () =>
                  _openListing(context, l.svcIndustrial, groupKey: 'business'),
            ),
            _tile(
              context,
              Icons.map_outlined,
              l.svcMap,
              () => context.push('/map'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _groupHeader(l.svcConstruction, badge: l.svcNew),
        Row(
          children: [
            _tile(
              context,
              communityCategoryOf('design').icon,
              l.svcDesign,
              () => _openServices(context),
            ),
            _tile(
              context,
              communityCategoryOf('build').icon,
              l.svcBuild,
              () => _openServices(context),
            ),
            _tile(
              context,
              communityCategoryOf('interior').icon,
              l.svcInterior,
              () => _openServices(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _leaderboardShortcut(context),
      ],
    );
  }

  /// Lối tắt full-width tới bảng xếp hạng nhà thầu (mọi ngành nghề).
  Widget _leaderboardShortcut(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: null, // bảng xếp hạng nhà thầu đã gỡ cùng mảng thi công
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: HD.accentTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HD.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: HD.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.emoji_events_outlined,
                color: HD.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.svcLeaderboardTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: HD.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.svcLeaderboardSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: HD.inkMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _groupHeader(String text, {String? badge}) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 2),
    child: Row(
      children: [
        Text(text, style: HD.eyebrow()),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: HD.accent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _tile(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: HD.accentTint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: HD.accent, size: 28),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: HD.ink,
                    height: 1.15,
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
