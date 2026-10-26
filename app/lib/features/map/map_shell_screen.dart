import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/router/deferred_route_widget.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/services/planning_service.dart';
import 'package:house_booking/data/services/geo_location_service.dart';
import 'package:house_booking/features/map/map_screen.dart';

// Chunk quy hoạch nặng (flutter_map + vector_map_tiles) — chỉ tải khi user
// bấm sang mode "Quy hoạch" lần đầu. Mọi reference tới symbol của 2 lib này
// PHẢI nằm trong builder của DeferredRouteWidget (xem note ở lib đó).
import 'package:house_booking/features/planning/planning_map_screen.dart'
    deferred as planning_screen;
import 'package:house_booking/features/planning/providers/planning_map_provider.dart'
    deferred as planning_provider;

enum MapMode { listings, planning }

/// Màn hình bản đồ gộp: 1 page, toggle giữa "Nhà đăng" và "Quy hoạch".
///
/// Dùng chung cho cả route `/map` (mở mode listings) và `/planning`
/// (mở mode planning, hỗ trợ deep-link ?lat=&lng=&zoom=). Phần quy hoạch
/// được lazy-load qua [DeferredRouteWidget] khi user chuyển sang mode đó.
class MapShellScreen extends StatefulWidget {
  const MapShellScreen({
    super.key,
    this.initialMode = MapMode.listings,
    this.initialCenter,
    this.houseMarker = false,
    this.initialZoom,
    this.focusHouseId,
  });

  final MapMode initialMode;

  /// Deep-link quy hoạch (mở từ house detail): tâm bản đồ + marker nhà.
  final LatLng? initialCenter;
  final bool houseMarker;
  final double? initialZoom;

  /// Tin cần LÀM NỔI khi mở bản đồ. Chỉ đưa toạ độ là chưa đủ: bản đồ chỉ tải
  /// một trang tin, tin được chỉ đích danh rất thường KHÔNG nằm trong đó — người
  /// dùng tới đúng chỗ mà chẳng thấy ghim nào, tưởng bấm hụt.
  final int? focusHouseId;

  @override
  State<MapShellScreen> createState() => _MapShellScreenState();
}

class _MapShellScreenState extends State<MapShellScreen> {
  late MapMode _mode = widget.initialMode;
  final _geo = const GeoLocationService();
  LatLng? _currentLocation;
  bool _locating = false;

  // Khi true, mode quy hoạch đã được dựng ít nhất một lần → giữ trong
  // IndexedStack để không phải tải/dựng lại khi toggle qua lại.
  bool _planningMounted = false;

  @override
  void initState() {
    super.initState();
    // `/planning` không truyền tọa độ nghĩa là người dùng mở từ ô
    // "Thông tin và quy hoạch". Lấy vị trí trước khi dựng map để
    // MapOptions nhận đúng initialCenter ngay lần đầu, đồng thời provider tự
    // chọn đúng tỉnh và bật raster quy hoạch của tỉnh đó.
    if (widget.initialMode == MapMode.planning &&
        widget.initialCenter == null) {
      _locating = true;
      _locateForPlanning();
    }
  }

  Future<void> _locateForPlanning() async {
    final result = await _geo.getCurrentLocation(chinhXacCao: true);
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (result.isOk && result.lat != null && result.lng != null) {
        _currentLocation = LatLng(result.lat!, result.lng!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == MapMode.planning) _planningMounted = true;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: HD.accent,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: SegmentedButton<MapMode>(
          segments: [
            const ButtonSegment(
              value: MapMode.listings,
              label: Text('Nhà đăng'),
              icon: Icon(Icons.home_outlined),
            ),
            ButtonSegment(
              value: MapMode.planning,
              // Nhãn NGẮN vì segment hẹp — tên đầy đủ ở tiêu đề màn/hub.
              label: Text(AppLocalizations.of(context).planningTabShort),
              icon: const Icon(Icons.map_outlined),
            ),
          ],
          selected: {_mode},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _mode = s.first),
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith(
              (st) =>
                  st.contains(WidgetState.selected) ? HD.accent : Colors.white,
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (st) => st.contains(WidgetState.selected)
                  ? Colors.white
                  : Colors.transparent,
            ),
            side: WidgetStateProperty.all(
              const BorderSide(color: Colors.white70),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _mode == MapMode.listings ? 0 : 1,
        children: [
          MapScreen(
            embedded: true,
            // Chỉ áp cho chế độ tin đăng: mở /planning?lat=… là muốn xem quy
            // hoạch ở đó, không phải xem tin ở đó.
            initialCenter: widget.initialMode == MapMode.listings
                ? widget.initialCenter
                : null,
            initialZoom: widget.initialMode == MapMode.listings
                ? widget.initialZoom
                : null,
            focusHouseId: widget.focusHouseId,
          ),
          _planningMounted
              ? (_locating ? _locationLoading() : _buildPlanning())
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildPlanning() {
    final center = widget.initialCenter ?? _currentLocation;
    return DeferredRouteWidget(
      loadLibrary: () => Future.wait([
        planning_screen.loadLibrary(),
        planning_provider.loadLibrary(),
      ]),
      builder: (_) => ChangeNotifierProvider(
        create: (_) => planning_provider.PlanningMapProvider(PlanningService()),
        child: planning_screen.PlanningMapScreen(
          embedded: true,
          initialCenter: center,
          houseMarker: widget.houseMarker,
          myLocationMarker:
              widget.initialCenter == null && _currentLocation != null,
          initialZoom: widget.initialZoom,
        ),
      ),
    );
  }

  Widget _locationLoading() => const ColoredBox(
    color: Color(0xfff7f9fc),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: HD.accent),
          SizedBox(height: 14),
          Text(
            'Đang xác định vị trí để mở bản đồ quy hoạch…',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}
