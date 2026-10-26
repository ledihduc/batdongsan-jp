import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:house_booking/features/map/widgets/base_map_tile_layer.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/repositories/api_house_repository.dart';
import 'package:house_booking/data/services/geo_location_service.dart';
import 'package:house_booking/features/map/utils/pin_kind.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Bản đồ XEM TRƯỚC trên trang chủ: dải ngang thấp, ghim tin đăng, chạm để mở
/// bản đồ đầy đủ.
///
/// Hai quyết định đáng ghi lại:
///
/// 1. **Bản đồ này KHÔNG tương tác.** Đặt một bản đồ kéo được vào giữa trang
///    cuộn dọc là bẫy kinh điển: ngón tay vuốt để cuộn trang lại bị bản đồ ăn
///    mất, trang đứng im. Ở đây mọi cử chỉ đi thẳng xuống trang, còn chạm một
///    cái thì mở bản đồ thật — nơi kéo/zoom thoải mái.
///
/// 2. **Không tự bật hộp thoại xin quyền vị trí.** Chỉ dùng vị trí khi quyền
///    ĐÃ được cấp trước đó; chưa có thì canh theo chính các tin đang hiện. Xin
///    quyền ngay khi người ta vừa mở app, lúc chưa hiểu mình được lợi gì, là
///    cách nhanh nhất để bị từ chối vĩnh viễn — và kéo chết theo cả những màn
///    thật sự cần vị trí.
///
/// Dùng ở HAI chỗ: mục "Khu vực mua bán" ở trang chủ, và ẢNH BÌA hồ sơ chủ nhà
/// ([kieuBia]). Mở rộng widget này thay vì dựng bản đồ thứ tư cho hồ sơ — app
/// đã có ba bản đồ rồi, mỗi cái một kiểu ghim thì người dùng phải học lại từ
/// đầu ở mỗi màn.
class HomeMapPreview extends StatefulWidget {
  const HomeMapPreview({
    super.key,
    this.repo,
    this.houses,
    this.height = 210,
    this.boGoc = HD.r12,
    this.kieuBia = false,
    this.requestLocationOnLoad = false,
    this.onTap,
  });

  /// Chỉ để test bơm dữ liệu giả.
  final ApiHouseRepository? repo;

  /// Tin đăng cho sẵn. Khác null thì KHÔNG gọi API và KHÔNG hỏi vị trí — bìa hồ
  /// sơ đã có `HouseProvider.myHouses`, gọi lại `/api/houses` chỉ để vẽ bìa là
  /// thừa một lượt mạng, còn hỏi vị trí ở đó không phục vụ việc gì.
  final List<HouseModel>? houses;

  final double height;
  final double boGoc;

  /// Chế độ ẢNH BÌA hồ sơ. Khác biệt duy nhất là TRÁNH CHỖ: `FbProfileHeader`
  /// đã đặt Cài đặt + Đăng xuất ở góc phải TRÊN và avatar tràn xuống góc trái
  /// DƯỚI, nên cụm nút zoom phải rời xuống phải-dưới và bỏ hẳn nút định vị.
  final bool kieuBia;

  /// Trang chủ bật cờ này để xin vị trí ngay khi bản đồ xuất hiện và canh
  /// camera đúng nơi người dùng đang đứng. Các bản đồ dùng làm ảnh bìa vẫn
  /// giữ hành vi yên lặng, tránh xin quyền ở chỗ không phục vụ tra cứu.
  final bool requestLocationOnLoad;

  /// Chạm vào bản đồ. Null → mở bản đồ toàn sàn `/map`.
  final VoidCallback? onTap;

  @override
  State<HomeMapPreview> createState() => _HomeMapPreviewState();
}

class _HomeMapPreviewState extends State<HomeMapPreview> {
  ApiHouseRepository get _repo => widget.repo ?? ApiHouseRepository();
  final _geo = const GeoLocationService();

  /// Cần controller chứ không thể chỉ đổi `initialCenter`: flutter_map đọc
  /// `initialCenter` ĐÚNG MỘT LẦN ở khung hình đầu. Lấy được vị trí sau đó mà
  /// chỉ setState thì chấm "vị trí của tôi" hiện ra ngoài khung nhìn còn bản đồ
  /// đứng nguyên chỗ cũ — trông y như không lấy được vị trí.
  final MapController _ctrl = MapController();
  bool _dangDinhVi = false;

  /// Zoom RỘNG: mục đích là cho thấy "quanh đây có nhiều tin", không phải để
  /// đọc từng ghim. Mức 11 gói gọn cỡ một thành phố.
  static const double _zoomDau = 11;
  static const LatLng _macDinh = LatLng(10.7769, 106.7009);

  /// Khung TOÀN CẢNH VIỆT NAM — bậc dự phòng cuối của chế độ bìa.
  ///
  /// Bìa hồ sơ giờ luôn là bản đồ, kể cả tài khoản vừa lập chưa có tin nào.
  /// Rơi về [_macDinh] (TP.HCM, zoom 11) trong tình huống đó là bịa: nói với
  /// người dùng rằng địa bàn của họ ở Sài Gòn trong khi hệ thống không biết gì
  /// cả. Toàn cảnh cả nước thì trung tính và đúng — "chưa khoanh vùng".
  ///
  /// Vĩ độ 16,2 là điểm giữa Bắc–Nam; zoom 4,8 vừa đủ trọn từ Hà Giang tới
  /// Cà Mau trên dải bìa cao 190px.
  static const LatLng _tamVietNam = LatLng(16.2, 107.5);
  static const double _zoomVietNam = 4.8;

  /// Zoom hiện tại — nút +/− đổi giá trị này. Bản đồ khoá cử chỉ nên đây là
  /// nguồn duy nhất, không sợ lệch với thao tác kéo của người dùng.
  double _zoom = _zoomDau;

  List<HouseModel> _nha = const [];
  LatLng? _toi;
  bool _xong = false;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    // Có dữ liệu cho sẵn → vẽ luôn, không chạm mạng, không chạm định vị.
    final choSan = widget.houses;
    if (choSan != null) {
      setState(() {
        _nha = choSan
            .where((h) => h.latitude != null && h.longitude != null)
            .toList();
        _xong = true;
      });
      // Đồng bộ mức zoom của NÚT với mức bản đồ thật sự khởi tạo. Bỏ bước này
      // thì lần bấm "+" đầu tiên nhảy từ 11 (mặc định trang chủ) chứ không phải
      // từ mức đang nhìn thấy — bản đồ giật một phát rất khó hiểu.
      _zoom = _zoomBanDau;
      // Danh sách cho sẵn mà RỖNG (bìa hồ sơ chưa có tin nào) thì vẫn phải xin
      // định vị: thiếu cả ghim lẫn vị trí, bìa chỉ còn khung cả nước. Có ghim
      // rồi thì thôi — khung đã canh theo tin đăng, hỏi quyền định vị lúc đó
      // chỉ là quấy rầy mà không đổi được gì trên màn.
      if (_nha.isEmpty) {
        unawaited(_napViTri(xinQuyen: widget.requestLocationOnLoad));
      }
      return;
    }

    // Tin đăng TRƯỚC và vẽ ngay. Vị trí là thứ "có thì tốt", nên chạy riêng —
    // gộp vào cùng một `Future.wait` thì chỉ cần tầng định vị treo hoặc không
    // có trên nền tảng đang chạy là cả bản đồ không bao giờ hiện.
    try {
      final nha = await _repo.getHouses(limit: 40);
      if (!mounted) return;
      setState(() {
        _nha = nha
            .where((h) => h.latitude != null && h.longitude != null)
            .toList();
        _xong = true;
      });
    } catch (_) {
      if (mounted) setState(() => _xong = true);
    }
    unawaited(_napViTri(xinQuyen: widget.requestLocationOnLoad));
  }

  Future<void> _napViTri({bool xinQuyen = false}) async {
    try {
      final r = xinQuyen
          ? await _geo.getCurrentLocation(chinhXacCao: true)
          : await _geo.currentIfAllowed(chinhXacCao: true);
      if (!mounted || !r.isOk) return;
      _datViTri(LatLng(r.lat!, r.lng!));
    } catch (_) {
      // Không có quyền / nền tảng không hỗ trợ → bản đồ vẫn canh theo tin đăng.
    }
  }

  void _datViTri(LatLng p) {
    // Đang ở khung toàn cảnh Việt Nam (bìa, chưa tin nào) thì zoom 4,8 là mức
    // "cả nước" — giữ nguyên khi về tới vị trí thì thành một chấm giữa bản đồ
    // vô nghĩa. Kéo về mức khu vực.
    final z = _chuaCoGiDeCanh ? _zoomDau : _zoom;
    setState(() {
      _toi = p;
      _zoom = z;
    });
    // Dời khung nhìn về đó — nếu không, chấm vị trí nằm ngoài màn hình.
    _ctrl.move(p, z);
  }

  /// Phóng to / thu nhỏ bằng NÚT. Bản đồ này khoá mọi cử chỉ để không nuốt
  /// thao tác cuộn trang, nên nút là cách duy nhất còn lại — và cũng đủ: ở một
  /// dải xem trước, người ta chỉ cần nhích một hai nấc để ước lượng mật độ.
  void _doiZoom(double delta) {
    final z = (_zoom + delta).clamp(4.0, 18.0);
    if (z == _zoom) return;
    setState(() => _zoom = z);
    _ctrl.move(_ctrl.camera.center, z);
  }

  /// Bấm nút định vị = người dùng CHỦ ĐỘNG hỏi. Đây mới là lúc được phép bật
  /// hộp thoại xin quyền: họ vừa nói rõ mình muốn gì.
  Future<void> _bamDinhVi() async {
    if (_dangDinhVi) return;
    setState(() => _dangDinhVi = true);
    final l = AppLocalizations.of(context);
    GeoLocationResult r;
    try {
      r = await _geo.getCurrentLocation(chinhXacCao: true);
    } catch (_) {
      r = const GeoLocationResult(GeoLocationStatus.error);
    }
    if (!mounted) return;
    setState(() => _dangDinhVi = false);
    if (r.isOk && r.lat != null && r.lng != null) {
      _datViTri(LatLng(r.lat!, r.lng!));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (r.status) {
          GeoLocationStatus.serviceOff => l.mapLocationOff,
          // Ba nguyên nhân KHÁC NHAU, ba cách sửa khác nhau. Gộp cả ba thành
          // "chưa cấp quyền" là dồn người dùng vào ngõ cụt: họ đi tìm hộp thoại
          // để bấm Cho phép, mà hộp thoại đó sẽ không bao giờ hiện.
          GeoLocationStatus.insecureContext => l.mapLocationInsecure,
          GeoLocationStatus.denied || GeoLocationStatus.deniedForever =>
            kIsWeb ? l.mapLocationBlocked : l.mapLocationDenied,
          GeoLocationStatus.outOfVietnam => l.mapLocationOutside,
          _ => l.mapLocationError,
        }),
      ),
    );
  }

  /// Tâm bản đồ: vị trí của người dùng nếu có, không thì tâm của chính các tin
  /// đang hiện — chứ không phải một toạ độ cứng ở tỉnh khác.
  /// Null = KHÔNG có hành động chạm (bìa hồ sơ mặc định rơi vào đây).
  ///
  /// Vì sao bìa không tự dẫn sang `/map`: `context.push` đẩy màn lên navigator
  /// GỐC, trong khi bìa nằm trong navigator con của tab Cá nhân — đo trên
  /// staging thì cú chạm làm shell dựng lại và văng về tab Trang chủ, không
  /// phải mở bản đồ. Bìa là ẢNH, không phải nút; muốn xem bản đồ thì đã có mục
  /// "Khu vực mua bán" ở trang chủ và tab Bản đồ.
  VoidCallback? get _cham {
    if (widget.onTap != null) return widget.onTap;
    if (widget.kieuBia) return null;
    return () => context.push('/map');
  }

  /// Mức phóng cho khung hình đầu.
  ///
  /// Trang chủ dùng mức cố định 11 (cỡ một thành phố) — mục đích ở đó là cho
  /// thấy "quanh đây có nhiều tin". Bìa hồ sơ thì ngược lại: nó phải vừa khít
  /// đúng vùng chủ nhà này có nhà, mà một chủ nhà có thể chỉ có tin trong một
  /// huyện — để mức 11 thì mọi ghim dồn vào một chấm giữa khung.
  /// Khung nhìn của bìa: canh theo VÙNG ĐÔNG GHIM NHẤT.
  ///
  /// Ba cách trước đều hỏng trên dữ liệu thật, ghi lại để đừng quay lại:
  ///   * Trung bình toạ độ → chủ nhà có tin ở Hà Nội, Cần Thơ và Nha Trang thì
  ///     tâm rơi vào khoảng giữa, tức giữa biển/rừng, bìa không có ghim nào.
  ///   * Khung bao min–max → một tin lẻ ở tỉnh khác đủ kéo bản đồ lùi ra tới
  ///     mức thấy cả Đông Nam Á.
  ///   * Băm vào lưới ô cố định 0,5° → RANH GIỚI Ô CẮT ĐÔI CỤM THẬT. Đo trên
  ///     tài khoản seed_190: 7 tin Hà Nội nằm vắt qua vĩ tuyến 21,0 nên bị chia
  ///     thành 3+4, thua cụm Nha Trang 5 tin — bìa của một chủ nhà Hà Nội lại
  ///     hiện ra biển Nha Trang.
  ///
  /// Nên: với mỗi ghim, đếm số ghim khác nằm trong bán kính ~0,35° (≈35km).
  /// Ghim nào đông hàng xóm nhất thì lấy cả xóm đó làm khung. Không có ranh
  /// giới nào để cắt nhầm. n ≤ 40 nên O(n²) là không đáng kể.
  ({LatLng tam, double zoom})? get _khungBia {
    if (!widget.kieuBia || _nha.isEmpty) return null;
    if (_nha.length == 1) {
      return (
        tam: LatLng(_nha.first.latitude!, _nha.first.longitude!),
        zoom: 13,
      );
    }

    const bk = 0.35;
    List<HouseModel> xomDongNhat = const [];
    for (final tam in _nha) {
      final xom = _nha
          .where(
            (h) =>
                (h.latitude! - tam.latitude!).abs() <= bk &&
                (h.longitude! - tam.longitude!).abs() <= bk,
          )
          .toList();
      if (xom.length > xomDongNhat.length) xomDongNhat = xom;
    }
    if (xomDongNhat.isEmpty) xomDongNhat = _nha;

    final lat =
        xomDongNhat.map((h) => h.latitude!).reduce((a, b) => a + b) /
        xomDongNhat.length;
    final lng =
        xomDongNhat.map((h) => h.longitude!).reduce((a, b) => a + b) /
        xomDongNhat.length;

    return (tam: LatLng(lat, lng), zoom: xomDongNhat.length == 1 ? 12.0 : 11.0);
  }

  /// Khung ôm trọn mọi ghim — chỉ dùng ở chế độ bìa.
  ///
  /// Trước đây bìa canh theo "xóm đông ghim nhất", nên một môi giới rải tin
  /// khắp nước chỉ thấy đúng Hà Nội, còn 12 tin ở Nha Trang, Cam Ranh, Cần Thơ
  /// thì nằm ngoài màn hình. Bìa là để nhìn TỔNG QUAN địa bàn, nên phải thấy
  /// hết.
  ///
  /// `maxZoom: 12` chặn trường hợp ngược lại: chỉ có một ghim thì `bounds` co
  /// về một điểm và bản đồ phóng tới mức thấy từng viên gạch.
  CameraFit? get _omTronGhim {
    if (!widget.kieuBia || _nha.isEmpty) return null;
    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints([
        for (final h in _nha) LatLng(h.latitude!, h.longitude!),
      ]),
      // Lề nhỏ thôi: bìa chỉ cao ~190px, lề 26 ăn hơn một phần tư chiều cao và
      // đẩy khung rộng thêm cả một quốc gia.
      padding: const EdgeInsets.all(12),
      maxZoom: 12,
    );
  }

  /// Chế độ bìa mà KHÔNG có gì để canh khung: chưa tin nào, chưa lấy được vị
  /// trí. Khi vị trí về sau đó, `_datViTri` tự dời khung nên trạng thái này chỉ
  /// kéo dài tới lúc có toạ độ.
  bool get _chuaCoGiDeCanh => widget.kieuBia && _nha.isEmpty && _toi == null;

  double get _zoomBanDau =>
      _khungBia?.zoom ?? (_chuaCoGiDeCanh ? _zoomVietNam : _zoomDau);

  LatLng get _tam {
    final bia = _khungBia;
    if (bia != null) return bia.tam;
    if (_toi != null) return _toi!;
    if (_chuaCoGiDeCanh) return _tamVietNam;
    if (_nha.isEmpty) return _macDinh;
    final lat =
        _nha.map((h) => h.latitude!).reduce((a, b) => a + b) / _nha.length;
    final lng =
        _nha.map((h) => h.longitude!).reduce((a, b) => a + b) / _nha.length;
    return LatLng(lat, lng);
  }

  Color _mauLoai(String k) => switch (k) {
    PinKind.stayShort => HD.pinStayShort,
    PinKind.business => HD.pinBusiness,
    PinKind.sale => HD.pinSale,
    _ => HD.pinStayLong,
  };

  String _nhanLoai(String k, AppLocalizations l) => switch (k) {
    PinKind.stayShort => l.tradeChipShort,
    PinKind.business => l.tradeChipBusiness,
    PinKind.sale => l.tradeChipSale,
    _ => l.tradeChipLong,
  };

  Widget _nutTron({
    required String tooltip,
    required VoidCallback onTap,
    required Widget child,
  }) => Material(
    color: HD.paperRaised,
    shape: const CircleBorder(),
    elevation: 2,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(width: 32, height: 32, child: Center(child: child)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.boGoc),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!_xong)
              const ColoredBox(color: HD.paperSunken)
            else
              FlutterMap(
                mapController: _ctrl,
                options: MapOptions(
                  initialCenter: _tam,
                  initialZoom: _zoomBanDau,
                  // Bìa hồ sơ: khung phải ôm TRỌN mọi ghim, kể cả khi người
                  // này rải tin từ Hà Nội tới Cần Thơ. Dùng `initialCameraFit`
                  // chứ không tự tính zoom: nó đo bằng kích thước THẬT ở lượt
                  // dựng đầu, tránh đúng cái bẫy `fitCamera` đọc kích thước cũ.
                  initialCameraFit: _omTronGhim,
                  // Khoá MỌI cử chỉ — xem lý do ở phần mô tả lớp.
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  lopTileNen(),
                  MarkerLayer(
                    markers: [
                      for (final h in _nha)
                        Marker(
                          point: LatLng(h.latitude!, h.longitude!),
                          width: 14,
                          height: 14,
                          child: Container(
                            decoration: BoxDecoration(
                              color: HD.pinColorFor(
                                h.categoryGroup,
                                isSale: h.isForSale,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      // Vị trí CỦA TÔI — chữ thập, không phải chấm tròn. Pin
                      // tin đăng ngay trên kia cũng là đĩa tròn viền trắng, mà
                      // bốn màu pin đã chiếm hết xanh lá/cam/xanh dương/đỏ nên
                      // đổi màu không phân biệt được; phải khác HÌNH DẠNG.
                      if (_toi != null)
                        Marker(
                          point: _toi!,
                          width: MarkerViTriToi.hopCho(20),
                          height: MarkerViTriToi.hopCho(20),
                          child: const MarkerViTriToi(),
                        ),
                    ],
                  ),
                ],
              ),

            // Dải mờ dưới đáy để chữ đọc được trên mọi nền bản đồ.
            //
            // Chế độ bìa KHÔNG có dải này: đáy bìa đã bị avatar tràn xuống
            // chiếm, và nút "Mở rộng" ở đó thì nằm ngay dưới cụm zoom — hai
            // nút đè lên nhau. Chạm cả bìa vẫn mở được bản đồ.
            if (!widget.kieuBia)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      // Tiêu đề mục đã nằm NGAY TRÊN khối này, nên ở đây chỉ nói
                      // thêm khi có chuyện đáng nói (không có tin nào). Lặp lại
                      // hai lần cùng một ý chỉ tổ chiếm chỗ của bản đồ.
                      Expanded(
                        child: _xong && _nha.isEmpty
                            ? Text(
                                l.homeMapPreviewEmpty,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      // Nút mở rộng RIÊNG, có viền — chạm cả thẻ cũng mở được,
                      // nhưng phải có một thứ trông như nút thì người dùng mới
                      // chắc là bấm được.
                      Material(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _cham,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.open_in_full,
                                  color: Colors.white,
                                  size: 13,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  l.homeMapExpand,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Lớp chạm phủ TOÀN khối — cả bản đồ là một nút mở bản đồ đầy đủ.
            // Không có hành động chạm thì KHÔNG dựng lớp phủ: một lớp InkWell
            // vô hại vẫn nuốt cú chạm và loé gợn mực, người dùng tưởng bấm
            // được mà không có gì xảy ra.
            if (_cham != null)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: _cham),
                ),
              ),

            // Cụm nút đặt SAU lớp chạm để nhận cú chạm trước — đặt trước
            // thì lớp phủ nuốt mất, bấm nút chỉ mở bản đồ đầy đủ.
            //
            // Chế độ bìa KHÔNG có nút nào: bìa là một tấm hình, cử chỉ đã khoá
            // (`InteractiveFlag.none`) nên phóng to rồi cũng không kéo đi đâu
            // được. Hai nút +/− ở đó chỉ đè lên nhãn tổng quan và mời người ta
            // bấm vào thứ không dẫn tới đâu — chạm bìa mở bản đồ đầy đủ mới là
            // hành động đúng.
            if (!widget.kieuBia)
              Positioned(
                right: 8,
                top: 8,
                child: Column(
                  children: [
                    if (!widget.kieuBia)
                      _nutTron(
                        tooltip: l.homeMapLocate,
                        onTap: _bamDinhVi,
                        child: _dangDinhVi
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.my_location,
                                size: 18,
                                color: _toi != null ? HD.accent : HD.ink,
                              ),
                      ),
                    if (!widget.kieuBia) const SizedBox(height: 6),
                    _nutTron(
                      tooltip: l.mapZoomIn,
                      onTap: () => _doiZoom(1),
                      child: const Icon(Icons.add, size: 18, color: HD.ink),
                    ),
                    const SizedBox(height: 6),
                    _nutTron(
                      tooltip: l.mapZoomOut,
                      onTap: () => _doiZoom(-1),
                      child: const Icon(Icons.remove, size: 18, color: HD.ink),
                    ),
                  ],
                ),
              ),

            // Chú thích màu ghim — góc trái trên, dùng ĐÚNG bộ từ và bộ màu của
            // bản đồ đầy đủ để người dùng chỉ phải học một lần.
            Positioned(
              left: 8,
              top: 8,
              child: Material(
                color: HD.paperRaised.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final k in PinKind.all) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _mauLoai(k),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _nhanLoai(k, l),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: HD.inkSoft,
                          ),
                        ),
                        if (k != PinKind.all.last) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
