import 'package:flutter/material.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/data/models/room_model.dart';
import 'package:house_booking/data/services/tien_ich_phong.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

// ---------------------------------------------------------------------------
// Editorial dialog — used for maintenance + end-maintenance confirmations.
// ---------------------------------------------------------------------------

class EditorialDialog extends StatelessWidget {
  const EditorialDialog({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.confirmLabel,
  });

  final String eyebrow;
  final String title;
  final Widget body;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: HD.paperRaised,
      surfaceTintColor: HD.paperRaised,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: HD.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(HD.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 14, height: 1, color: HD.accent),
                const SizedBox(width: HD.s8),
                Text(eyebrow, style: HD.eyebrow(color: HD.accent)),
              ],
            ),
            const SizedBox(height: HD.s8),
            Text(title,
                style: HD.mastheadItalic(color: HD.ink).copyWith(fontSize: 22)),
            const SizedBox(height: HD.s16),
            body,
            const SizedBox(height: HD.s20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('HUỶ',
                      style: HD.eyebrow(color: HD.inkMuted)),
                ),
                const SizedBox(width: HD.s8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HD.accent,
                    foregroundColor: HD.paperRaised,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: HD.s16, vertical: HD.s12),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(confirmLabel,
                      style: HD.eyebrow(color: HD.paperRaised)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Room masthead — status stamp + code display.
// ---------------------------------------------------------------------------

class RoomMasthead extends StatelessWidget {
  const RoomMasthead({super.key, required this.room});
  final RoomModel room;

  @override
  Widget build(BuildContext context) {
    final tone = switch (room.status) {
      'vacant' => HD.positive,
      'occupied' => HD.accent,
      'maintenance' => HD.warning,
      _ => HD.inkMuted,
    };
    final label = switch (room.status) {
      'vacant' => 'TRỐNG',
      'occupied' => 'ĐANG THUÊ',
      'maintenance' => 'BẢO TRÌ',
      _ => room.status.toUpperCase(),
    };

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HD.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(HD.s20, HD.s20, HD.s20, HD.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 22, height: 1, color: tone),
              const SizedBox(width: HD.s8),
              Text('PHÒNG · MÃ SỐ', style: HD.eyebrow(color: tone)),
            ],
          ),
          const SizedBox(height: HD.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(room.code,
                  style: HD.bigNumeral(color: HD.ink).copyWith(fontSize: 52)),
              const SizedBox(width: HD.s12),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(border: Border.all(color: tone)),
                  child: Text(label,
                      style: HD.eyebrow(color: tone).copyWith(fontSize: 10)),
                ),
              ),
            ],
          ),
          if (room.isMaintenance && room.maintenanceStart != null) ...[
            const SizedBox(height: HD.s8),
            Container(
              padding: const EdgeInsets.fromLTRB(HD.s12, HD.s8, HD.s12, HD.s8),
              decoration: BoxDecoration(
                color: HD.paperRaised,
                border: Border(left: BorderSide(color: HD.warning, width: 2)),
              ),
              child: Text(
                'Bảo trì từ ${room.maintenanceStart}'
                '${room.maintenanceEnd != null ? ' → ${room.maintenanceEnd}' : ''}',
                style: HD.body(size: 12).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fact sheet — key/value rows for room specs.
// ---------------------------------------------------------------------------

class RoomFactSheet extends StatelessWidget {
  const RoomFactSheet({super.key, required this.room});
  final RoomModel room;

  @override
  Widget build(BuildContext context) {
    final doDac = tenTienIch(room.doTrongPhong, kDoTrongPhong);
    final dichVu = tenTienIch(room.dichVuGom, kDichVuGom);
    final rows = <(String, String)>[
      ('GIÁ THUÊ', _formatPrice(room.basePrice)),
      if (room.areaM2 != null)
        ('DIỆN TÍCH', '${room.areaM2!.toStringAsFixed(0)} m²'),
      ('SỨC CHỨA', '${room.capacity} người'),
      // Giá HIỆU LỰC (đã kế thừa từ toà nếu phòng chưa khai) — số này mới là
      // số dùng để tính hoá đơn, nên nó mới là số đáng hiện.
      ('ĐIỆN', '${_gon(room.giaDienHieuLuc)} / kWh'),
      ('NƯỚC', '${_gon(room.giaNuocHieuLuc)} / m³'),
      if (room.phiDichVuHieuLuc > 0)
        (
          'DỊCH VỤ',
          dichVu.isEmpty
              ? '${_gon(room.phiDichVuHieuLuc)} / tháng'
              : '${_gon(room.phiDichVuHieuLuc)} / tháng · ${dichVu.join(", ").toLowerCase()}',
        ),
      if (doDac.isNotEmpty) ('ĐỒ TRONG PHÒNG', doDac.join(', ')),
      if (room.note != null && room.note!.isNotEmpty)
        ('GHI CHÚ', room.note!),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: HD.s20, vertical: HD.s16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HD.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 14, height: 1, color: HD.inkMuted),
              const SizedBox(width: HD.s8),
              Text('THÔNG SỐ', style: HD.eyebrow(color: HD.inkMuted)),
            ],
          ),
          const SizedBox(height: HD.s12),
          for (var i = 0; i < rows.length; i++) ...[
            _FactRow(label: rows[i].$1, value: rows[i].$2),
            if (i < rows.length - 1) const HDHairline(),
          ],
        ],
      ),
    );
  }

  /// Số tiền gọn cho bảng thông số: "3.500đ", "4,5tr".
  static String _gon(double v) => PriceFormat.compact(v);

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(2)} triệu / tháng';
    }
    return '${price.toStringAsFixed(0)} đ / tháng';
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HD.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: HD.eyebrow(color: HD.inkMuted)),
          ),
          Expanded(
            child: Text(value,
                style: HD.tabular(color: HD.ink, size: 14)),
          ),
        ],
      ),
    );
  }
}
