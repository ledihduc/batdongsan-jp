import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/geo_location_service.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Cụm điều khiển bản đồ ở mép phải: định vị + phóng to/thu nhỏ.
///
/// Xếp theo kiểu Google Maps — nút định vị tách riêng phía trên, cặp +/− gộp
/// trong MỘT thẻ có vạch ngăn ở giữa. Chuột trên máy tính không phải lúc nào
/// cũng cuộn-zoom được (trackpad, chuột không con lăn) nên nút +/− không phải
/// đồ trang trí.
class MapControls extends StatefulWidget {
  const MapControls({
    required this.controller,
    this.onLocated,
    super.key,
  });

  final MapController controller;

  /// Gọi sau khi lấy được vị trí — nơi dùng có thể ghim marker "bạn ở đây".
  final ValueChanged<LatLng>? onLocated;

  @override
  State<MapControls> createState() => _MapControlsState();
}

class _MapControlsState extends State<MapControls> {
  final _geo = GeoLocationService();
  bool _dangLay = false;

  Future<void> _dinhVi() async {
    if (_dangLay) return;
    setState(() => _dangLay = true);
    final l = AppLocalizations.of(context);
    final r = await _geo.getCurrentLocation();
    if (!mounted) return;
    setState(() => _dangLay = false);

    if (r.isOk && r.lat != null && r.lng != null) {
      final p = LatLng(r.lat!, r.lng!);
      widget.controller.move(p, 15);
      widget.onLocated?.call(p);
      return;
    }
    // Mỗi trạng thái lỗi một câu khác nhau — "không lấy được vị trí" chung
    // chung khiến người dùng không biết phải làm gì tiếp.
    final msg = switch (r.status) {
      GeoLocationStatus.serviceOff => l.mapLocationOff,
      // Ba nguyên nhân KHÁC NHAU, ba cách sửa khác nhau — xem ghi chú ở
      // HomeMapPreview.
      GeoLocationStatus.insecureContext => l.mapLocationInsecure,
      GeoLocationStatus.denied ||
      GeoLocationStatus.deniedForever =>
        kIsWeb ? l.mapLocationBlocked : l.mapLocationDenied,
      GeoLocationStatus.outOfVietnam => l.mapLocationOutside,
      _ => l.mapLocationError,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _zoom(double delta) {
    final c = widget.controller.camera;
    widget.controller.move(c.center, (c.zoom + delta).clamp(4.0, 18.0));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _the(
          child: _nut(
            tooltip: l.mapMyLocation,
            onTap: _dinhVi,
            child: _dangLay
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, size: 20, color: HD.ink),
          ),
        ),
        const SizedBox(height: 10),
        _the(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _nut(
                tooltip: l.mapZoomIn,
                onTap: () => _zoom(1),
                child: const Icon(Icons.add, size: 20, color: HD.ink),
              ),
              // Vạch ngăn thụt hai đầu — dấu hiệu "hai nút, một thẻ".
              const SizedBox(
                width: 26,
                child: Divider(height: 1, thickness: 1, color: HD.hairline),
              ),
              _nut(
                tooltip: l.mapZoomOut,
                onTap: () => _zoom(-1),
                child: const Icon(Icons.remove, size: 20, color: HD.ink),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _the({required Widget child}) => Material(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r8),
        elevation: 3,
        child: child,
      );

  Widget _nut({
    required String tooltip,
    required VoidCallback onTap,
    required Widget child,
  }) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(HD.r8),
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Center(child: child)),
        ),
      );
}
