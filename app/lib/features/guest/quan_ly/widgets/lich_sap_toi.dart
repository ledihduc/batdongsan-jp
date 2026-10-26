import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/quan_ly_api.dart';

/// "Th 2" … "Th 7", "CN" — cách người Việt ghi thứ trên lịch.
String thuVN(DateTime d) =>
    d.weekday == DateTime.sunday ? 'CN' : 'Th ${d.weekday + 1}';

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _dm(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// Icon + màu theo LOẠI mốc. Màu ô ngày cùng màu icon để mắt nhóm được "hôm
/// nào có việc gì" mà không cần đọc chữ.
(IconData, Color) kieuSuKien(String loai) => switch (loai) {
  'xem_nha' => (Icons.home_rounded, HD.accent),
  'hen_chot' => (Icons.handshake_outlined, HD.accent),
  'nhan_phong' => (Icons.vpn_key_rounded, HD.svcGreen),
  'tra_phong' => (Icons.logout_rounded, HD.svcBlue),
  'vao_o' => (Icons.event_available, HD.svcBlue),
  'het_han' => (Icons.event_busy_outlined, HD.svcOrange),
  _ => (Icons.event_note_outlined, HD.inkMuted),
};

/// Thẻ "Lịch sắp tới" trên trang Quản lý: vài mốc gần nhất + "Xem tất cả".
class KhoiLichSapToi extends StatelessWidget {
  const KhoiLichSapToi({
    super.key,
    required this.lich,
    required this.onChon,
    required this.onXemTatCa,
    this.toiDa = 3,
    this.loiRong = 'Chưa có lịch nào sắp tới.',
  });

  final List<SuKienQuanLy> lich;
  final ValueChanged<SuKienQuanLy> onChon;
  final VoidCallback onXemTatCa;
  final int toiDa;
  final String loiRong;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s12, HD.s12),
    decoration: BoxDecoration(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(HD.r12 + 4),
      boxShadow: [
        BoxShadow(
          color: HD.ink.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month, color: HD.accent, size: 24),
            const SizedBox(width: HD.s8),
            const Expanded(
              child: Text(
                'Lịch sắp tới',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: HD.ink,
                ),
              ),
            ),
            // Luôn hiện, kể cả khi ít mốc: màn đầy đủ còn nhóm theo ngày.
            TextButton(
              key: const Key('lich-xem-tat-ca'),
              onPressed: onXemTatCa,
              style: TextButton.styleFrom(
                foregroundColor: HD.accent,
                visualDensity: VisualDensity.compact,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Xem tất cả'),
                  Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: HD.s8),
        if (lich.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: HD.s12),
            child: Text(loiRong, style: HD.body(size: 13, color: HD.inkMuted)),
          )
        else
          for (final (i, e) in lich.take(toiDa).indexed) ...[
            if (i > 0) const SizedBox(height: HD.s8),
            DongSuKien(e: e, onTap: () => onChon(e)),
          ],
      ],
    ),
  );
}

/// Một dòng mốc lịch: ô ngày · icon · việc · nơi · giờ.
class DongSuKien extends StatelessWidget {
  const DongSuKien({super.key, required this.e, this.onTap});

  final SuKienQuanLy e;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, mau) = kieuSuKien(e.loai);
    final t = e.batDau;
    final gio = t == null || !e.coGio
        ? null
        : (e.ketThuc != null ? '${_hm(t)} - ${_hm(e.ketThuc!)}' : _hm(t));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('su-kien-${e.mucLoai}-${e.mucId}-${e.loai}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(HD.r12),
        child: Ink(
          padding: const EdgeInsets.all(HD.s8),
          decoration: BoxDecoration(
            border: Border.all(color: HD.hairline.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(HD.r12),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: HD.s8),
                decoration: BoxDecoration(
                  color: mau.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(HD.r8),
                ),
                child: Column(
                  children: [
                    Text(
                      t == null ? '--/--' : _dm(t),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: mau,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t == null ? '' : thuVN(t),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: mau.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: HD.s12),
              Icon(icon, color: mau, size: 24),
              const SizedBox(width: HD.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.tieuDe,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: HD.ink,
                      ),
                    ),
                    if (e.noi.isNotEmpty)
                      Text(
                        e.noi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HD.body(size: 13, color: HD.inkMuted),
                      ),
                    if (gio != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: HD.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            gio,
                            style: HD.body(size: 13, color: HD.inkSoft),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: HD.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
