import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/ca_thue_api.dart';
import 'package:house_booking/data/services/ho_so_ngan_han_api.dart';
import 'package:house_booking/data/services/lich_gio_api.dart';
import 'package:house_booking/data/services/short_stay_api.dart';
import 'package:house_booking/data/services/tien_ich_phong.dart';
import 'package:house_booking/features/host/dien_nuoc/dien_nuoc_chung.dart'
    show anhTuyetDoi;
import 'package:house_booking/features/host/ngan_han/ca_thue/chi_tiet_ca_thue_screen.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/dang_o_screen.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/nhan_phong_screen.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/tra_phong_screen.dart';
import 'package:house_booking/features/host/ngan_han/lich_gio_screen.dart';
import 'package:house_booking/data/services/lich_ngan_han_api.dart';
import 'package:house_booking/features/host/ngan_han/the_lich_phong.dart';
import 'package:house_booking/features/host/ngan_han/the_su_kien_hom_nay.dart';
import 'package:house_booking/features/host/ngan_han/hop_thoai_them_ca.dart';
import 'package:house_booking/features/host/property/widgets/muc_kenh_khai_thac.dart';
import 'package:house_booking/features/host/short_stay/hop_thoai_gia_ngan_han.dart';

/// HỒ SƠ & QUẢN TRỊ PHÒNG NGẮN HẠN — dựng theo mockup "P201" (12/09/2026):
/// thẻ phòng + bảng giá giờ/đêm/ngày · 4 ô thông số · khách đang trong phòng
/// kèm tiến độ ca · lịch ca thuê trong ngày (gồm cả khoảng khoá dọn phòng) ·
/// tiền của ca hiện tại · tiện nghi · thanh dưới trả phòng & quyết toán.
///
/// Route: không — `RoomDetailScreen` mở màn này cho phòng THUẦN ngắn hạn
/// (phòng thuê tháng đi `HoSoPhongScreen`).
/// API: [HoSoNganHanApi] đọc cả màn một lượt; [ShortStayApi] cho nhận/trả
/// phòng và khoá phòng — một việc một đường.
///
/// Câu hỏi của phòng ngắn hạn khác hẳn phòng thuê tháng: không phải "hợp đồng
/// tới đâu" mà "ai đang trong phòng, còn mấy phút, ca sau là ai, trả phòng thu
/// bao nhiêu". Màn này trả lời đúng bốn câu đó theo thứ tự.
class HoSoPhongNganHanScreen extends StatefulWidget {
  const HoSoPhongNganHanScreen({
    super.key,
    required this.roomId,
    this.api = const HoSoNganHanApi(),
    this.shortStayApi = const ShortStayApi(),
    this.caThueApi = const CaThueApi(),
    this.lichGioApi = const LichGioApi(),
    this.lichApi = const LichNganHanApi(),
    this.ngayBanDau,
    this.onSua,
    this.onXoa,
    this.onNhanBan,
    this.onBaoTri,
    this.onKetThucBaoTri,
    this.onChiSo,
  });

  final int roomId;
  final HoSoNganHanApi api;
  final ShortStayApi shortStayApi;

  /// Quầy lễ tân (nhận phòng · đang ở · trả phòng) — tách riêng để test bơm
  /// giả được mà không cần mạng thật.
  final CaThueApi caThueApi;

  /// Lịch giờ 4 tuần của chính phòng này — nuôi cục lịch trong thẻ LỊCH PHÒNG.
  final LichGioApi lichGioApi;

  /// Lịch NGÀY của cả toà — nuôi thẻ "Sự kiện sắp tới trong hôm nay".
  final LichNganHanApi lichApi;

  /// 'YYYY-MM-DD' — chỉ để test ghim ngày; bình thường là hôm nay.
  final String? ngayBanDau;

  final Future<void> Function()? onSua;
  final Future<void> Function()? onXoa;
  final Future<void> Function()? onNhanBan;
  final Future<void> Function()? onBaoTri;
  final Future<void> Function()? onKetThucBaoTri;
  final Future<void> Function()? onChiSo;

  @override
  State<HoSoPhongNganHanScreen> createState() => _HoSoPhongNganHanScreenState();
}

class _HoSoPhongNganHanScreenState extends State<HoSoPhongNganHanScreen> {
  HoSoNganHan? _hs;
  String? _ngay;
  bool _dangTai = false;
  bool _dangLam = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _ngay = widget.ngayBanDau;
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final hs = await widget.api.lay(widget.roomId, ngay: _ngay);
      if (!mounted) return;
      setState(() {
        _hs = hs;
        _ngay = hs.ngay;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loi = e is ApiException ? e.message : 'Không tải được hồ sơ phòng');
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  void _bao(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _lam(Future<void> Function() viec, String xong) async {
    if (_dangLam) return;
    setState(() => _dangLam = true);
    try {
      await viec();
      if (!mounted) return;
      _bao(xong);
      await _nap();
    } catch (e) {
      if (mounted) _bao(e is ApiException ? e.message : 'Không thực hiện được');
    } finally {
      if (mounted) setState(() => _dangLam = false);
    }
  }

  // ── Thao tác ──────────────────────────────────────────────────────────────

  /// Mở một màn của quầy rồi nạp lại hồ sơ khi quay về.
  Future<void> _moQuay(Widget man) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => man),
    );
    if (mounted) await _nap();
  }

  /// Nhận phòng đi qua ĐỦ ba bước (đối chiếu giấy tờ · bàn giao · thu tiền).
  /// Đổi trạng thái trần thì luôn có ca quên thu tiền.
  Future<void> _nhanPhong(KhachDangO k) => _moQuay(
    NhanPhongScreen(reservationId: k.reservationId, api: widget.caThueApi),
  );

  /// Trả phòng đi qua thủ tục check-out đầy đủ: đối chiếu giờ thực ở, kiểm
  /// phòng, quyết toán thu/hoàn, rồi khoá phòng để dọn.
  Future<void> _traPhong(KhachDangO k) => _moQuay(
    TraPhongScreen(reservationId: k.reservationId, api: widget.caThueApi),
  );

  /// Khách đang trong phòng: màn trực (gia hạn nhanh, minibar, tạm tính).
  Future<void> _quanLyDangO(KhachDangO k) => _moQuay(
    DangOScreen(reservationId: k.reservationId, api: widget.caThueApi),
  );


  Future<void> _themCa() async {
    final hs = _hs;
    if (hs == null) return;
    final ra = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HopThoaiThemCa(
        roomId: hs.roomId,
        maPhong: hs.maPhong,
        giaGio: hs.giaGio,
        giaQuaDem: hs.giaQuaDem,
        giaNgay: hs.giaNgay,
      ),
    );
    if (ra == null || !mounted) return;
    _bao('Đã mở ca thuê mới.');
    await _nap();
  }

  /// Khoá phòng để dọn — đúng cái khe "đệm dọn phòng" trên lịch.
  Future<void> _khoaDon() async {
    final phut = await showModalBottomSheet<int>(
      context: context,
      builder: (d) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(HD.s16),
              child: Text('Khoá phòng để dọn trong', style: HD.bodyBold(size: 15)),
            ),
            for (final p in const [30, 60, 90, 120])
              ListTile(
                key: ValueKey('khoa-$p'),
                leading: const Icon(Icons.cleaning_services_outlined),
                title: Text('$p phút'),
                onTap: () => Navigator.pop(d, p),
              ),
          ],
        ),
      ),
    );
    if (phut == null) return;
    final tu = DateTime.now().add(const Duration(minutes: 1));
    await _lam(
      () => widget.shortStayApi.block(
        widget.roomId,
        DateTime(tu.year, tu.month, tu.day, tu.hour, tu.minute),
        DateTime(tu.year, tu.month, tu.day, tu.hour, tu.minute)
            .add(Duration(minutes: phut)),
        'Dọn phòng',
      ),
      'Đã khoá phòng $phut phút để dọn.',
    );
  }

  Future<void> _suaGia() async {
    final hs = _hs;
    if (hs == null) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HopThoaiGiaNganHan(
        roomId: hs.roomId,
        banDau: {
          if (hs.giaGio != null) 'gia_theo_gio': hs.giaGio,
          if (hs.giaQuaDem != null) 'gia_qua_dem': hs.giaQuaDem,
          if (hs.giaNgay != null) 'gia_theo_ngay': hs.giaNgay,
        },
      ),
    );
    if (ok == true && mounted) await _nap();
  }

  Future<void> _goi(String sdt) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: sdt));
    if (!ok && mounted) {
      await Clipboard.setData(ClipboardData(text: sdt));
      if (mounted) _bao('Đã sao chép số $sdt');
    }
  }

  Future<void> _xemDon(int id) => _moQuay(
    ChiTietCaThueScreen(reservationId: id, api: widget.caThueApi),
  );

  /// SƠ ĐỒ GIỜ của CHÍNH phòng này, 4 tuần liền: hàng = ngày, cột = giờ.
  /// Phòng theo giờ bán ba bốn ca một ngày nên phải nhìn trên trục giờ mới
  /// thấy khe trống; sơ đồ cả toà theo ngày nằm sau một nút trong đó.
  Future<void> _moLich() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LichGioScreen(roomId: widget.roomId),
      ),
    );
    if (mounted) await _nap();
  }

  Future<void> _moKenh() async {
    final hs = _hs;
    if (hs == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(HD.s16),
        child: SingleChildScrollView(child: MucKenhKhaiThac(roomId: hs.roomId)),
      ),
    );
    if (mounted) await _nap();
  }



  // ── Dựng màn ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hs = _hs;
    return Scaffold(
      backgroundColor: HD.paper,
      bottomNavigationBar: hs == null ? null : _thanhDuoi(hs),
      body: SafeArea(
        child: Column(
          children: [
            _thanhTren(hs),
            Expanded(
              child: RefreshIndicator(
                color: HD.accent,
                onRefresh: _nap,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  children: [
                    if (_dangTai && hs != null)
                      const Padding(
                        padding: EdgeInsets.only(bottom: HD.s8),
                        child: LinearProgressIndicator(minHeight: 2, color: HD.accent),
                      ),
                    if (_loi != null)
                      Text(_loi!, style: HD.body(size: 13, color: HD.negative))
                    else if (hs == null)
                      const Padding(
                        padding: EdgeInsets.all(HD.s32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      _hero(hs),
                      const SizedBox(height: 12),
                      _daiHang(hs),
                      _boNThongSo(hs),
                      const SizedBox(height: 12),
                      if (hs.khach != null)
                        _theKhach(hs, hs.khach!)
                      else
                        _thePhongTrong(hs),
                      const SizedBox(height: 12),
                      _theLich(hs),
                      const SizedBox(height: 12),
                      // Việc của quầy trong hôm nay, CẢ TOÀ: người trực chỉ có
                      // một đôi tay nên cần "việc kế tiếp là gì", không phải
                      // "phòng này có việc gì".
                      TheSuKienHomNay(
                        buildingId: hs.buildingId,
                        roomIdNhanManh: widget.roomId,
                        api: widget.lichApi,
                        shortStayApi: widget.shortStayApi,
                        caThueApi: widget.caThueApi,
                      ),
                      if (hs.khach != null && hs.xemTaiChinh) ...[
                        const SizedBox(height: 12),
                        _theTien(hs.khach!),
                      ],
                      if (hs.doTrongPhong.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _theTienNghi(hs),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thanhTren(HoSoNganHan? hs) {
    final tt = _nhanPhongTrangThai(hs);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(HD.s8, HD.s8, HD.s12, HD.s8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Phòng ${hs?.maPhong ?? ''}',
                        overflow: TextOverflow.ellipsis,
                        style: HD.bodyBold(size: 17),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _NhanTron(chu: tt.chu, mau: tt.mau, icon: tt.icon),
                  ],
                ),
                Text(
                  '${hs?.tenToa ?? ''} • Lưu trú ngắn hạn',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.body(size: 11, color: HD.inkMuted),
                ),
              ],
            ),
          ),
          _menu(),
        ],
      ),
    );
  }

  Widget _menu() {
    final muc = <(String, String, bool)>[
      if (widget.onSua != null) ('sua', 'Sửa phòng', false),
      ('gia', 'Sửa giá giờ / đêm / ngày', false),
      ('kenh', 'Kênh khai thác', false),
      ('lich', 'Lịch phòng', false),
      if (widget.onChiSo != null) ('chi_so', 'Chỉ số điện nước', false),
      if (widget.onNhanBan != null) ('nhan_ban', 'Nhân bản phòng', false),
      if (widget.onBaoTri != null) ('bao_tri', 'Báo sự cố / bảo trì', false),
      if (widget.onKetThucBaoTri != null)
        ('ket_thuc_bao_tri', 'Kết thúc bảo trì', false),
      if (widget.onXoa != null) ('xoa', 'Xoá phòng', true),
    ];
    return PopupMenuButton<String>(
      key: const ValueKey('menu-ngan-han'),
      tooltip: 'Thao tác với phòng',
      position: PopupMenuPosition.under,
      onSelected: (k) async {
        switch (k) {
          case 'sua':
            await widget.onSua?.call();
            if (mounted) await _nap();
          case 'gia':
            await _suaGia();
          case 'kenh':
            await _moKenh();
          case 'lich':
            await _moLich();
          case 'chi_so':
            await widget.onChiSo?.call();
          case 'nhan_ban':
            await widget.onNhanBan?.call();
          case 'bao_tri':
            await widget.onBaoTri?.call();
            if (mounted) await _nap();
          case 'ket_thuc_bao_tri':
            await widget.onKetThucBaoTri?.call();
            if (mounted) await _nap();
          case 'xoa':
            await widget.onXoa?.call();
        }
      },
      itemBuilder: (_) => [
        for (final (k, nhan, do_) in muc)
          PopupMenuItem(
            value: k,
            child: Text(
              nhan,
              style: HD.body(size: 13, color: do_ ? HD.negative : HD.ink),
            ),
          ),
      ],
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(color: HD.paperSunken, shape: BoxShape.circle),
        child: const Icon(Icons.more_vert, size: 18, color: HD.inkSoft),
      ),
    );
  }

  Widget _hero(HoSoNganHan hs) {
    final anh = hs.anh.isEmpty ? null : hs.anh.first;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HD.r12),
        child: Stack(
          children: [
            SizedBox(
              height: 180,
              width: double.infinity,
              child: anh == null
                  ? const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                        ),
                      ),
                      child: Center(
                        child: Icon(Icons.hotel, size: 44, color: Colors.white38),
                      ),
                    )
                  : Image.network(
                      anhTuyetDoi(anh),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: HD.paperSunken),
                    ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              top: 10,
              right: 10,
              child: Row(
                children: [
                  if (hs.loaiPhong != null || hs.dienTich != null)
                    _KinhMo(
                      chu: [
                        if (hs.loaiPhong != null) hs.loaiPhong!,
                        if (hs.dienTich != null) '${_so(hs.dienTich!)} m²',
                      ].join(' • '),
                    ),
                  const Spacer(),
                  if (hs.anh.length > 1) _KinhMo(chu: '1/${hs.anh.length}'),
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bảng giá ngắn hạn niêm yết',
                          style: HD.body(size: 11, color: Colors.white70),
                        ),
                        const SizedBox(height: 2),
                        _bangGia(hs),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('sua-gia-ngan-han'),
                    onPressed: _suaGia,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: HD.ink,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(HD.r12),
                      ),
                      textStyle: HD.bodyBold(size: 12),
                    ),
                    icon: const Icon(Icons.edit, size: 13),
                    label: const Text('Sửa giá'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bangGia(HoSoNganHan hs) {
    final phan = <Widget>[];
    void them(double? gia, String don, Color mau) {
      if (gia == null) return;
      if (phan.isNotEmpty) {
        phan.add(Text(' • ', style: HD.body(size: 12, color: Colors.white38)));
      }
      phan.add(
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: PriceFormat.full(gia),
                style: HD.bodyBold(size: 16, color: mau),
              ),
              TextSpan(
                text: '/$don',
                style: HD.body(size: 11, color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    them(hs.giaGio, 'giờ', Colors.white);
    them(hs.giaQuaDem, 'đêm', const Color(0xFFFDA4AF));
    them(hs.giaNgay, 'ngày', Colors.white);
    if (phan.isEmpty) {
      return Text(
        'Chưa khai giá — bấm "Sửa giá"',
        style: HD.bodyBold(size: 13, color: Colors.white),
      );
    }
    return Wrap(crossAxisAlignment: WrapCrossAlignment.end, children: phan);
  }

  /// Tồn kho của HẠNG. Khách đặt hạng chứ không đặt số phòng, nên câu hỏi ở
  /// quầy luôn là "hạng này còn phòng không" — trả lời được ngay tại đây thì
  /// người trực khỏi mở màn khác giữa lúc khách đứng đợi.
  Widget _daiHang(HoSoNganHan hs) {
    if (hs.hangId == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(HD.s12),
          decoration: BoxDecoration(
            color: HD.warningTint,
            borderRadius: BorderRadius.circular(HD.r12),
            border: Border.all(color: HD.warning.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 17, color: HD.svcAmber),
              const SizedBox(width: HD.s8),
              Expanded(
                child: Text(
                  'Phòng chưa xếp hạng — khách không đặt được theo loại phòng.',
                  style: HD.body(size: 12, color: HD.inkSoft),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        key: const ValueKey('dai-hang'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
        ),
        child: Row(
          children: [
            const Icon(Icons.category_outlined, size: 16, color: HD.svcIndigo),
            const SizedBox(width: HD.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hs.loaiPhong ?? 'Hạng phòng',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.bodyBold(size: 13),
                  ),
                  Text(
                    [
                      if (hs.hangGiuong != null) hs.hangGiuong!,
                      if (hs.hangSucChua > 0) '${hs.hangSucChua} khách',
                      if (!hs.hangDangBan) 'Đang ngừng bán',
                    ].join(' • '),
                    style: HD.body(size: 11, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${hs.hangTrong}',
                    style: HD.bodyBold(
                      size: 17,
                      color: hs.hangTrong > 0 ? HD.positive : HD.negative,
                    ),
                  ),
                  TextSpan(
                    text: '/${hs.hangSoPhong} phòng trống',
                    style: HD.body(size: 11.5, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boNThongSo(HoSoNganHan hs) {
    final o = <(IconData, Color, String, String?)>[
      (Icons.straighten, HD.accent, 'Diện tích',
          hs.dienTich == null ? null : '${_so(hs.dienTich!)} m²'),
      (Icons.layers_outlined, HD.svcIndigo, 'Vị trí',
          (hs.tang ?? '').isEmpty ? null : 'Tầng ${hs.tang}'),
      (Icons.bed_outlined, HD.svcAmber, 'Loại phòng', hs.loaiPhong),
      (Icons.people_alt_outlined, HD.positive, 'Sức chứa', '${hs.sucChua} khách'),
    ];
    return Row(
      children: [
        for (var i = 0; i < o.length; i++) ...[
          if (i > 0) const SizedBox(width: HD.s8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(HD.r12),
                border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: o[i].$2.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(HD.r12),
                    ),
                    child: Icon(o[i].$1, size: 16, color: o[i].$2),
                  ),
                  const SizedBox(height: 6),
                  Text(o[i].$3, style: HD.body(size: 10, color: HD.inkMuted)),
                  Text(
                    o[i].$4 ?? 'Chưa khai',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.bodyBold(
                      size: 12,
                      color: o[i].$4 == null ? HD.inkMuted : HD.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _theKhach(HoSoNganHan hs, KhachDangO k) => _The(
    key: const ValueKey('khach-dang-o'),
    cham: k.quaGio ? HD.negative : HD.positive,
    tieuDe: k.daNhanPhong ? 'KHÁCH ĐANG TRONG PHÒNG' : 'CA SẮP TỚI',
    phai: k.maDat == null
        ? null
        : Text('Mã đặt: ${k.maDat}', style: HD.body(size: 11, color: HD.inkMuted)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: HD.accentTint,
                borderRadius: BorderRadius.circular(HD.r12),
              ),
              child: Icon(
                k.daNhanPhong ? Icons.how_to_reg : Icons.schedule,
                color: HD.accent,
              ),
            ),
            const SizedBox(width: HD.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          k.ten ?? 'Khách đang ở',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HD.bodyBold(size: 14),
                        ),
                      ),
                      _NhanTron(
                        chu: k.nhanKieu,
                        mau: HD.svcIndigo,
                        icon: Icons.timelapse,
                      ),
                    ],
                  ),
                  if ((k.sdt ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        k.sdt!,
                        style: HD.body(size: 11.5, color: HD.inkMuted),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: HD.s8, vertical: 4),
                    decoration: BoxDecoration(
                      color: HD.paper,
                      borderRadius: BorderRadius.circular(HD.r8),
                    ),
                    child: Text(
                      'Nhận ${_gio(k.vao)}  •  Trả dự kiến ${_gio(k.ra)}',
                      style: HD.body(size: 11.5, color: HD.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: HD.s12),
        _tienDo(k),
        const SizedBox(height: HD.s12),
        Row(
          children: [
            Expanded(
              // Khách đã vào phòng thì việc của quầy là PHỤC VỤ (gia hạn,
              // minibar, tạm tính), chưa vào thì là xem lại đơn.
              child: k.daNhanPhong
                  ? _NutNho(
                      khoa: const ValueKey('phuc-vu-phong'),
                      icon: Icons.room_service_outlined,
                      mau: HD.svcIndigo,
                      chu: 'Phục vụ',
                      onTap: () => _quanLyDangO(k),
                    )
                  : _NutNho(
                      khoa: const ValueKey('xem-don'),
                      icon: Icons.receipt_long_outlined,
                      mau: HD.svcIndigo,
                      chu: 'Xem đơn',
                      onTap: () => _xemDon(k.reservationId),
                    ),
            ),
            if ((k.sdt ?? '').isNotEmpty) ...[
              const SizedBox(width: HD.s8),
              Expanded(
                child: _NutNho(
                  khoa: const ValueKey('goi-khach'),
                  icon: Icons.phone,
                  mau: HD.positive,
                  chu: 'Gọi khách',
                  onTap: () => _goi(k.sdt!),
                ),
              ),
            ],
            const SizedBox(width: HD.s8),
            Expanded(
              child: k.daNhanPhong
                  ? _NutNho(
                      khoa: const ValueKey('tra-phong'),
                      icon: Icons.logout,
                      mau: HD.accent,
                      chu: 'Trả phòng',
                      onTap: () => _traPhong(k),
                    )
                  : _NutNho(
                      khoa: const ValueKey('nhan-phong'),
                      icon: Icons.login,
                      mau: HD.accent,
                      chu: 'Nhận phòng',
                      onTap: () => _nhanPhong(k),
                    ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _tienDo(KhachDangO k) {
    final ty = (k.phanTram / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tiến độ ca (${k.nhanKieu.toLowerCase()})',
                style: HD.body(size: 12, color: HD.inkMuted),
              ),
            ),
            Text(
              k.quaGio
                  ? 'Quá giờ ${_khoang(-k.conPhut)}'
                  : 'Còn ${_khoang(k.conPhut)}',
              key: const ValueKey('con-lai-ca'),
              style: HD.bodyBold(
                size: 12,
                color: k.quaGio ? HD.negative : HD.svcAmber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: ty,
            minHeight: 9,
            backgroundColor: HD.paperSunken,
            color: k.quaGio ? HD.negative : HD.accent,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              'Đã ở ${_khoang(k.daOPhut)}',
              style: HD.body(size: 10, color: HD.inkMuted),
            ),
            const Spacer(),
            Text(
              'Trả ${_gio(k.ra)}',
              style: HD.body(size: 10, color: HD.inkMuted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _thePhongTrong(HoSoNganHan hs) => _The(
    key: const ValueKey('phong-trong'),
    cham: HD.inkMuted,
    tieuDe: 'PHÒNG ĐANG TRỐNG',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // KHÔNG lặp lại nút "Mở ca" ở đây: thanh dưới luôn hiện và đã mang
        // đúng nút đó. Hai nút đỏ giống hệt nhau cách nhau 40px làm người dùng
        // dừng lại đọc xem chúng có khác gì không.
        Text(
          hs.kenhBat
              ? 'Chưa có ai trong phòng. Khách vãng lai tới thì bấm "Mở ca cho '
                    'khách vãng lai" ở thanh dưới.'
              : 'Kênh ngắn hạn đang TẮT nên phòng không hiện trên chợ. Bật ở "Kênh khai thác".',
          style: HD.body(size: 12.5, color: HD.inkSoft),
        ),
      ],
    ),
  );

  /// LỊCH PHÒNG & CA THUÊ — cục lịch 4 tuần + sơ đồ giờ của ngày đang chọn +
  /// danh sách ca. Ba tab "Hôm nay/Ngày mai/Ngày kia" cũ chỉ nhìn được ba ngày,
  /// trong khi nhận đặt trước phải thấy cả tháng.
  Widget _theLich(HoSoNganHan hs) => _The(
    key: const ValueKey('lich-ngay'),
    cham: HD.svcIndigo,
    tieuDe: 'LỊCH PHÒNG & CA THUÊ',
    phai: hs.xemTaiChinh && hs.doanhThuNgay > 0
        ? Text(
            PriceFormat.full(hs.doanhThuNgay),
            style: HD.bodyBold(size: 12, color: HD.accent),
          )
        : null,
    child: TheLichPhong(
      roomId: widget.roomId,
      ngayChon: hs.ngay,
      api: widget.lichGioApi,
      caThueApi: widget.caThueApi,
      onChonNgay: (iso) {
        setState(() => _ngay = iso);
        _nap();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hs.lich.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: HD.s8),
              child: Text(
                'Ngày ${_ngayVN(hs.ngay)} chưa có ca nào.',
                style: HD.body(size: 12, color: HD.inkMuted),
              ),
            )
          else
            for (final m in hs.lich) ...[
              _MucLichO(
                muc: m,
                xemTien: hs.xemTaiChinh,
                onTap: m.laChan ? null : () => _xemDon(m.id),
              ),
              const SizedBox(height: HD.s8),
            ],
          Row(
            children: [
              Expanded(
                child: _NutNho(
                  khoa: const ValueKey('them-ca'),
                  icon: Icons.add_circle_outline,
                  mau: HD.accent,
                  chu: 'Thêm ca vào lịch',
                  onTap: _themCa,
                ),
              ),
              const SizedBox(width: HD.s8),
              Expanded(
                child: _NutNho(
                  khoa: const ValueKey('khoa-don-phong'),
                  icon: Icons.cleaning_services_outlined,
                  mau: HD.svcBlue,
                  chu: 'Khoá để dọn',
                  onTap: _khoaDon,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _theTien(KhachDangO k) => _The(
    key: const ValueKey('tai-chinh-ca'),
    cham: HD.accent,
    tieuDe: 'TIỀN CỦA CA HIỆN TẠI',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _OTien(
                nhan: 'Cọc đã nhận',
                so: PriceFormat.full(k.coc ?? 0),
                mau: HD.positive,
                nen: HD.positiveTint,
              ),
            ),
            const SizedBox(width: HD.s8),
            Expanded(
              child: _OTien(
                nhan: 'Cần thu khi trả phòng',
                so: PriceFormat.full(k.conThu ?? 0),
                mau: HD.accent,
                nen: HD.accentTint,
              ),
            ),
          ],
        ),
        const SizedBox(height: HD.s12),
        _dongTien('Tiền phòng (${k.nhanKieu.toLowerCase()})', k.tong ?? 0),
        _dongTien('Cọc đã nhận', -(k.coc ?? 0), mau: HD.positive),
        const Divider(height: HD.s16, color: HD.hairline),
        Row(
          children: [
            Expanded(child: Text('Còn phải thu', style: HD.bodyBold(size: 14))),
            Text(
              PriceFormat.full(k.conThu ?? 0),
              style: HD.bodyBold(size: 17, color: HD.accent),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _dongTien(String nhan, double tien, {Color? mau}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(nhan, style: HD.body(size: 12.5, color: HD.inkSoft))),
        Text(
          tien < 0 ? '-${PriceFormat.full(-tien)}' : PriceFormat.full(tien),
          style: HD.bodyBold(size: 12.5, color: mau),
        ),
      ],
    ),
  );

  Widget _theTienNghi(HoSoNganHan hs) => _The(
    cham: HD.svcAmber,
    tieuDe: 'THIẾT BỊ & TIỆN NGHI PHÒNG',
    child: Wrap(
      spacing: HD.s8,
      runSpacing: HD.s8,
      children: [
        for (final ten in tenTienIch(hs.doTrongPhong, kDoTrongPhong))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: HD.paper,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: HD.hairline),
            ),
            child: Text(ten, style: HD.body(size: 12, color: HD.inkSoft)),
          ),
      ],
    ),
  );

  Widget _thanhDuoi(HoSoNganHan hs) {
    final k = hs.khach;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, HD.s12, 14, HD.s12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: HD.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _NutVuong(
              khoa: const ValueKey('mo-lich-phong'),
              icon: Icons.calendar_month_outlined,
              chu: 'Lịch',
              onTap: _moLich,
            ),
            const SizedBox(width: HD.s8),
            Expanded(
              child: SizedBox(
                height: 46,
                child: k != null && k.daNhanPhong
                    ? FilledButton.icon(
                        key: const ValueKey('checkout-quyet-toan'),
                        onPressed: _dangLam ? null : () => _traPhong(k),
                        style: _kieuChinh(),
                        icon: const Icon(Icons.receipt_long, size: 18),
                        label: Text(
                          hs.xemTaiChinh && (k.conThu ?? 0) > 0
                              ? 'Trả phòng · thu ${PriceFormat.compact(k.conThu!)}'
                              : 'Trả phòng & quyết toán',
                        ),
                      )
                    : k != null
                    ? FilledButton.icon(
                        key: const ValueKey('nhan-phong-chinh'),
                        onPressed: _dangLam ? null : () => _nhanPhong(k),
                        style: _kieuChinh(),
                        icon: const Icon(Icons.login, size: 18),
                        label: const Text('Nhận phòng cho khách'),
                      )
                    : FilledButton.icon(
                        key: const ValueKey('mo-ca-chinh'),
                        onPressed: _dangLam ? null : _themCa,
                        style: _kieuChinh(),
                        icon: const Icon(Icons.person_add_alt, size: 18),
                        label: const Text('Mở ca cho khách vãng lai'),
                      ),
              ),
            ),
            const SizedBox(width: HD.s8),
            _NutVuong(
              khoa: const ValueKey('cai-dat-phong'),
              icon: Icons.tune,
              chu: 'Cài đặt',
              onTap: _moKenh,
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _kieuChinh() => FilledButton.styleFrom(
    backgroundColor: HD.accent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HD.r12)),
    textStyle: HD.bodyBold(size: 13),
  );

  ({String chu, Color mau, IconData icon}) _nhanPhongTrangThai(HoSoNganHan? hs) {
    if (hs == null) return (chu: '—', mau: HD.inkMuted, icon: Icons.circle);
    if (hs.trangThaiPhong == 'maintenance') {
      return (chu: 'Bảo trì', mau: HD.svcAmber, icon: Icons.build_circle);
    }
    final k = hs.khach;
    if (k != null && k.quaGio) {
      return (chu: 'Quá giờ trả', mau: HD.negative, icon: Icons.error_outline);
    }
    if (k != null && k.daNhanPhong) {
      return (chu: 'Đang có khách', mau: HD.positive, icon: Icons.person);
    }
    if (k != null) {
      return (chu: 'Sắp có khách', mau: HD.svcIndigo, icon: Icons.schedule);
    }
    return (chu: 'Trống', mau: HD.inkMuted, icon: Icons.meeting_room_outlined);
  }
}

// ── Định dạng ────────────────────────────────────────────────────────────────

String _hai(int n) => n.toString().padLeft(2, '0');


String _gio(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  return d == null ? '—' : '${_hai(d.hour)}:${_hai(d.minute)}';
}

String _ngayVN(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : '${_hai(d.day)}/${_hai(d.month)}';
}

/// 135 → '2h15'. Đọc "còn 135 phút" thì phải tự chia trong đầu.
String _khoang(int phut) {
  final p = phut.abs();
  if (p < 60) return '$p phút';
  final gio = p ~/ 60;
  final du = p % 60;
  return du == 0 ? '${gio}h' : '${gio}h$du';
}

String _so(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

// ── Mảnh dùng lại ────────────────────────────────────────────────────────────

class _The extends StatelessWidget {
  const _The({
    super.key,
    required this.tieuDe,
    required this.child,
    this.cham = HD.accent,
    this.phai,
  });

  final String tieuDe;
  final Widget child;
  final Color cham;
  final Widget? phai;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: cham, shape: BoxShape.circle),
            ),
            const SizedBox(width: HD.s8),
            Expanded(
              child: Text(
                tieuDe,
                style: HD.bodyBold(size: 11.5, color: HD.inkSoft),
              ),
            ),
            if (phai != null) phai!,
          ],
        ),
        const SizedBox(height: HD.s12),
        child,
      ],
    ),
  );
}

class _MucLichO extends StatelessWidget {
  const _MucLichO({required this.muc, required this.xemTien, this.onTap});

  final MucLich muc;
  final bool xemTien;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chan = muc.laChan;
    final (mau, icon, nhan) = chan
        ? (HD.svcBlue, Icons.cleaning_services_outlined, 'Khoá phòng')
        : switch (muc.trangThai) {
            'checked_in' => (HD.positive, Icons.how_to_reg, 'Đang trong phòng'),
            'approved' => (HD.svcIndigo, Icons.event_available, 'Đã xác nhận'),
            _ => (HD.svcAmber, Icons.hourglass_empty, 'Chờ duyệt'),
          };
    return InkWell(
      key: ValueKey('lich-${muc.loai}-${muc.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(HD.r12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: mau.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: mau.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: mau, shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: Colors.white),
            ),
            const SizedBox(width: HD.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_gio(muc.tu)} – ${_gio(muc.den)}',
                          style: HD.bodyBold(size: 12, color: HD.ink),
                        ),
                      ),
                      if (!chan)
                        _NhanTron(chu: muc.nhanKieu, mau: mau, icon: Icons.timer_outlined),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chan
                        ? (muc.ghiChu ?? 'Khoá tay')
                        : (muc.ten ?? 'Ca thuê #${muc.id}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 12, color: HD.inkSoft),
                  ),
                  if (!chan)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nhan,
                            style: HD.body(size: 11, color: mau),
                          ),
                        ),
                        if (xemTien && muc.tong != null)
                          Text(
                            PriceFormat.full(muc.tong!),
                            style: HD.bodyBold(size: 12),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OTien extends StatelessWidget {
  const _OTien({
    required this.nhan,
    required this.so,
    required this.mau,
    required this.nen,
  });

  final String nhan;
  final String so;
  final Color mau;
  final Color nen;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: nen,
      borderRadius: BorderRadius.circular(HD.r12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nhan, style: HD.body(size: 11, color: HD.inkSoft)),
        const SizedBox(height: 4),
        Text(so, style: HD.bodyBold(size: 16, color: mau)),
      ],
    ),
  );
}

class _NutNho extends StatelessWidget {
  const _NutNho({
    required this.khoa,
    required this.icon,
    required this.mau,
    required this.chu,
    required this.onTap,
  });

  final Key khoa;
  final IconData icon;
  final Color mau;
  final String chu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: khoa,
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: mau,
      side: BorderSide(color: mau.withValues(alpha: 0.4)),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HD.r12)),
      textStyle: HD.bodyBold(size: 12),
    ),
    icon: Icon(icon, size: 15),
    label: Text(chu, maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

class _NutVuong extends StatelessWidget {
  const _NutVuong({
    required this.khoa,
    required this.icon,
    required this.chu,
    required this.onTap,
  });

  final Key khoa;
  final IconData icon;
  final String chu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: khoa,
    color: HD.paperSunken,
    borderRadius: BorderRadius.circular(HD.r12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HD.r12),
      child: SizedBox(
        width: 46,
        height: 46,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: HD.inkSoft),
            Text(chu, style: HD.body(size: 9, color: HD.inkMuted)),
          ],
        ),
      ),
    ),
  );
}

class _KinhMo extends StatelessWidget {
  const _KinhMo({required this.chu});

  final String chu;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(HD.r8),
    ),
    child: Text(chu, style: HD.body(size: 11, color: Colors.white)),
  );
}

class _NhanTron extends StatelessWidget {
  const _NhanTron({required this.chu, required this.mau, required this.icon});

  final String chu;
  final Color mau;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: HD.s8, vertical: 3),
    decoration: BoxDecoration(
      color: mau.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: mau),
        const SizedBox(width: 4),
        Text(chu, style: HD.bodyBold(size: 10.5, color: mau)),
      ],
    ),
  );
}
