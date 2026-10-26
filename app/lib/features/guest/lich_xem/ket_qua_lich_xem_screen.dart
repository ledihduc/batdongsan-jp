import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/features/guest/booking/schedule_booking_screen.dart';
import 'package:house_booking/features/guest/lich_xem/trang_thai_xem.dart';
import 'package:house_booking/features/guest/thue_o/ho_so_thue.dart';

enum KieuKetQuaXem { daChot, khongChot, daHuy }

/// Màn 5a/5b/5c — kết quả cuối của một lịch xem phòng (mockup 04/10/2026):
///
///   * 5a "Đã chốt phòng!"          → Xem phòng đang thuê · Về trang chủ
///   * 5b "Bạn chưa chốt phòng"     → Xem thêm phòng · Về trang chủ
///   * 5c "Đã hủy lịch xem phòng"   → Đặt lịch lại · Về trang chủ
///
/// Không gọi API: màn trước đã ghi xong, đây chỉ báo kết quả và chỉ lối đi
/// tiếp. "Xem phòng đang thuê" và "Về trang chủ" đều quay về trang Hoạt động
/// (gốc của tab) — phòng vừa chốt hiện ở mục Đang thuê / đề nghị thuê ở đó.
class KetQuaLichXemScreen extends StatelessWidget {
  const KetQuaLichXemScreen({
    super.key,
    required this.kieu,
    required this.phieu,
    this.onTimNha,
  });

  final KieuKetQuaXem kieu;
  final PhieuHen phieu;

  /// Mở trang tìm nhà ("Xem thêm phòng"). Null → chỉ quay về trang gốc.
  final VoidCallback? onTimNha;

  void _veGoc(BuildContext context) =>
      Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    final (icon, mau, nen, tieuDe, loi) = switch (kieu) {
      KieuKetQuaXem.daChot => (
        Icons.check_rounded,
        HD.positive,
        HD.positiveTint,
        'Đã chốt phòng!',
        'Bạn đã chốt phòng này. Sale sẽ liên hệ với bạn để làm hợp đồng '
            'và hướng dẫn đặt cọc.',
      ),
      KieuKetQuaXem.khongChot => (
        Icons.sentiment_neutral_rounded,
        const Color(0xFF6B7280),
        const Color(0xFFF1F2F4),
        'Bạn chưa chốt phòng',
        'Cảm ơn bạn đã phản hồi. Sale sẽ gợi ý thêm những phòng phù hợp '
            'hơn với nhu cầu của bạn.',
      ),
      KieuKetQuaXem.daHuy => (
        Icons.event_busy_rounded,
        HD.accent,
        HD.accentTint,
        'Đã hủy lịch xem phòng',
        'Lịch xem phòng của bạn đã được hủy. Sale đã nhận được thông báo.',
      ),
    };
    final (chinh, khoaChinh, onChinh) = switch (kieu) {
      KieuKetQuaXem.daChot => (
        'Xem phòng đang thuê',
        const Key('ket-qua-xem-phong'),
        () => _veGoc(context),
      ),
      KieuKetQuaXem.khongChot => (
        'Xem thêm phòng',
        const Key('ket-qua-xem-them'),
        () {
          _veGoc(context);
          onTimNha?.call();
        },
      ),
      KieuKetQuaXem.daHuy => (
        'Đặt lịch lại',
        const Key('ket-qua-dat-lai'),
        () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ScheduleBookingScreen(
              houseId: phieu.tin.houseId,
              roomId: phieu.tin.roomId,
              tenPhong: phieu.tin.tieuDe,
            ),
          ),
        ),
      ),
    };
    final datLaiDuoc =
        kieu != KieuKetQuaXem.daHuy ||
        phieu.tin.houseId != null ||
        phieu.tin.roomId != null;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: nen, shape: BoxShape.circle),
                child: Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: mau,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 38),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                tieuDe,
                key: const Key('ket-qua-tieu-de'),
                textAlign: TextAlign.center,
                style: HD.bodyBold(size: 21, color: HD.ink),
              ),
              const SizedBox(height: 10),
              Text(
                loi,
                textAlign: TextAlign.center,
                style: HD.body(size: 14, color: HD.inkMuted),
              ),
              const SizedBox(height: 22),
              _TomTat(phieu: phieu),
              const Spacer(flex: 3),
              if (datLaiDuoc)
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: FilledButton(
                    key: khoaChinh,
                    style: FilledButton.styleFrom(
                      backgroundColor: HD.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: HD.bodyBold(size: 15),
                    ),
                    onPressed: onChinh,
                    child: Text(chinh),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('ve-trang-chu'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HD.ink,
                    side: const BorderSide(color: Color(0xFFD5D8DD)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: HD.bodyBold(size: 15),
                  ),
                  onPressed: () => _veGoc(context),
                  child: const Text('Về trang chủ'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ nhỏ nhắc lại phòng + giờ hẹn.
class _TomTat extends StatelessWidget {
  const _TomTat({required this.phieu});

  final PhieuHen phieu;

  @override
  Widget build(BuildContext context) {
    final anh = phieu.tin.anhDs.isNotEmpty
        ? phieu.tin.anhDs.first
        : phieu.tin.anh;
    final luc = phieu.luc;
    const nen = ColoredBox(
      color: HD.paperSunken,
      child: Center(child: Icon(Icons.apartment_rounded, color: HD.inkMuted)),
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEEF1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 56,
              child: anh == null
                  ? nen
                  : CachedNetworkImage(
                      imageUrl: duongDanAnh(anh),
                      fit: BoxFit.cover,
                      placeholder: (_, _) => nen,
                      errorWidget: (_, _, _) => nen,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phieu.tin.tieuDe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.bodyBold(size: 14.5, color: HD.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  luc == null
                      ? khoangGio(phieu.gio)
                      : '${thuNgay(luc)} • ${khoangGio(phieu.gio)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.body(size: 12.5, color: HD.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
