import 'dart:async';

import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/repositories/api_house_repository.dart';
import 'package:house_booking/data/services/geo_location_service.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Mốc diện tích quen thuộc. Người tìm nhà nghĩ theo NGƯỠNG ("tầm 50m²"), chứ
/// không nghĩ ra con số chính xác để gõ vào ô nhập.
enum AreaBucket { tatCa, duoi30, tu30den50, tu50den80, tren80 }

/// Cách giới hạn KHU VỰC tìm. `quanhDay` cần toạ độ máy, `diaDanh` cần backend
/// geocode chuỗi người dùng gõ.
enum KhuVuc { toanBo, quanhDay, diaDanh }

/// Bộ lọc của màn Mua/Bán. Bất biến để so sánh được và để màn cha biết khi nào
/// nút lọc phải sáng lên.
class TradeFilter {
  const TradeFilter({
    this.giaTu,
    this.giaDen,
    this.dienTich = AreaBucket.tatCa,
    this.phongNgu,
    this.sort = '',
    this.loaiHinh,
    this.huongNha = const {},
    this.chiUyTin = false,
    this.diemDanhGia = 0,
    this.saoChatLuong = 0,
    this.khuVuc = KhuVuc.toanBo,
    this.banKinhKm = 3,
    this.lat,
    this.lng,
    this.tenDiaDanh = '',
  });

  final double? giaTu;
  final double? giaDen;
  final AreaBucket dienTich;
  final int? phongNgu;

  /// '' | price_asc | price_desc | trust | rating
  final String sort;

  /// id danh mục (loại hình cư trú); null = tất cả.
  final int? loaiHinh;

  /// Slug hướng nhà, chọn được NHIỀU: người xem phong thuỷ thường chấp nhận
  /// hai ba hướng hợp mệnh chứ không đúng một hướng duy nhất.
  final Set<String> huongNha;

  final bool chiUyTin;

  /// 0 = không lọc.
  final double diemDanhGia;

  /// 0 = không lọc.
  final int saoChatLuong;

  final KhuVuc khuVuc;
  final double banKinhKm;

  /// Tâm vùng tìm. Chỉ có nghĩa khi [khuVuc] khác [KhuVuc.toanBo]; null nghĩa
  /// là CHƯA lấy được toạ độ → phải coi như không lọc khu vực, không được gửi
  /// bán kính đi một mình.
  final double? lat;
  final double? lng;

  /// Chuỗi người dùng gõ ở chế độ địa danh — giữ lại để hiện lại khi mở bảng.
  final String tenDiaDanh;

  /// Có ĐỦ dữ liệu để lọc theo khu vực hay chưa.
  bool get coToaDo => khuVuc != KhuVuc.toanBo && lat != null && lng != null;

  double? get dienTichTu => switch (dienTich) {
    AreaBucket.tu30den50 => 30,
    AreaBucket.tu50den80 => 50,
    AreaBucket.tren80 => 80,
    _ => null,
  };

  double? get dienTichDen => switch (dienTich) {
    AreaBucket.duoi30 => 30,
    AreaBucket.tu30den50 => 50,
    AreaBucket.tu50den80 => 80,
    _ => null,
  };

  /// Số tiêu chí đang bật — hiện ngay trên nút lọc ở màn cha, để người dùng
  /// biết danh sách bị cắt bớt bao nhiêu mà không phải mở bảng ra xem.
  int get soTieuChi =>
      (giaTu != null || giaDen != null ? 1 : 0) +
      (dienTich != AreaBucket.tatCa ? 1 : 0) +
      (phongNgu != null ? 1 : 0) +
      (sort.isNotEmpty ? 1 : 0) +
      (loaiHinh != null ? 1 : 0) +
      (huongNha.isEmpty ? 0 : 1) +
      (chiUyTin ? 1 : 0) +
      (diemDanhGia > 0 ? 1 : 0) +
      (saoChatLuong > 0 ? 1 : 0) +
      // Chỉ tính khi ĐÃ có toạ độ: chọn "quanh đây" mà chưa cấp quyền vị trí
      // thì thực tế chưa lọc gì, đếm vào là nói dối.
      (coToaDo ? 1 : 0);

  bool get dangLoc => soTieuChi > 0;

  TradeFilter copyWith({
    double? giaTu,
    double? giaDen,
    AreaBucket? dienTich,
    int? phongNgu,
    String? sort,
    int? loaiHinh,
    Set<String>? huongNha,
    bool? chiUyTin,
    double? diemDanhGia,
    int? saoChatLuong,
    KhuVuc? khuVuc,
    double? banKinhKm,
    double? lat,
    double? lng,
    String? tenDiaDanh,
    bool xoaToaDo = false,
    bool xoaGia = false,
    bool xoaPhongNgu = false,
    bool xoaLoaiHinh = false,
  }) => TradeFilter(
    giaTu: xoaGia ? null : (giaTu ?? this.giaTu),
    giaDen: xoaGia ? null : (giaDen ?? this.giaDen),
    dienTich: dienTich ?? this.dienTich,
    phongNgu: xoaPhongNgu ? null : (phongNgu ?? this.phongNgu),
    sort: sort ?? this.sort,
    loaiHinh: xoaLoaiHinh ? null : (loaiHinh ?? this.loaiHinh),
    huongNha: huongNha ?? this.huongNha,
    chiUyTin: chiUyTin ?? this.chiUyTin,
    diemDanhGia: diemDanhGia ?? this.diemDanhGia,
    saoChatLuong: saoChatLuong ?? this.saoChatLuong,
    khuVuc: khuVuc ?? this.khuVuc,
    banKinhKm: banKinhKm ?? this.banKinhKm,
    lat: xoaToaDo ? null : (lat ?? this.lat),
    lng: xoaToaDo ? null : (lng ?? this.lng),
    tenDiaDanh: tenDiaDanh ?? this.tenDiaDanh,
  );
}

/// Bảng lọc trượt lên từ đáy cho màn Mua/Bán.
///
/// Dựng theo màn "Bộ lọc nâng cao" ở trang chủ nhưng SỬA bốn điều đã cản trở ở
/// đó:
///
///  1. Ở đó là màn TOÀN MÀN HÌNH — người đang lướt tin phải rời hẳn danh sách,
///     cuộn qua tám mục rồi mới quay lại. Đây là bảng trượt, danh sách vẫn nằm
///     sau lưng, cảm giác là "chỉnh lại" chứ không phải "đi làm một cái form".
///  2. Ở đó giá chỉ có MỘT thanh trượt "giá tối đa" — không đặt được sàn, người
///     cần nhà 5–8 triệu vẫn phải xem cả nhà 500 nghìn. Đây là thanh HAI ĐẦU.
///  3. Ở đó thang giá cố định 0–100 triệu kể cả khi đang xem tin BÁN (đơn vị
///     tỷ) → cả thanh trượt vô dụng. Đây thang TỰ ĐỔI theo thứ đang xem.
///  4. Ở đó bấm "Áp dụng" xong mới biết còn 0 kết quả, phải mở lại và nới điều
///     kiện — vòng lặp mù. Đây nút áp dụng ĐẾM SẴN: "Xem 37 tin".
///
/// Hướng nhà phong thuỷ · uy tín · sao chất lượng · loại hình nay CÓ ở đây,
/// nhưng gấp lại trong mục "Lọc nâng cao" mặc định đóng. Bản đầu bỏ hẳn chúng
/// vì ở màn gốc chúng chiếm quá nửa chiều dài trong khi ít người chạm tới —
/// gấp lại giữ được điều đó mà vẫn không bắt ai phải quay về trang chủ mới lọc
/// đủ. Riêng "khu vực / quanh đây" vẫn nằm ngoài: nó cần tham số toạ độ mà
/// `ApiHouseRepository.getHouses` chưa nhận, thêm vào đây sẽ là một ô lọc bấm
/// vào không đổi gì.
class TradeFilterSheet extends StatefulWidget {
  const TradeFilterSheet({
    required this.initial,
    required this.dem,
    this.thangTy = false,
    this.danhMuc = const [],
    this.repo,
    super.key,
  });

  final TradeFilter initial;

  /// Đếm số tin khớp — màn cha cung cấp vì chỉ nó biết tab và chip đang chọn.
  final Future<int> Function(TradeFilter) dem;

  /// true khi đang lọc tin BÁN → thang giá tính bằng tỷ.
  final bool thangTy;

  /// Danh mục loại hình `{id, name}`. Màn cha truyền vào chứ bảng lọc KHÔNG tự
  /// đọc `HouseProvider`: buộc vào provider thì bảng chỉ dựng được ở nơi có
  /// provider đó, và mọi test đều phải bọc thêm một lớp không liên quan.
  final List<dynamic> danhMuc;

  /// Chỉ dùng để geocode địa danh. Bơm được để test không chạm mạng.
  final ApiHouseRepository? repo;

  @override
  State<TradeFilterSheet> createState() => _TradeFilterSheetState();
}

class _TradeFilterSheetState extends State<TradeFilterSheet> {
  late TradeFilter _f = widget.initial;

  Timer? _hoan;
  int? _soTin;
  bool _dangDem = true;

  /// Mục nâng cao mở sẵn nếu người dùng ĐANG lọc bằng nó — mở bảng ra mà thấy
  /// mục đóng kín thì không hiểu vì sao danh sách lại ngắn thế.
  ApiHouseRepository get _repo => widget.repo ?? ApiHouseRepository();
  static const _geo = GeoLocationService();

  late final _diaDanhCtl = TextEditingController(
    text: widget.initial.tenDiaDanh,
  );
  bool _dangDinhVi = false;
  String? _loiKhuVuc;

  late bool _moNangCao =
      widget.initial.loaiHinh != null ||
      widget.initial.huongNha.isNotEmpty ||
      widget.initial.chiUyTin ||
      widget.initial.diemDanhGia > 0 ||
      widget.initial.saoChatLuong > 0;

  /// Trần thang trượt, tính theo ĐƠN VỊ hiển thị (tỷ hoặc triệu).
  double get _tran => widget.thangTy ? 20 : 50;
  double get _donVi => widget.thangTy ? 1000000000 : 1000000;

  late RangeValues _gia = RangeValues(
    (widget.initial.giaTu ?? 0) / _donVi,
    (widget.initial.giaDen ?? (_tran * _donVi)) / _donVi,
  );

  @override
  void initState() {
    super.initState();
    _demLai();
  }

  @override
  void dispose() {
    _hoan?.cancel();
    _diaDanhCtl.dispose();
    super.dispose();
  }

  /// Đếm sau khi người dùng NGỪNG chỉnh 400ms — kéo thanh trượt bắn ra hàng
  /// chục lần đổi giá trị, gọi API mỗi lần là tự làm nghẽn chính mình.
  void _demLai() {
    _hoan?.cancel();
    setState(() => _dangDem = true);
    _hoan = Timer(const Duration(milliseconds: 400), () async {
      final f = _hienTai();
      final n = await widget.dem(f);
      if (mounted) {
        setState(() {
          _soTin = n;
          _dangDem = false;
        });
      }
    });
  }

  TradeFilter _hienTai() {
    final tu = _gia.start * _donVi;
    final den = _gia.end * _donVi;
    return _f
        .copyWith(
          // 0 và mức trần nghĩa là "không giới hạn" → để null, nếu không nút lọc
          // sẽ sáng lên vì một tiêu chí thực ra không lọc gì.
          xoaGia: true,
        )
        .copyWith(
          giaTu: _gia.start <= 0 ? null : tu,
          giaDen: _gia.end >= _tran ? null : den,
        );
  }

  void _dat(TradeFilter f) {
    setState(() => _f = f);
    _demLai();
  }

  String _nhanGia(AppLocalizations l) {
    final dv = widget.thangTy ? l.tfBillion : l.tfMillion;
    final tu = _gia.start.toStringAsFixed(widget.thangTy ? 1 : 0);
    final den = _gia.end >= _tran
        ? l.tfNoLimit
        : '${_gia.end.toStringAsFixed(widget.thangTy ? 1 : 0)} $dv';
    return '$tu $dv – $den';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: HD.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _tayCam(l),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, HD.s16),
                children: [
                  // Khu vực đứng ĐẦU, y như bảng lọc nâng cao cũ: nó thu hẹp
                  // tập kết quả mạnh hơn mọi tiêu chí khác, chọn sau cùng thì
                  // các con số bên trên vừa xem xong đã lỗi thời.
                  ..._mucKhuVuc(l),
                  const SizedBox(height: HD.s16),

                  _muc(l.tfPrice, _nhanGia(l)),
                  RangeSlider(
                    values: _gia,
                    min: 0,
                    max: _tran,
                    divisions: widget.thangTy ? 40 : 50,
                    activeColor: HD.accent,
                    onChanged: (v) {
                      setState(() => _gia = v);
                      _demLai();
                    },
                  ),
                  const SizedBox(height: HD.s16),

                  _muc(l.tfArea, null),
                  _hangChip([
                    for (final b in AreaBucket.values)
                      (
                        nhan: _nhanDienTich(b, l),
                        chon: _f.dienTich == b,
                        cham: () => _dat(_f.copyWith(dienTich: b)),
                      ),
                  ]),
                  const SizedBox(height: HD.s16),

                  _muc(l.tfBedrooms, null),
                  _hangChip([
                    for (final n in <int?>[null, 1, 2, 3, 4])
                      (
                        nhan: n == null ? l.tfAny : (n == 4 ? '4+' : '$n'),
                        chon: _f.phongNgu == n,
                        cham: () => _dat(
                          n == null
                              ? _f.copyWith(xoaPhongNgu: true)
                              : _f.copyWith(phongNgu: n),
                        ),
                      ),
                  ]),
                  const SizedBox(height: HD.s16),

                  _muc(l.tfSort, null),
                  _hangChip([
                    for (final s in const [
                      '',
                      'price_asc',
                      'price_desc',
                      'trust',
                      'rating',
                    ])
                      (
                        nhan: switch (s) {
                          'price_asc' => l.tfSortPriceAsc,
                          'price_desc' => l.tfSortPriceDesc,
                          'trust' => l.tfSortTrust,
                          'rating' => l.tfSortRating,
                          _ => l.tfSortNewest,
                        },
                        chon: _f.sort == s,
                        cham: () => _dat(_f.copyWith(sort: s)),
                      ),
                  ]),
                  const SizedBox(height: HD.s8),

                  _nutNangCao(l),
                  if (_moNangCao) ..._mucNangCao(l),
                ],
              ),
            ),
            _thanhDay(l),
          ],
        ),
      ),
    );
  }

  String _nhanDienTich(AreaBucket b, AppLocalizations l) => switch (b) {
    AreaBucket.duoi30 => l.tfAreaUnder,
    AreaBucket.tu30den50 => l.tfArea3050,
    AreaBucket.tu50den80 => l.tfArea5080,
    AreaBucket.tren80 => l.tfAreaOver,
    _ => l.tfAny,
  };

  Widget _tayCam(AppLocalizations l) => Padding(
    padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s8, HD.s8),
    child: Row(
      children: [
        Expanded(child: Text(l.tfTitle, style: HD.bodyBold(size: 16))),
        TextButton(
          onPressed: () {
            setState(() {
              _f = const TradeFilter();
              _gia = RangeValues(0, _tran);
              _moNangCao = false;
            });
            _demLai();
          },
          child: Text(l.tfReset),
        ),
      ],
    ),
  );

  /// Tiêu đề mục + giá trị đang chọn ở bên phải — đọc lướt là biết đang lọc gì
  /// mà không phải soi từng chip.
  Widget _muc(String ten, String? giaTri) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: Row(
      children: [
        Expanded(child: Text(ten, style: HD.bodyBold(size: 14))),
        if (giaTri != null)
          Text(
            giaTri,
            style: HD.caption().copyWith(
              color: HD.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    ),
  );

  // ── Khu vực tìm kiếm ──────────────────────────────────────────────────────

  static const List<double> _banKinh = [1, 3, 5, 10];

  List<Widget> _mucKhuVuc(AppLocalizations l) {
    return [
      _muc(l.tfArea2, null),
      _hangChip([
        for (final k in KhuVuc.values)
          (
            nhan: switch (k) {
              KhuVuc.quanhDay => l.tfAreaNear,
              KhuVuc.diaDanh => l.tfAreaPlace,
              _ => l.tfAreaAll,
            },
            chon: _f.khuVuc == k,
            cham: () => _doiKhuVuc(k),
          ),
      ]),
      if (_f.khuVuc == KhuVuc.diaDanh) ...[
        const SizedBox(height: HD.s8),
        TextField(
          controller: _diaDanhCtl,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l.tfPlaceHint,
            isDense: true,
            prefixIcon: const Icon(Icons.place_outlined, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HD.r8),
            ),
          ),
          // Geocode khi người dùng NGỪNG gõ chứ không mỗi ký tự: mỗi lần là
          // một lượt gọi Nominatim, và backend giới hạn 120 lượt/giờ.
          onSubmitted: (_) => _timDiaDanh(),
          onEditingComplete: _timDiaDanh,
        ),
      ],
      if (_f.khuVuc == KhuVuc.quanhDay) ...[
        const SizedBox(height: HD.s8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _dangDinhVi ? null : _layViTri,
            icon: const Icon(Icons.my_location, size: 18),
            label: Text(
              _dangDinhVi
                  ? l.tfLocating
                  : (_f.lat != null ? l.tfLocated : l.filterGetCurrentLocation),
            ),
            style: TextButton.styleFrom(foregroundColor: HD.accent),
          ),
        ),
      ],
      if (_loiKhuVuc != null) ...[
        const SizedBox(height: 4),
        Text(_loiKhuVuc!, style: HD.caption().copyWith(color: HD.negative)),
      ],
      if (_f.khuVuc != KhuVuc.toanBo) ...[
        const SizedBox(height: HD.s8),
        _muc(l.tfRadius, '${_f.banKinhKm.toStringAsFixed(0)} km'),
        _hangChip([
          for (final r in _banKinh)
            (
              nhan: '${r.toStringAsFixed(0)} km',
              chon: _f.banKinhKm == r,
              cham: () => _dat(_f.copyWith(banKinhKm: r)),
            ),
        ]),
      ],
    ];
  }

  void _doiKhuVuc(KhuVuc k) {
    setState(() => _loiKhuVuc = null);
    if (k == KhuVuc.toanBo) {
      // Về "toàn bộ" phải XOÁ toạ độ, không chỉ đổi chế độ — giữ lại thì lần
      // sau bật "quanh đây" sẽ dùng toạ độ cũ của một buổi khác.
      _dat(_f.copyWith(khuVuc: k, xoaToaDo: true));
      return;
    }
    _dat(_f.copyWith(khuVuc: k, xoaToaDo: true));
    if (k == KhuVuc.quanhDay) _layViTri();
  }

  Future<void> _layViTri() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _dangDinhVi = true;
      _loiKhuVuc = null;
    });
    final r = await _geo.getCurrentLocation();
    if (!mounted) return;
    setState(() => _dangDinhVi = false);
    if (!r.isOk) {
      setState(
        () => _loiKhuVuc = switch (r.status) {
          GeoLocationStatus.serviceOff => l.filterLocServiceOff,
          GeoLocationStatus.denied => l.filterLocDenied,
          GeoLocationStatus.deniedForever => l.filterLocDeniedForever,
          GeoLocationStatus.outOfVietnam => l.filterLocOutOfVietnam,
          GeoLocationStatus.insecureContext => l.filterLocInsecureContext,
          _ => l.filterLocError,
        },
      );
      return;
    }
    _dat(_f.copyWith(lat: r.lat, lng: r.lng));
  }

  Future<void> _timDiaDanh() async {
    final l = AppLocalizations.of(context);
    final ten = _diaDanhCtl.text.trim();
    setState(() {
      _dangDinhVi = true;
      _loiKhuVuc = null;
    });
    try {
      final toaDo = await _repo.geocodePlace(ten);
      if (!mounted) return;
      if (toaDo == null) {
        setState(() => _loiKhuVuc = l.tfNoMatchPlace);
        _dat(_f.copyWith(tenDiaDanh: ten, xoaToaDo: true));
        return;
      }
      _dat(_f.copyWith(tenDiaDanh: ten, lat: toaDo.lat, lng: toaDo.lng));
    } catch (_) {
      if (mounted) setState(() => _loiKhuVuc = l.filterLocError);
    } finally {
      if (mounted) setState(() => _dangDinhVi = false);
    }
  }

  /// Slug hướng nhà → nhãn. Slug phải khớp tham số `direction` của backend
  /// (mig 0071), nên để nguyên tiếng Anh dù nhãn hiển thị là tiếng Việt.
  static const List<String> _huong = [
    'north',
    'northeast',
    'east',
    'southeast',
    'south',
    'southwest',
    'west',
    'northwest',
  ];

  String _nhanHuong(String slug, AppLocalizations l) => switch (slug) {
    'north' => l.tfDirN,
    'northeast' => l.tfDirNE,
    'east' => l.tfDirE,
    'southeast' => l.tfDirSE,
    'south' => l.tfDirS,
    'southwest' => l.tfDirSW,
    'west' => l.tfDirW,
    _ => l.tfDirNW,
  };

  Widget _nutNangCao(AppLocalizations l) => InkWell(
    onTap: () => setState(() => _moNangCao = !_moNangCao),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: HD.s8),
      child: Row(
        children: [
          Expanded(child: Text(l.tfAdvanced, style: HD.bodyBold(size: 14))),
          Icon(
            _moNangCao ? Icons.expand_less : Icons.expand_more,
            color: HD.inkMuted,
          ),
        ],
      ),
    ),
  );

  List<Widget> _mucNangCao(AppLocalizations l) {
    final danhMuc = widget.danhMuc;
    return [
      if (danhMuc.isNotEmpty) ...[
        _muc(l.tfPropertyType, null),
        _hangChip([
          (
            nhan: l.tfAny,
            chon: _f.loaiHinh == null,
            cham: () => _dat(_f.copyWith(xoaLoaiHinh: true)),
          ),
          for (final c in danhMuc)
            (
              nhan: '${c['name']}',
              chon: _f.loaiHinh == c['id'],
              cham: () => _dat(
                _f.loaiHinh == c['id']
                    ? _f.copyWith(xoaLoaiHinh: true)
                    : _f.copyWith(loaiHinh: c['id'] as int),
              ),
            ),
        ]),
        const SizedBox(height: HD.s16),
      ],

      _muc(l.tfDirection, null),
      _hangChip([
        for (final h in _huong)
          (
            nhan: _nhanHuong(h, l),
            chon: _f.huongNha.contains(h),
            // Chọn NHIỀU: mỗi chip tự bật/tắt, không đè lên chip đang chọn.
            cham: () => _dat(
              _f.copyWith(
                huongNha: _f.huongNha.contains(h)
                    ? ({..._f.huongNha}..remove(h))
                    : {..._f.huongNha, h},
              ),
            ),
          ),
      ]),
      const SizedBox(height: HD.s16),

      _muc(l.tfTrust, null),
      // Row + Switch chứ không SwitchListTile: ListTile vẽ nền và gợn mực lên
      // Material gần nhất, mà bảng này nằm trong một DecoratedBox có nền riêng
      // — Flutter bắt lỗi đúng trường hợp đó ngay từ chế độ debug.
      Row(
        children: [
          Expanded(child: Text(l.tfTrustedOnly, style: HD.body())),
          Switch(
            value: _f.chiUyTin,
            activeThumbColor: HD.accent,
            onChanged: (v) => _dat(_f.copyWith(chiUyTin: v)),
          ),
        ],
      ),
      const SizedBox(height: HD.s8),

      _muc(l.tfMinRating, null),
      _hangChip([
        for (final d in const [0.0, 3.5, 4.0, 4.5])
          (
            nhan: d == 0 ? l.tfAny : '★ ${d.toStringAsFixed(1)}+',
            chon: _f.diemDanhGia == d,
            cham: () => _dat(_f.copyWith(diemDanhGia: d)),
          ),
      ]),
      const SizedBox(height: HD.s16),

      _muc(l.tfMinQuality, null),
      _hangChip([
        for (final s in const [0, 3, 4, 5])
          (
            nhan: s == 0 ? l.tfAny : l.tfQualityStar(s),
            chon: _f.saoChatLuong == s,
            cham: () => _dat(_f.copyWith(saoChatLuong: s)),
          ),
      ]),
    ];
  }

  Widget _hangChip(List<({String nhan, bool chon, VoidCallback cham})> muc) =>
      Wrap(
        spacing: HD.s8,
        runSpacing: HD.s8,
        children: [
          for (final m in muc)
            DsChoiceChip(label: m.nhan, selected: m.chon, onTap: m.cham),
        ],
      );

  Widget _thanhDay(AppLocalizations l) {
    final khong = !_dangDem && _soTin == 0;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, HD.s12),
        decoration: const BoxDecoration(
          color: HD.paper,
          border: Border(top: BorderSide(color: HD.hairline)),
        ),
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: khong ? HD.neutral : HD.accent,
            ),
            // Không còn tin nào thì khoá nút lại — bấm vào chỉ để nhận một
            // danh sách rỗng thì thà nói luôn ở đây.
            onPressed: khong ? null : () => Navigator.pop(context, _hienTai()),
            child: Text(
              _dangDem
                  ? l.tfCounting
                  : (khong ? l.tfSeeNone : l.tfSeeCount(_soTin ?? 0)),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
