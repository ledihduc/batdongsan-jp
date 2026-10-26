import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:house_booking/features/map/widgets/base_map_tile_layer.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Bản đồ tin đăng của một người bán ("Bản đồ điểm chốt").
///
/// Dùng ở hai chỗ với mức tương tác KHÁC NHAU — đó là cả điểm mấu chốt:
///   * [BrokerDealMap] nhúng trong hồ sơ: cho PHÓNG TO (chụm 2 ngón, chạm đúp,
///     nút +/−) nhưng KHÔNG cho kéo bằng một ngón. Lý do: bản đồ nằm giữa một
///     trang cuộn dọc; nếu bắt cả cử chỉ kéo thì người dùng vuốt qua bản đồ sẽ
///     không cuộn được trang nữa — lỗi kinh điển của map nhúng.
///   * [BrokerDealMapScreen] toàn màn hình: mở đầy đủ mọi cử chỉ, vì lúc đó
///     không còn trang nào để cuộn.
/// Chạm ghim → mở tin đó.
class BrokerDealMap extends StatefulWidget {
  const BrokerDealMap({
    super.key,
    required this.houses,
    required this.hostName,
    this.height = 220,
    this.fullScreen = false,
  });

  final List<HouseModel> houses;
  final String hostName;
  final double height;

  /// true = mọi cử chỉ (kéo, xoay bằng 2 ngón, cuộn chuột) đều bật.
  final bool fullScreen;

  @override
  State<BrokerDealMap> createState() => BrokerDealMapState();
}

class BrokerDealMapState extends State<BrokerDealMap> {
  final MapController _ctrl = MapController();

  /// Khung nhìn ban đầu, tính MỘT LẦN cho lần layout đầu tiên có kích thước
  /// thật. Không tính lại khi ràng buộc đổi (xoay máy, đổi cỡ cửa sổ trên web,
  /// bàn phím bật lên): tính lại sẽ dựng `MapOptions` mới và ĐẨY camera về
  /// khung ban đầu — người dùng đang phóng to xem một khu thì bị văng ra ngoài.
  ({LatLng tam, double zoom})? _khungDaTinh;

  List<HouseModel> get _pins => widget.houses
      .where((h) => h.latitude != null && h.longitude != null)
      .toList(growable: false);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Tâm + mức phóng để MỌI ghim lọt trong khung [w]×[h].
  ///
  /// Tự tính thay vì gọi `fitCamera` sau khi dựng: `fitCamera` phụ thuộc kích
  /// thước mà camera ĐANG nghĩ mình có, và trong ListView/Column kích thước đó
  /// còn cũ ở lượt layout đầu → tile chỉ được vẽ trong một ô nhỏ giữa khung,
  /// còn ghim thì trải đúng chỗ (đã gặp đúng lỗi này). Tính sẵn rồi truyền qua
  /// `initialCenter`/`initialZoom` thì không còn phụ thuộc thời điểm nào cả.
  ({LatLng tam, double zoom}) _khungBanDau(
    List<LatLng> diem,
    double w,
    double h,
  ) {
    final lats = diem.map((d) => d.latitude);
    final lngs = diem.map((d) => d.longitude);
    final minLat = lats.reduce(math.min), maxLat = lats.reduce(math.max);
    final minLng = lngs.reduce(math.min), maxLng = lngs.reduce(math.max);
    final tam = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    if (diem.length == 1) return (tam: tam, zoom: 14);

    // Web Mercator: tìm zoom LỚN NHẤT mà khung bao vẫn lọt, chừa lề 48px.
    double worldY(double lat) {
      final r = lat * math.pi / 180;
      return (1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2;
    }

    final dx = (maxLng - minLng) / 360;
    final dy = (worldY(minLat) - worldY(maxLat)).abs();
    final wUse = math.max(64.0, w - 96), hUse = math.max(64.0, h - 96);
    for (var z = 16.0; z >= 3; z -= 0.5) {
      final worldPx = 256 * math.pow(2, z);
      if (dx * worldPx <= wUse && dy * worldPx <= hUse) {
        return (tam: tam, zoom: z);
      }
    }
    return (tam: tam, zoom: 3);
  }

  void _zoom(double delta) {
    final cam = _ctrl.camera;
    _ctrl.move(cam.center, (cam.zoom + delta).clamp(3.0, 18.0));
  }

  @override
  Widget build(BuildContext context) {
    final pins = _pins;
    if (pins.isEmpty) return const SizedBox.shrink();
    final diem = pins.map((h) => LatLng(h.latitude!, h.longitude!)).toList();

    return LayoutBuilder(
      builder: (context, c) {
        // Lần layout đầu có thể có kích thước 0 (ListView dựng lười) — chờ tới
        // khi có kích thước thật rồi mới chốt khung, sau đó giữ nguyên.
        if (_khungDaTinh == null && c.maxWidth > 0 && c.maxHeight.isFinite) {
          _khungDaTinh = _khungBanDau(diem, c.maxWidth, c.maxHeight);
        }
        final khung =
            _khungDaTinh ??
            (tam: diem.first, zoom: pins.length == 1 ? 14.0 : 11.0);
        return _dungBanDo(pins, diem, khung);
      },
    );
  }

  Widget _dungBanDo(
    List<HouseModel> pins,
    List<LatLng> diem,
    ({LatLng tam, double zoom}) khung,
  ) {
    return FlutterMap(
      mapController: _ctrl,
      options: MapOptions(
        initialCenter: khung.tam,
        initialZoom: khung.zoom,
        minZoom: 3,
        maxZoom: 18,
        interactionOptions: InteractionOptions(
          flags: widget.fullScreen
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              // Nhúng trong trang cuộn: CHỈ phóng to/thu nhỏ, không kéo —
              // xem docstring ở đầu file.
              : InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        lopTileNen(),
        MarkerLayer(
          markers: [
            for (final h in pins)
              Marker(
                point: LatLng(h.latitude!, h.longitude!),
                width: 34,
                height: 34,
                child: GestureDetector(
                  onTap: () => _moTin(h),
                  child: Icon(
                    Icons.location_on,
                    // Cùng quy ước màu với bản đồ tin đăng: bán = tím, thuê =
                    // theo nhóm loại hình.
                    color: HD.pinColorFor(h.categoryGroup, isSale: h.isForSale),
                    size: 34,
                    shadows: const [
                      Shadow(color: Colors.black45, blurRadius: 3),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Cụm nút +/− (và "mở rộng" khi nhúng) — phía gọi tự đặt vào Stack của nó.
  Widget nutZoom(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _nutTron(Icons.add, () => _zoom(1)),
      const SizedBox(height: 6),
      _nutTron(Icons.remove, () => _zoom(-1)),
    ],
  );

  Widget _nutTron(IconData icon, VoidCallback onTap) => Material(
    color: HD.paperRaised,
    shape: const CircleBorder(),
    elevation: 2,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 20, color: HD.ink),
      ),
    ),
  );

  void _moTin(HouseModel h) {
    if (h.id == null) return;
    context.push('/house/${h.id}');
  }
}

/// Bản đồ điểm chốt TOÀN MÀN HÌNH — kéo/zoom thoải mái, chạm ghim mở tin.
/// Route: không có URL (push trong tab).
class BrokerDealMapScreen extends StatefulWidget {
  const BrokerDealMapScreen({
    super.key,
    required this.houses,
    required this.hostName,
  });

  final List<HouseModel> houses;
  final String hostName;

  @override
  State<BrokerDealMapScreen> createState() => _BrokerDealMapScreenState();
}

class _BrokerDealMapScreenState extends State<BrokerDealMapScreen> {
  // Nút +/− do bản đồ cung cấp nhưng phải nằm NGOÀI FlutterMap (bọc thêm lớp
  // trong map làm camera lệch kích thước — xem ghi chú ở `_khungBanDau`), nên
  // cần key để lấy. THIẾU cụm nút này thì trên máy tính không còn cách nào
  // phóng to ngoài chạm đúp — đúng lỗi vừa gặp khi tách nút ra khỏi widget.
  final GlobalKey<BrokerDealMapState> _mapKey = GlobalKey<BrokerDealMapState>();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: DsAppBar(title: '${l.brokerMapTitle} · ${widget.hostName}'),
      body: Stack(
        children: [
          Positioned.fill(
            child: BrokerDealMap(
              key: _mapKey,
              houses: widget.houses,
              hostName: widget.hostName,
              fullScreen: true,
            ),
          ),
          Positioned(
            right: 12,
            bottom: 84,
            child: Builder(
              builder: (ctx) =>
                  _mapKey.currentState?.nutZoom(ctx) ?? const SizedBox.shrink(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: HD.paperRaised.withValues(alpha: 0.92),
              padding: const EdgeInsets.all(HD.s12),
              child: SafeArea(
                top: false,
                child: Text(
                  l.brokerMapHint,
                  textAlign: TextAlign.center,
                  style: HD.caption(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
