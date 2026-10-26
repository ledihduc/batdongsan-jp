import 'dart:async';
import 'package:house_booking/core/config/brand.dart';
import 'package:house_booking/features/map/widgets/base_map_tile_layer.dart';
import 'package:house_booking/core/widgets/ds.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart'
    as vtr
    show ThemeReader, Theme;

import 'package:house_booking/core/config/env.dart';
import 'package:house_booking/features/planning/providers/planning_map_provider.dart';
import 'package:house_booking/features/planning/widgets/disclaimer_banner.dart';
import 'package:house_booking/features/planning/widgets/error_card.dart';
import 'package:house_booking/features/planning/widgets/layer_control_panel.dart';
import 'package:house_booking/features/planning/widgets/loading_skeleton.dart';
import 'package:house_booking/features/planning/widgets/parcel_detail_sheet.dart';
import 'package:house_booking/features/planning/utils/zone_color_resolver.dart';
import 'package:house_booking/features/planning/widgets/planning_zone_legend.dart';
import 'package:house_booking/features/map/widgets/trackpad_pan_zoom.dart';
import 'package:house_booking/features/planning/widgets/province_picker.dart';
import 'package:house_booking/l10n/app_localizations.dart';

// Source ID khớp với key trong TileProviders và `source` trong theme JSON.
const String _kSourceId = 'planning-parcels';

// Tên source layer trong MVT protobuf từ Martin.
const String _kSourceLayer = 'parcels';

// Trung tâm mặc định — Bến Thành (HCMC). Có thể đổi sau khi user pick province.
const LatLng _kDefaultCenter = LatLng(10.7769, 106.7009);

/// Màn hình tra cứu quy hoạch đầy đủ.
/// [initialCenter] dùng khi mở từ house detail (P06) để fly-to vị trí BDS.
/// [houseMarker] = true → hiển thị marker nhà tại [initialCenter].
/// [initialZoom] override default 14 — dùng khi mở từ deep-link share (zoom=16).
class PlanningMapScreen extends StatefulWidget {
  const PlanningMapScreen({
    super.key,
    this.initialCenter,
    this.houseMarker = false,
    this.myLocationMarker = false,
    this.initialZoom,
    this.embedded = false,
  });

  final LatLng? initialCenter;

  /// Khi true, chỉ render phần body (không Scaffold/AppBar riêng) để nhúng
  /// vào [MapShellScreen] — shell tự quản AppBar + toggle mode.
  final bool embedded;

  /// Khi true, vẽ marker nhà tại [initialCenter] (dùng khi mở từ house detail).
  final bool houseMarker;

  /// Vị trí do GPS vừa trả về khi mở từ ô "Thông tin và quy hoạch". Dùng
  /// marker chữ thập riêng, không giả thành ghim của một căn nhà.
  final bool myLocationMarker;

  /// Override zoom level mặc định (14). Null = dùng default.
  final double? initialZoom;

  @override
  State<PlanningMapScreen> createState() => _PlanningMapScreenState();
}

class _PlanningMapScreenState extends State<PlanningMapScreen> {
  final _mapController = MapController();

  LatLng? _selectedLocationMarker;

  // Lưu tọa độ tap cuối để retry (AC-07)
  double? _lastTapLat;
  double? _lastTapLng;

  /// MapOptions dựng MỘT LẦN. flutter_map so options ở didUpdateWidget và thay
  /// cả camera khi thấy khác; các callback ở đây là closure nên dựng lại mỗi
  /// lần build sẽ luôn "khác" → camera bị thay giữa cử chỉ, bản đồ không phóng
  /// to được. Màn này rebuild mỗi lần provider báo có dữ liệu thửa mới.
  late final MapOptions _mapOptions = MapOptions(
    initialCenter: widget.initialCenter ?? _kDefaultCenter,
    initialZoom: widget.initialZoom ?? 14,
    minZoom: 4,
    maxZoom: 18,
    interactionOptions: const InteractionOptions(flags: kMapInteractiveFlags),
    onTap: (tapPosition, latLng) {
      _lastTapLat = latLng.latitude;
      _lastTapLng = latLng.longitude;
      context.read<PlanningMapProvider>().tapParcel(
        latLng.latitude,
        latLng.longitude,
      );
    },
    onPositionChanged: (camera, hasGesture) => _scheduleMapSettled(),
  );

  // Vector tile provider — khởi tạo một lần, tái dùng
  late final TileProviders _tileProviders;
  late final vtr.Theme _vectorTheme;

  // Debounce fetch bbox cho web fallback (PolygonLayer).
  Timer? _bboxDebounce;

  // Theo dõi noResultTick để show SnackBar khi tap miss.
  int _lastNoResultTick = 0;

  // Theo dõi outOfBboxTick để show SnackBar khi tap/search ngoài VN.
  int _lastOutOfBboxTick = 0;

  @override
  void initState() {
    super.initState();
    // vector_map_tiles cần path_provider.getTemporaryDirectory() —
    // không hỗ trợ Flutter web. Trên web chỉ render base OSM,
    // tap-to-lookup vẫn gọi API như bình thường.
    if (!kIsWeb) {
      _tileProviders = TileProviders({
        _kSourceId: NetworkVectorTileProvider(
          urlTemplate: Env.martinTileUrl,
          maximumZoom: 16,
        ),
      });
      _vectorTheme = _buildVectorTheme();
    } else {
      // Web: fetch bbox lần đầu sau khi map mount xong.
      WidgetsBinding.instance.addPostFrameCallback((_) => _onMapSettled());
    }
    // Auto-pick province tại initialCenter để overlay hiện ngay khi vào map
    // (thay vì chờ user bấm picker pill).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final center = widget.initialCenter ?? _kDefaultCenter;
      context.read<PlanningMapProvider>().autoSelectProvinceForPoint(
        center.latitude,
        center.longitude,
      );
    });
  }

  // Mỗi khi map di chuyển ổn định: (web) fetch parcels bbox + (mọi nền) dò lại
  // tỉnh theo TÂM để tự đổi overlay quy hoạch sang tỉnh đang xem.
  void _scheduleMapSettled() {
    _bboxDebounce?.cancel();
    _bboxDebounce = Timer(const Duration(milliseconds: 350), _onMapSettled);
  }

  void _onMapSettled() {
    if (!mounted) return;
    final provider = context.read<PlanningMapProvider>();
    final center = _mapController.camera.center;
    provider.updateProvinceForCenter(center.latitude, center.longitude);
    if (kIsWeb) {
      final bounds = _mapController.camera.visibleBounds;
      provider.fetchParcelsInBbox(
        west: bounds.west,
        south: bounds.south,
        east: bounds.east,
        north: bounds.north,
      );
    }
  }

  /// Convert một GeoJSON feature (Polygon | MultiPolygon) thành flutter_map Polygons.
  /// Color lấy từ zone_color (fallback xanh dương).
  List<Polygon> _featureToPolygons(Map<String, dynamic> f) {
    final geom = f['geometry'] as Map<String, dynamic>?;
    if (geom == null) return const [];
    final props =
        (f['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
    final color = parseZoneHex(props['zone_color'] as String?);
    final fill = color.withValues(alpha: kZoneFillAlpha);
    final border = color.withValues(alpha: 0.9);

    final type = geom['type'] as String?;
    final coords = geom['coordinates'] as List?;
    if (coords == null) return const [];

    List<Polygon> out = [];
    if (type == 'Polygon') {
      out.addAll(_ringsToPolygons(coords, fill, border));
    } else if (type == 'MultiPolygon') {
      for (final poly in coords) {
        if (poly is List) {
          out.addAll(_ringsToPolygons(poly, fill, border));
        }
      }
    }
    return out;
  }

  List<Polygon> _ringsToPolygons(List rings, Color fill, Color border) {
    if (rings.isEmpty) return const [];
    final outer = rings.first;
    if (outer is! List) return const [];
    final points = outer
        .whereType<List>()
        .where((p) => p.length >= 2)
        .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
        .toList();
    if (points.length < 3) return const [];
    return [
      Polygon(
        points: points,
        color: fill,
        borderColor: border,
        borderStrokeWidth: 1.2,
      ),
    ];
  }

  @override
  void dispose() {
    _bboxDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Consumer<PlanningMapProvider>(
      builder: (context, provider, _) {
        // Show transient SnackBar khi tap không trúng parcel.
        if (provider.noResultTick != _lastNoResultTick) {
          _lastNoResultTick = provider.noResultTick;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final messenger = ScaffoldMessenger.maybeOf(context);
            messenger?.clearSnackBars();
            messenger?.showSnackBar(
              const SnackBar(
                content: Text('Không có thông tin quy hoạch tại điểm này.'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          });
        }
        // Show transient SnackBar khi tap/search rơi ngoài VN bbox.
        if (provider.outOfBboxTick != _lastOutOfBboxTick) {
          _lastOutOfBboxTick = provider.outOfBboxTick;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final messenger = ScaffoldMessenger.maybeOf(context);
            messenger?.clearSnackBars();
            messenger?.showSnackBar(
              const SnackBar(
                content: Text('Vị trí ngoài lãnh thổ Việt Nam.'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          });
        }
        return Stack(
          children: [
            // Lớp 1: FlutterMap
            TrackpadPanZoom(
              controller: _mapController,
              child: FlutterMap(
                mapController: _mapController,
                options: _mapOptions,
                children: [
                  // Nền OSM raster.
                  // Note: trên web Chrome log warning "Refused to set unsafe
                  // header User-Agent" — flutter_map luôn set header này,
                  // browser ignore nên tiles vẫn tải bình thường. Không fix được.
                  lopTileNen(),
                  // Raster overlay quy hoạch theo tỉnh (Guland tiles, native z8-17).
                  // Backend proxy CDN Guland + cache local (xem guland_tile_proxy.py).
                  if (provider.planningLayerVisible &&
                      provider.selectedProvince?.hasTiles == true &&
                      provider.selectedProvince?.tileLayerSlug != null)
                    Opacity(
                      opacity: provider.layerOpacity,
                      child: lopTileQuyHoach(
                        Env.planningRasterTileUrl(
                          provider.selectedProvince!.tileLayerSlug!,
                        ),
                      ),
                    ),
                  // Native: vector tile overlay (Martin MVT).
                  if (!kIsWeb && provider.planningLayerVisible)
                    Opacity(
                      opacity: provider.layerOpacity,
                      child: VectorTileLayer(
                        tileProviders: _tileProviders,
                        theme: _vectorTheme,
                      ),
                    ),
                  // Web: PolygonLayer fallback từ GeoJSON bbox API
                  // (vector_map_tiles cần path_provider.getTemporaryDirectory
                  // — chưa hỗ trợ Flutter web).
                  if (kIsWeb &&
                      provider.planningLayerVisible &&
                      provider.bboxFeatures.isNotEmpty)
                    Opacity(
                      opacity: provider.layerOpacity,
                      child: PolygonLayer(
                        polygons: [
                          for (final f in provider.bboxFeatures)
                            ..._featureToPolygons(f),
                        ],
                      ),
                    ),
                  // Attribution bắt buộc
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('© OpenStreetMap contributors'),
                      TextSourceAttribution(
                        'Dữ liệu quy hoạch — ${Brand.name}',
                      ),
                    ],
                  ),
                  // Marker nhà — chỉ hiển thị khi mở từ house detail (P06).
                  if (widget.houseMarker && widget.initialCenter != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: widget.initialCenter!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.home,
                            color: Colors.red,
                            size: 36,
                            shadows: [
                              Shadow(
                                color: Colors.black38,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  if (widget.myLocationMarker && widget.initialCenter != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: widget.initialCenter!,
                          width: MarkerViTriToi.hopCho(24),
                          height: MarkerViTriToi.hopCho(24),
                          child: const MarkerViTriToi(),
                        ),
                      ],
                    ),
                  if (_selectedLocationMarker != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocationMarker!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 38,
                            shadows: [
                              Shadow(
                                color: Colors.black38,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Lớp 2: Province picker pill (góc trái trên)
            // Bottom sheet gộp 2 nhóm kết quả: tỉnh/thành + địa chỉ Nominatim.
            // Tránh đặt search bar riêng ở top vì sẽ chồng tap area lên pill
            // và layer panel.
            Positioned(
              top: 8,
              left: 8,
              child: ProvincePicker(
                onPick: (center, province) {
                  setState(() {
                    _selectedLocationMarker = null;
                  });
                  // Zoom phù hợp với mức tile có sẵn (Guland tới z18).
                  _mapController.move(center, 12);
                },
                onAddressPick: (pos) {
                  setState(() {
                    _selectedLocationMarker = pos;
                  });
                  // Zoom sát hơn cho địa chỉ cụ thể (street level).
                  _mapController.move(pos, 16);
                },
              ),
            ),

            // Lớp 3: Điều khiển lớp quy hoạch — thanh độ mờ DỌC bám mép
            // phải. Chừa top 8 (không đụng gì) và bottom 56 để tránh đè
            // DisclaimerBanner; Align giữ panel co theo nội dung nhưng vẫn
            // cho LayoutBuilder biết chiều cao khả dụng.
            const Positioned(
              right: 8,
              top: 8,
              bottom: 56,
              child: Align(
                alignment: Alignment.centerRight,
                child: LayerControlPanel(),
              ),
            ),

            // Lớp 3b: Chú giải LỚP QUY HOẠCH (góc trái dưới, trên banner).
            // Chỉ hiện khi lớp đang bật — tắt lớp thì không còn màu để giải
            // thích.
            if (provider.planningLayerVisible)
              Positioned(
                left: 8,
                bottom: 56,
                child: PlanningZoneLegend(
                  features: provider.bboxFeatures,
                  // Raster tile của tỉnh không kèm dữ liệu loại đất.
                  rasterSource:
                      provider.selectedProvince?.hasTiles == true &&
                      provider.selectedProvince?.tileLayerSlug != null,
                ),
              ),

            // Lớp 4: Disclaimer banner (footer)
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: DisclaimerBanner(),
            ),

            // Lớp 5: Loading skeleton (AC-08)
            if (provider.state == MapState.loading) const LoadingSkeleton(),

            // Lớp 6: Error card (AC-07) — chỉ cho lỗi network/server
            if (provider.state == MapState.error &&
                provider.errorMessage != null)
              ErrorCard(
                errorMessage: provider.errorMessage!,
                retryCount: provider.retryCount,
                lastTapLat: _lastTapLat,
                lastTapLng: _lastTapLng,
              ),

            // Lớp 7: Parcel detail sheet (AC-02, AC-09, AC-15)
            if (provider.selectedParcel != null)
              ParcelDetailSheet(parcel: provider.selectedParcel!),
          ],
        );
      },
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: DsAppBar(
        title: AppLocalizations.of(context).planningScreenTitle,
        background: HD.accent,
        foreground: Colors.white,
      ),
      body: body,
    );
  }

  /// Build vector theme theo cùng cách POC (ThemeReader + MapLibre JSON).
  /// Không dùng LayerType.fill() — API đó không tồn tại trong vector_map_tiles 8.0.0.
  vtr.Theme _buildVectorTheme() {
    return vtr.ThemeReader().read(_planningThemeJson());
  }

  Map<String, dynamic> _planningThemeJson() {
    return {
      'id': 'planning-full',
      'layers': [
        {
          'id': 'parcels-fill',
          'type': 'fill',
          'source': _kSourceId,
          'source-layer': _kSourceLayer,
          'paint': {
            'fill-color': 'rgba(66, 135, 245, 0.35)',
            'fill-opacity': 0.8,
          },
        },
        {
          'id': 'parcels-outline',
          'type': 'line',
          'source': _kSourceId,
          'source-layer': _kSourceLayer,
          'paint': {'line-color': 'rgba(30, 90, 200, 0.9)', 'line-width': 1.5},
        },
      ],
    };
  }
}
