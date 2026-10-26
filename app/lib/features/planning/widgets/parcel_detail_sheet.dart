import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/data/models/planning_parcel_model.dart';
import 'package:house_booking/features/planning/providers/planning_map_provider.dart';
import 'package:house_booking/features/planning/report/report_error_screen.dart';
import 'package:house_booking/features/planning/utils/zone_color_resolver.dart';
import 'package:house_booking/features/planning/widgets/disclaimer_banner.dart';

// i18n: TODO(i18n) — thay bằng AppLocalizations khi setup ARB.
const _kFreshnessWarning = 'Dữ liệu cũ hơn 30 ngày — cần đối chiếu thêm';
const _kReportBtn = 'Báo cáo dữ liệu sai';
const _kNoData = '—';

/// Bottom sheet chi tiết thửa đất (AC-02, AC-09, AC-12, AC-15).
/// Dùng DraggableScrollableSheet để user kéo xem thêm.
class ParcelDetailSheet extends StatelessWidget {
  const ParcelDetailSheet({super.key, required this.parcel});

  final ParcelDetail parcel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.4, 0.7, 0.9],
      builder: (ctx, scrollCtrl) {
        return Material(
          elevation: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          color: Theme.of(context).colorScheme.surface,
          child: SingleChildScrollView(
            controller: scrollCtrl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header: zone name + chip màu + nút đóng
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      // Chip màu quy hoạch
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: resolveZoneColor(parcel.zoneColor,
                              dark: isDark),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade400,
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          parcel.zoneName ?? parcel.zoneCode ?? 'Quy hoạch',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Nút đóng (AC-12 — tap target ≥ 48dp)
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              context.read<PlanningMapProvider>().dismissSheet(),
                          tooltip: 'Đóng',
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 16),

                // Chi tiết thửa
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                        icon: Icons.straighten,
                        label: 'Diện tích',
                        value: parcel.areaM2 != null
                            ? '${parcel.areaM2!.toStringAsFixed(1)} m²'
                            : _kNoData,
                      ),
                      _InfoRow(
                        icon: Icons.location_city,
                        label: 'Quận/Huyện',
                        value: parcel.district ?? _kNoData,
                      ),
                      _InfoRow(
                        icon: Icons.pin_drop_outlined,
                        label: 'Tờ / Thửa',
                        value:
                            '${parcel.sheetNo ?? _kNoData} / ${parcel.parcelNo ?? _kNoData}',
                      ),
                      _InfoRow(
                        icon: Icons.map_outlined,
                        label: 'Mã vùng',
                        value: parcel.zoneCode ?? _kNoData,
                      ),

                      const SizedBox(height: 8),

                      // Freshness (AC-15)
                      _FreshnessRow(fetchedAt: parcel.fetchedAt),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // Disclaimer (AC-09)
                const DisclaimerBanner(compact: true),

                const SizedBox(height: 8),

                // Nút báo cáo — P07 screen chưa có, dùng Snackbar placeholder
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.flag_outlined, size: 16),
                      label: const Text(_kReportBtn),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: () => _onReport(context, parcel.parcelId),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onReport(BuildContext context, String parcelId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportErrorScreen(parcelId: parcelId),
      ),
    );
  }
}

/// Một hàng thông tin trong sheet chi tiết.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hàng hiển thị ngày cập nhật + warning nếu > 30 ngày (AC-15).
class _FreshnessRow extends StatelessWidget {
  const _FreshnessRow({required this.fetchedAt});

  final DateTime fetchedAt;

  @override
  Widget build(BuildContext context) {
    final daysSince = DateTime.now().difference(fetchedAt).inDays;
    final isStale = daysSince > 30;

    final dateStr =
        '${fetchedAt.day.toString().padLeft(2, '0')}/${fetchedAt.month.toString().padLeft(2, '0')}/${fetchedAt.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.update, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'Cập nhật: $dateStr',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        if (isStale) ...[
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 14, color: Colors.amber.shade800),
                const SizedBox(width: 4),
                Text(
                  _kFreshnessWarning,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
