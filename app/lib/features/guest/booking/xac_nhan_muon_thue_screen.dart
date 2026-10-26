import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/features/guest/booking/coc_xac_nhan_thue_screen.dart';
import 'package:house_booking/features/shared/viewing_detail_widgets.dart';

/// Khách kiểm tra thông tin trước khi chuyển sang hồ sơ cọc và hợp đồng.
class XacNhanMuonThueScreen extends StatelessWidget {
  const XacNhanMuonThueScreen({super.key, required this.journey, this.phieu});

  final RentalJourney journey;
  final PhieuHen? phieu;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HD.paper,
    appBar: ViewingDetailAppBar(title: 'Xác nhận muốn thuê'),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, HD.s24),
      children: [
        _property(),
        const SizedBox(height: HD.s12),
        const ViewingStatusBox(
          icon: Icons.schedule,
          title: 'Chờ Sale xác nhận',
          message:
              'Bạn đã chọn muốn thuê. Sale sẽ xác nhận lại với chủ nhà và liên hệ sớm.',
          color: HD.warning,
        ),
        const SizedBox(height: HD.s16),
        Text('Thông tin dự kiến', style: HD.bodyBold(size: 14)),
        const SizedBox(height: HD.s8),
        ViewingSectionCard(
          child: Column(
            children: [
              _row(
                Icons.payments_outlined,
                'Giá thuê',
                (phieu?.tin.gia ?? 0) > 0
                    ? '${PriceFormat.full(phieu!.tin.gia!)}/${phieu!.tin.donVi}'
                    : 'Sale sẽ xác nhận',
              ),
              _row(
                Icons.savings_outlined,
                'Tiền cọc dự kiến',
                journey.totalDeposit > 0
                    ? PriceFormat.full(journey.totalDeposit.toDouble())
                    : 'Sale sẽ xác nhận',
              ),
              _row(
                Icons.calendar_month,
                'Ngày bắt đầu thuê',
                'Thống nhất trong hợp đồng',
              ),
              _row(
                Icons.description_outlined,
                'Thời hạn thuê',
                'Thống nhất trong hợp đồng',
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: HD.s12),
        Container(
          padding: const EdgeInsets.all(HD.s12),
          decoration: BoxDecoration(
            color: HD.accentTint,
            borderRadius: BorderRadius.circular(HD.r8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info, size: 19, color: HD.accent),
              const SizedBox(width: HD.s8),
              Expanded(
                child: Text(
                  'Sale sẽ xác nhận lại giá, tiền cọc và lịch ký với chủ nhà. Bạn sẽ được thông báo ngay khi có thông tin chính thức.',
                  style: HD.body(size: 12.5, color: HD.inkSoft),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            key: const Key('gui-yeu-cau-chot-thue'),
            style: viewingPrimaryButton(),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => CocXacNhanThueScreen(journeyId: journey.id),
              ),
            ),
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Gửi yêu cầu chốt thuê'),
          ),
          const SizedBox(height: HD.s8),
          OutlinedButton.icon(
            style: viewingOutlineButton(),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Sale sẽ liên hệ với bạn trên số điện thoại đã đăng ký.',
                ),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Nhắn Sale'),
          ),
        ],
      ),
    ),
  );

  Widget _property() {
    if (phieu != null) return ViewingPropertyCard(phieu: phieu!);
    final image = journey.subject.image;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(HD.r8),
          child: SizedBox(
            width: 94,
            height: 82,
            child: image == null || image.isEmpty
                ? const ColoredBox(
                    color: HD.paperSunken,
                    child: Icon(Icons.apartment, color: HD.inkMuted),
                  )
                : CachedNetworkImage(
                    imageUrl: image.startsWith('http')
                        ? image
                        : '${ApiConfig.baseUrl}$image',
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Text(journey.subject.title, style: HD.bodyBold(size: 15)),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String label, String value, {bool last = false}) =>
      Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: HD.accent),
            const SizedBox(width: HD.s8),
            Expanded(
              child: Text(
                label,
                style: HD.body(size: 12.5, color: HD.inkMuted),
              ),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: HD.bodyBold(size: 12.5),
              ),
            ),
          ],
        ),
      );
}
