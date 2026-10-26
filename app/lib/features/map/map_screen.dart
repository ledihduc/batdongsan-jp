import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/map/widgets/base_map_tile_layer.dart';

import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/repositories/api_house_repository.dart';
import 'package:house_booking/providers/house_provider.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/features/map/utils/marker_cluster.dart';
import 'package:house_booking/features/map/utils/pin_kind.dart';
import 'package:house_booking/features/map/widgets/map_controls.dart';
import 'package:house_booking/features/map/widgets/map_search_bar.dart';
import 'package:house_booking/features/map/widgets/trackpad_pan_zoom.dart';
import 'package:house_booking/features/map/widgets/map_pin_legend.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.embedded = false,
    this.initialCenter,
    this.initialZoom,
    this.focusHouseId,
    this.repo,
  });

  /// Mở thẳng vào một vị trí (bấm "xem trên bản đồ" từ một tin). Có giá trị thì
  /// BỎ QUA bước tự canh khung nhìn theo toàn bộ tin — người dùng vừa chỉ đích
  /// danh chỗ họ muốn xem, kéo camera đi nơi khác là phản tác dụng.
  final LatLng? initialCenter;
  final double? initialZoom;

  /// Tin cần chọn sẵn khi mở. Xem lý do ở [MapShellScreen.focusHouseId].
  final int? focusHouseId;

  /// Chỉ để test bơm dữ liệu giả.
  final ApiHouseRepository? repo;

  /// Khi true, chỉ render phần body (không Scaffold/AppBar riêng) để nhúng
  /// vào [MapShellScreen] — shell tự quản AppBar + toggle mode.
  final bool embedded;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapCtrl = MapController();
  ApiHouseRepository get _repo => widget.repo ?? ApiHouseRepository();
  HouseModel? _selected;

  /// Tin được chỉ đích danh qua deep-link, TẢI RIÊNG. Nó có thể không nằm trong
  /// trang tin mà provider đang giữ, nên phải tự đi lấy — nếu không, người dùng
  /// tới đúng toạ độ mà bản đồ trống trơn.
  HouseModel? _tinChiDinh;

  /// Đã kéo khung nhìn về vùng có tin chưa. `initialCenter` của FlutterMap chỉ
  /// đọc MỘT LẦN ở khung hình đầu — lúc đó danh sách tin còn rỗng nên bản đồ
  /// đứng ở tâm mặc định (Sài Gòn) trong khi tin nằm ở tỉnh khác: người dùng
  /// thấy bản đồ trống dù dữ liệu có đủ.
  late bool _daCanKhungNhin = widget.initialCenter != null;

  /// Chưa xong lần nạp tin ĐẦU TIÊN. Không thể chỉ dựa vào `hp.isLoading`: ở
  /// khung hình đầu nó vẫn là false (request chưa kịp bắn), nên thẻ "chưa có
  /// nhà nào" sẽ loé lên rồi mới biến mất.
  bool _dangChoNapLanDau = true;

  /// Mức zoom ĐÃ LÀM TRÒN dùng để gom cụm. Cố ý chỉ giữ số nguyên: lưới cụm
  /// đổi rõ rệt mỗi mức zoom, còn bám theo số lẻ thì chỉ tổ dựng lại màn liên
  /// tục mà mắt không thấy khác gì.
  late int _zoomBucket = (widget.initialZoom ?? 12).round();

  /// Hoãn cập nhật cụm tới khi người dùng NGỪNG kéo/chụm. onPositionChanged bắn
  /// mỗi khung hình trong lúc có cử chỉ; setState ở đó làm dựng lại cả màn giữa
  /// lúc đang tương tác → bản đồ giật.
  Timer? _zoomDebounce;

  /// Cụm đã tính, dùng lại khi màn dựng lại vì lý do khác (chọn pin, tải thêm
  /// tin) mà zoom không đổi.
  List<PinCluster> _clusters = const [];
  int? _clustersZoom;
  Set<String>? _clustersKinds;

  /// Chính danh sách tin đã dùng để tính [_clusters]. Giữ nguyên tham chiếu để
  /// so SÁNH THEO TỪNG PHẦN TỬ chứ không chỉ theo SỐ LƯỢNG.
  ///
  /// Trước đây chỉ so số lượng, và đó là một lỗi im lặng: đổi bộ lọc hay tìm
  /// kiếm mới thường trả về đúng 20 tin (một trang) — cùng độ dài, cùng zoom,
  /// cùng loại — nên bộ nhớ đệm coi là "không đổi" và bản đồ giữ nguyên ghim
  /// của kết quả CŨ. Người dùng lọc xong thấy y hệt lúc trước, tưởng bộ lọc
  /// hỏng.
  List<HouseModel> _clustersInput = const [];

  /// Điểm vừa chọn từ ô tìm kiếm hoặc nút định vị — ghim tạm để người dùng
  /// biết bản đồ vừa nhảy tới đâu.
  LatLng? _diemDanhDau;

  /// Loại tin đang hiển thị. Mặc định BẬT HẾT — bản đồ phải cho thấy mọi thứ
  /// cho tới khi người dùng chủ động bỏ bớt.
  final Set<String> _loaiHienThi = {...PinKind.all};

  /// MapOptions dựng MỘT LẦN. flutter_map so sánh options ở didUpdateWidget và
  /// thay cả camera khi thấy khác; các callback ở đây là closure nên dựng lại
  /// mỗi lần build sẽ luôn "khác" → camera bị thay ngay giữa cử chỉ zoom, biểu
  /// hiện là bản đồ KHÔNG phóng to được. Giữ một instance cố định là hết.
  late final MapOptions _mapOptions = MapOptions(
    initialCenter: widget.initialCenter ?? _defaultCenter,
    initialZoom: widget.initialZoom ?? 12,
    minZoom: 4,
    maxZoom: 18,
    interactionOptions: const InteractionOptions(flags: kMapInteractiveFlags),
    onTap: (_, __) => setState(() => _selected = null),
    onPositionChanged: _onPositionChanged,
  );

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    // KHÔNG setState thẳng ở đây — hàm này chạy mỗi khung hình khi đang kéo
    // hoặc chụm. Chỉ hẹn giờ, và chỉ khi mức zoom làm tròn thật sự đổi.
    final b = camera.zoom.round();
    if (b == _zoomBucket) return;
    _zoomDebounce?.cancel();
    _zoomDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      final cur = _mapCtrl.camera.zoom.round();
      if (cur == _zoomBucket) return;
      setState(() => _zoomBucket = cur);
    });
  }

  // Mặc định trung tâm Sài Gòn nếu không có nhà nào
  static const LatLng _defaultCenter = LatLng(10.7769, 106.7009);

  @override
  void initState() {
    super.initState();
    // Vào THẲNG /map bằng link (không qua trang chủ) thì HouseProvider chưa
    // từng nạp tin — bản đồ hiện "chưa có nhà nào có toạ độ" dù dữ liệu đầy.
    // Chỉ nạp khi đang rỗng để không bắn thêm request ở luồng thường.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final hp = Provider.of<HouseProvider>(context, listen: false);
      if (hp.houses.isEmpty && !hp.isLoading) await hp.fetchInitialData();
      if (mounted) setState(() => _dangChoNapLanDau = false);
      await _napTinChiDinh();
    });
  }

  /// Tìm tin được chỉ đích danh: ưu tiên danh sách đang có, không thấy thì gọi
  /// API. Xong thì CHỌN nó luôn để thẻ thông tin hiện lên ở đáy — đó mới là
  /// "mở đúng tin", chứ dời camera tới một vùng trống thì người dùng không biết
  /// mình đang nhìn cái gì.
  Future<void> _napTinChiDinh() async {
    final id = widget.focusHouseId;
    if (id == null) return;
    final hp = Provider.of<HouseProvider>(context, listen: false);
    HouseModel? h;
    for (final x in hp.houses) {
      if (x.id == id) {
        h = x;
        break;
      }
    }
    h ??= await _repo.getHouseById(id).catchError((_) => null);
    if (!mounted || h == null) return;
    setState(() {
      _tinChiDinh = h;
      _selected = h;
    });
    if (h.latitude != null && h.longitude != null) {
      _mapCtrl.move(
        LatLng(h.latitude!, h.longitude!),
        widget.initialZoom ?? 16,
      );
    }
  }

  @override
  void dispose() {
    _zoomDebounce?.cancel();
    _mapCtrl.dispose();
    super.dispose();
  }

  /// Đúng tập tin đó, không cần gom lại. So bằng `identical` vì mỗi lần nạp
  /// API sinh ra [HouseModel] mới — cùng tin thì cùng tham chiếu, khác dữ liệu
  /// thì khác tham chiếu. Chỉ là so con trỏ nên rẻ hơn nhiều so với việc gom
  /// cụm lại.
  bool _cungTapTin(List<HouseModel> a, List<HouseModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  /// Tính lại cụm KHI CẦN. Zoom, tập tin và bộ lọc loại đều không đổi → trả
  /// lại kết quả cũ (bản đồ dựng lại rất thường xuyên: chọn ghim, mở chú giải,
  /// tải thêm tin).
  List<PinCluster> _clustersFor(List<HouseModel> houses) {
    if (_clustersZoom == _zoomBucket &&
        _cungTapTin(_clustersInput, houses) &&
        _clustersKinds != null &&
        _clustersKinds!.length == _loaiHienThi.length &&
        _clustersKinds!.containsAll(_loaiHienThi)) {
      return _clusters;
    }
    _clusters = clusterPins(houses, zoom: _zoomBucket.toDouble());
    _clustersZoom = _zoomBucket;
    // `houses` là danh sách MỚI mỗi lượt build (`.where().toList()`), không ai
    // sửa nó sau đó — giữ tham chiếu là an toàn.
    _clustersInput = houses;
    _clustersKinds = {..._loaiHienThi};
    return _clusters;
  }

  @override
  Widget build(BuildContext context) {
    final hp = Provider.of<HouseProvider>(context);
    final housesWithCoord = hp.houses
        .where((h) => h.latitude != null && h.longitude != null)
        .toList();
    // Ghép tin được chỉ đích danh vào (nếu chưa có) để nó CHẮC CHẮN có ghim.
    final ct = _tinChiDinh;
    if (ct != null &&
        ct.latitude != null &&
        ct.longitude != null &&
        !housesWithCoord.any((h) => h.id == ct.id)) {
      housesWithCoord.add(ct);
    }

    if (!_daCanKhungNhin && housesWithCoord.isNotEmpty) {
      _daCanKhungNhin = true;
      final diem = housesWithCoord
          .map((h) => LatLng(h.latitude!, h.longitude!))
          .toList();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Fit tất cả pin, chừa lề để pin ở mép không bị cắt.
        _mapCtrl.fitCamera(
          CameraFit.coordinates(
            coordinates: diem,
            padding: const EdgeInsets.all(48),
            maxZoom: 14,
          ),
        );
      });
    }

    // Lọc theo ô tích trong chú giải TRƯỚC khi gom cụm, để con số trên bong
    // bóng đếm đúng những tin đang thật sự hiện.
    final hienThi = housesWithCoord
        .where((h) => _loaiHienThi.contains(pinKindFor(h)))
        .toList();

    // Gom pin gần nhau để zoom xa không bị chồng ghim đè lên nhau.
    final clusters = _clustersFor(hienThi);
    final markers = clusters
        .map((c) => c.isSingle ? _buildMarker(c.first) : _buildClusterMarker(c))
        .toList();
    final initialCenter = housesWithCoord.isNotEmpty
        ? LatLng(
            housesWithCoord.first.latitude!,
            housesWithCoord.first.longitude!,
          )
        : _defaultCenter;

    final body = Stack(
      children: [
        TrackpadPanZoom(
          controller: _mapCtrl,
          child: FlutterMap(
            mapController: _mapCtrl,
            options: _mapOptions,
            children: [
              lopTileNen(),
              MarkerLayer(markers: markers),
              if (_diemDanhDau != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _diemDanhDau!,
                      width: 34,
                      height: 34,
                      child: const Icon(
                        Icons.place,
                        color: HD.accent,
                        size: 32,
                        shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                      ),
                    ),
                  ],
                ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
        if (_selected != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: _selectedCard(_selected!),
          ),
        // Hàng trên cùng: ô tìm địa điểm + chú giải NẰM CÙNG MỘT HÀNG.
        // Xếp chồng hai khối lên nhau (như trước) ăn mất hai dải ngang của bản
        // đồ; gộp một hàng thì chỉ mất một.
        Positioned(
          left: 8,
          right: 8,
          top: 8,
          child: Row(
            // Neo theo MÉP TRÊN: mở chú giải ra thì nó dài xuống dưới, ô tìm
            // kiếm phải đứng yên chứ không trôi theo.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: MapSearchBar(
                  onPick: (p, _) {
                    setState(() {
                      _diemDanhDau = p;
                      _selected = null;
                    });
                    _mapCtrl.move(p, 15);
                  },
                ),
              ),
              if (housesWithCoord.isNotEmpty) ...[
                const SizedBox(width: 8),
                MapPinLegend(
                  enabled: _loaiHienThi,
                  onToggle: (kind) => setState(() {
                    // Bỏ tích loại CUỐI CÙNG sẽ cho bản đồ trắng trơn mà không
                    // giải thích được vì sao — giữ lại ít nhất một loại.
                    if (_loaiHienThi.contains(kind)) {
                      if (_loaiHienThi.length > 1) _loaiHienThi.remove(kind);
                    } else {
                      _loaiHienThi.add(kind);
                    }
                  }),
                ),
              ],
            ],
          ),
        ),

        // Cụm định vị + phóng to/thu nhỏ — GÓC DƯỚI PHẢI như Google Maps, chứ
        // không canh giữa: ngón tay cầm máy với tới đó dễ nhất, và giữa màn là
        // chỗ để nhìn bản đồ.
        // Chừa 44 cho dòng ghi công OpenStreetMap ở đáy; khi có thẻ tin đang
        // chọn thì nâng lên trên thẻ để hai thứ không đè nhau.
        AnimatedPositioned(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          right: 8,
          bottom: _selected != null ? 150 : 44,
          child: MapControls(
            controller: _mapCtrl,
            onLocated: (p) => setState(() => _diemDanhDau = p),
          ),
        ),
        // Đang tải thì báo ĐANG TẢI, đừng khẳng định "chưa có nhà nào". Trước
        // đây thẻ rỗng hiện ngay từ khung hình đầu, trong khi tin còn đang về —
        // vừa nói sai, vừa nằm chắn giữa bản đồ nên kéo không được, khiến người
        // dùng tưởng bản đồ hỏng và phải chạm vào mới chạy.
        if (housesWithCoord.isEmpty && (hp.isLoading || _dangChoNapLanDau))
          const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        if (housesWithCoord.isEmpty && !hp.isLoading && !_dangChoNapLanDau)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Chưa có nhà nào có toạ độ. Khi host thêm vĩ độ/kinh độ, nhà sẽ hiện trên bản đồ.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bản đồ nhà',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (housesWithCoord.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.layers_clear_outlined),
              tooltip: 'Reset vị trí',
              onPressed: () {
                _mapCtrl.move(initialCenter, 12);
                setState(() => _selected = null);
              },
            ),
        ],
      ),
      body: body,
    );
  }

  /// Bong bóng đại diện cho nhiều tin nằm sát nhau. Màu = loại CHIẾM ĐA SỐ
  /// trong cụm, để nhìn từ xa vẫn đoán được vùng đó chủ yếu là bán hay cho thuê.
  Marker _buildClusterMarker(PinCluster c) {
    final counts = <Color, int>{};
    for (final h in c.houses) {
      final color = HD.pinColorFor(h.categoryGroup, isSale: h.isForSale);
      counts[color] = (counts[color] ?? 0) + 1;
    }
    final color = counts.entries
        .reduce((a, b) => b.value > a.value ? b : a)
        .key;
    // To dần theo số tin nhưng chặn trên — cụm 500 tin không được che nửa
    // bản đồ.
    final size = (36 + c.houses.length.clamp(0, 60) * 0.5).toDouble();

    return Marker(
      point: c.center,
      width: size,
      height: size,
      child: Tooltip(
        message: AppLocalizations.of(context).mapClusterTooltip,
        child: GestureDetector(
          // Zoom sâu thêm 2 mức tại tâm cụm → lưới nhỏ lại → cụm tự tách.
          onTap: () => _mapCtrl.move(
            c.center,
            (_zoomBucket + 2).clamp(4, 18).toDouble(),
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${c.houses.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Marker _buildMarker(HouseModel h) {
    return Marker(
      point: LatLng(h.latitude!, h.longitude!),
      width: 70,
      height: 40,
      child: GestureDetector(
        onTap: () {
          setState(() => _selected = h);
          _mapCtrl.move(LatLng(h.latitude!, h.longitude!), 14);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            // Màu = PHÂN LOẠI (bán / nhóm lưu trú-kinh doanh), KHÔNG phải trạng
            // thái. Pin đang chọn phân biệt bằng VIỀN ĐỎ + viền dày hơn.
            // (Trước đây hai nhánh if trả cùng HD.accent nên pin luôn đỏ.)
            color: HD.pinColorFor(h.categoryGroup, isSale: h.isForSale),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _selected?.id == h.id ? HD.accent : Colors.white,
              width: _selected?.id == h.id ? 3 : 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tin BÁN dùng chung một màu đỏ nên icon là thứ duy nhất còn
              // phân biệt loại hình — đừng thay bằng icon cố định.
              Icon(
                HD.pinIconFor(h.categoryGroup),
                color: Colors.white,
                size: 12,
              ),
              const SizedBox(width: 3),
              Text(
                PriceFormat.compact(h.price),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectedCard(HouseModel h) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/house/${h.id}'),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: h.images.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: h.images.first,
                      fit: BoxFit.cover,
                      memCacheWidth: 240,
                      fadeInDuration: const Duration(milliseconds: 150),
                      placeholder: (_, __) => Container(color: HD.paperSunken),
                      errorWidget: (_, __, ___) => Container(
                        color: HD.paperSunken,
                        child: const Icon(
                          Icons.home_outlined,
                          color: HD.inkMuted,
                        ),
                      ),
                    )
                  : Container(
                      color: HD.paperSunken,
                      child: const Icon(
                        Icons.home_outlined,
                        color: HD.inkMuted,
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: HD.inkMuted,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '${h.district}, ${h.city}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: HD.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      h.priceCompactLabel,
                      style: const TextStyle(
                        color: HD.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Text(
                          'Xem chi tiết →',
                          style: TextStyle(
                            color: HD.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _selected = null),
            ),
          ],
        ),
      ),
    );
  }
}
