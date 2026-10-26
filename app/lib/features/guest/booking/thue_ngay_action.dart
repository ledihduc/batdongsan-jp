import 'package:flutter/material.dart';

import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/data/services/viewing_v2_api.dart';
import 'package:house_booking/features/guest/booking/xac_nhan_muon_thue_screen.dart';

/// Starts the rental journey without recording a false "viewing completed".
Future<bool> moThueNgay(
  BuildContext context, {
  required PhieuHen phieu,
  required ViewingV2Api viewingApi,
  required RentalJourneyApi rentalApi,
}) async {
  final dongY = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Muốn thuê ngay căn này?'),
      content: const Text(
        'Bạn không cần chờ đến giờ xem. Vua Nhà sẽ mở hồ sơ thuê để Sale '
        'xác nhận giá, tiền cọc và hợp đồng với chủ nhà.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Để sau'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.favorite, size: 18),
          label: const Text('Tiếp tục thuê'),
        ),
      ],
    ),
  );
  if (dongY != true || !context.mounted) return false;

  final result = await viewingApi.rentNow(phieu.id);
  final journeyId = result.rentalJourneyId;
  if (journeyId == null) {
    throw StateError('Chưa tạo được hồ sơ thuê');
  }
  final journey = await rentalApi.detail(journeyId);
  if (!context.mounted) return false;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => XacNhanMuonThueScreen(journey: journey, phieu: phieu),
    ),
  );
  return true;
}
