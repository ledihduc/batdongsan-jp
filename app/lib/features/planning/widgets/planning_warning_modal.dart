import 'package:flutter/material.dart';
import 'package:house_booking/data/models/planning_parcel_model.dart';
import 'package:house_booking/data/services/planning_service.dart';
import 'package:house_booking/features/planning/analytics/planning_events.dart';
import 'package:house_booking/features/planning/report/report_error_screen.dart';
import 'package:house_booking/features/planning/utils/risky_zone_codes.dart';
import 'package:house_booking/features/planning/widgets/disclaimer_banner.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Modal kiểm tra quy hoạch — hiển thị từ post_house_screen khi user tap
/// "Kiểm tra quy hoạch".
///
/// - Fetch fresh mỗi lần mở (AC-15: không cache stale).
/// - Nếu vùng rủi ro: banner amber + log analytics (một lần duy nhất).
/// - D4: modal KHÔNG block submit — chỉ cảnh báo.
/// - PlanningService khởi tạo cục bộ (không trong global Provider).
class PlanningWarningModal extends StatefulWidget {
  final double lat;
  final double lng;

  const PlanningWarningModal({
    required this.lat,
    required this.lng,
    super.key,
  });

  @override
  State<PlanningWarningModal> createState() => _PlanningWarningModalState();
}

class _PlanningWarningModalState extends State<PlanningWarningModal> {
  final _service = PlanningService();

  ParcelDetail? _parcel;
  String? _error;
  bool _loading = true;
  // Flag để chỉ log analytics một lần — không log trong build.
  bool _analyticsLogged = false;

  @override
  void initState() {
    super.initState();
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
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.planWarnTitle),
      content: _buildContent(),
      actions: [
        // Link báo cáo — chỉ hiện khi parcel đã load (có parcelId) (US-08).
        if (_parcel != null)
          TextButton(
            onPressed: () {
              final parcelId = _parcel!.parcelId;
              Navigator.of(context).pop(); // đóng modal trước
              // Push ReportErrorScreen sau khi modal đóng
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReportErrorScreen(parcelId: parcelId),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade600,
            ),
            child: Text(l.planWarnReport),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.planWarnOk),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final l = AppLocalizations.of(context);
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Text(l.planWarnLoadError(_error!));
    }

    if (_parcel == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.planWarnNotFound),
          const SizedBox(height: 8),
          const DisclaimerBanner(compact: true),
        ],
      );
    }

    final isRisky = RiskyZoneCodes.isRisky(_parcel!.zoneCode);

    // Log analytics một lần — không gọi trong build trực tiếp (dùng flag).
    if (isRisky && !_analyticsLogged) {
      _analyticsLogged = true;
      // Dùng addPostFrameCallback để tránh side effect trong build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PlanningAnalytics.logRiskyWarning(_parcel!.zoneCode);
      });
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRisky)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.amber.shade800, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.planWarnRisky(
                          _parcel!.zoneName ?? _parcel!.zoneCode ?? "—"),
                      style: TextStyle(
                          color: Colors.amber.shade900, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Colors.green.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.planWarnSuitable,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _infoRow(
              l.planWarnZoneLabel,
              '${_parcel!.zoneName ?? "—"}'
              ' (${_parcel!.zoneCode ?? "—"})'),
          if (_parcel!.areaM2 != null)
            _infoRow(
                l.planWarnAreaLabel, '${_parcel!.areaM2!.toStringAsFixed(1)} m²'),
          if (_parcel!.district != null)
            _infoRow(l.planWarnDistrictLabel, _parcel!.district!),
          const SizedBox(height: 8),
          const DisclaimerBanner(compact: true),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: HD.inkMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
