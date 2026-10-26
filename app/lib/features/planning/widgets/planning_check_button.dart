import 'package:flutter/material.dart';
import 'package:house_booking/features/planning/analytics/planning_events.dart';
import 'package:house_booking/features/planning/widgets/planning_warning_modal.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Nút "Thông tin và quy hoạch" trong post_house_screen.
///
/// - Disabled khi lat/lng null hoặc = 0 (chưa nhập địa chỉ).
/// - Tooltip "Nhập địa chỉ trước" khi disabled.
/// - Tap → showDialog(PlanningWarningModal).
/// - D4: nút này KHÔNG ảnh hưởng đến submit button của form.
class PlanningCheckButton extends StatelessWidget {
  /// Tọa độ lat/lng lấy từ state của PostHouseScreen.
  /// null nếu chưa có tọa độ (geocoding chưa chạy).
  final double? lat;
  final double? lng;

  const PlanningCheckButton({this.lat, this.lng, super.key});

  bool get _enabled =>
      lat != null && lng != null && lat != 0.0 && lng != 0.0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Tooltip(
      // TODO(i18n): AppLocalizations.of(context)!.planningCheckRequireAddress
      message: _enabled ? '' : 'Nhập địa chỉ trước',
      child: OutlinedButton.icon(
        icon: const Icon(Icons.map_outlined, size: 18),
        label: Text(l.planningCheckAction),
        onPressed: _enabled ? () => _show(context) : null,
      ),
    );
  }

  Future<void> _show(BuildContext ctx) async {
    PlanningAnalytics.logCheckButtonTap();
    await showDialog<void>(
      context: ctx,
      builder: (_) => PlanningWarningModal(lat: lat!, lng: lng!),
    );
  }
}
