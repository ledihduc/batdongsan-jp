import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:house_booking/data/models/planning_parcel_model.dart';
import 'package:house_booking/data/services/planning_service.dart';
import 'package:house_booking/features/planning/analytics/planning_events.dart';
import 'package:house_booking/features/planning/utils/risky_zone_codes.dart';

/// Badge hiển thị thông tin quy hoạch dưới title/address trên house_detail_screen.
///
/// - Load async — KHÔNG block render house detail.
/// - Nếu API fail: ẩn badge (SizedBox.shrink), KHÔNG throw (AC-04).
/// - Tap → mở /tra-quy-hoach zoom 16 tại vị trí BDS.
/// - PlanningService được khởi tạo cục bộ vì service KHÔNG được register
///   trong global providers (per P04 design) — coi đây là kết quả mong đợi
///   cho MVP; future refactor có thể register global nếu cần.
class PlanningBadge extends StatefulWidget {
  final double lat;
  final double lng;

  const PlanningBadge({required this.lat, required this.lng, super.key});

  @override
  State<PlanningBadge> createState() => _PlanningBadgeState();
}

class _PlanningBadgeState extends State<PlanningBadge> {
  // Khởi tạo cục bộ — PlanningService không nằm trong global Provider tree.
  final _service = PlanningService();

  ParcelDetail? _parcel;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Guard: tọa độ (0, 0) là giá trị mặc định không hợp lệ — bỏ qua.
    if (widget.lat == 0 && widget.lng == 0) {
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final result =
          await _service.getParcelByPoint(widget.lat, widget.lng);
      if (mounted) {
        setState(() {
          _parcel = result;
          _loading = false;
        });
      }
    } catch (_) {
      // Fail silently — AC-04: badge không được crash house detail.
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openMap() {
    PlanningAnalytics.logBadgeTap(_parcel?.zoneCode);
    // Dùng go_router với query params → URL share được, browser back/forward
    // hoạt động đúng, và chunk planning_map chỉ tải khi route resolve.
    context.push(
      '/planning?lat=${widget.lat}&lng=${widget.lng}&zoom=16',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // Placeholder mỏng — không làm layout shift (Risk: badge async chớp nháy).
      return const SizedBox(
        height: 28,
        width: 140,
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    // API fail hoặc không tìm thấy thửa — ẩn hoàn toàn.
    if (_parcel == null) return const SizedBox.shrink();

    final isRisky = RiskyZoneCodes.isRisky(_parcel!.zoneCode);
    final bgColor =
        isRisky ? Colors.amber.shade100 : Colors.green.shade100;
    final fgColor =
        isRisky ? Colors.amber.shade900 : Colors.green.shade900;

    return InkWell(
      onTap: _openMap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 16, color: fgColor),
            const SizedBox(width: 6),
            Text(
              // TODO(i18n): AppLocalizations.of(context)!.planningBadgeLabel(zoneName)
              'Quy hoạch: ${_parcel!.zoneName ?? "—"}',
              style: TextStyle(fontSize: 12, color: fgColor),
            ),
          ],
        ),
      ),
    );
  }
}
