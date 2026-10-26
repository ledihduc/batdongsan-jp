import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/config/env.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/full_image_viewer.dart';
import 'package:house_booking/data/models/room_model.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/ho_so_phong_api.dart';
import 'package:house_booking/data/services/kenh_khai_thac_api.dart';
import 'package:house_booking/features/host/billing/providers/invoice_provider.dart';
import 'package:house_booking/features/host/billing/screens/invoice_detail_screen.dart';
import 'package:house_booking/features/host/billing/screens/invoice_list_screen.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/dien_nuoc/dien_nuoc_dai_han_screen.dart';
import 'package:house_booking/data/services/cho_thue_ngoai_api.dart';
import 'package:house_booking/features/host/property/widgets/hop_thoai_cho_thue_ngoai.dart';
import 'package:house_booking/features/host/property/providers/contract_provider.dart';
import 'package:house_booking/features/host/property/screens/contract_detail_screen.dart';
import 'package:house_booking/features/host/property/screens/contract_terminate_screen.dart';
import 'package:house_booking/features/host/property/screens/room_detail_contracts_section.dart';
import 'package:house_booking/features/host/property/screens/tai_san_phong_screen.dart';
import 'package:house_booking/features/host/property/widgets/ghi_sua_chua_sheet.dart';
import 'package:house_booking/features/host/property/widgets/muc_kenh_khai_thac.dart';
import 'package:house_booking/features/host/property/widgets/room_grid_card.dart'
    show NhanTinhTrang;
import 'package:house_booking/features/host/property/widgets/tai_san_phong_sheet.dart';
import 'package:house_booking/features/host/property/widgets/thanh_toan_hop_dong_sheet.dart';

/// HỒ SƠ PHÒNG — chi tiết một phòng THUÊ THÁNG (dài hạn / mặt bằng), dựng theo
/// mockup "Hồ sơ phòng P101" (11/09/2026): ảnh + giá niêm yết · bốn ô thông số
/// · khách thuê hiện tại + tiến độ hợp đồng · tài chính & tiền cọc · đồng hồ
/// điện nước · tài sản trong phòng · lịch sử sửa chữa · thao tác trạng thái ·
/// thanh "Lập hóa đơn tháng này". Route: không — `RoomDetailScreen` mở màn này
/// cho phòng thuê tháng; phòng ngắn hạn vẫn dùng màn cũ. Provider:
/// [ContractProvider] (bơm từ `RoomDetailScreen`). API: [HoSoPhongApi]
/// (`GET /api/host/rooms/{id}/ho-so`).
///
/// Mọi số là số đo thật. Khối không có dữ liệu thì ẨN, hoặc ghi "Chưa khai" và
/// dẫn tới nơi khai — không in số minh hoạ. Mockup có vài thứ hệ thống chưa ghi
/// nhận (hãng / thông số từng món đồ, ngày thu tiền cố định, đã đóng đủ cọc
/// chưa): màn không bịa chúng.
///
/// Người xem không phải chủ phòng (sale phụ trách) thấy phòng có người, không
/// thấy là ai, trả bao nhiêu — server đã giữ lại; màn không vẽ ô trống thế chỗ.
class HoSoPhongScreen extends StatefulWidget {
  const HoSoPhongScreen({
    super.key,
    required this.room,
    required this.contractProvider,
    this.api = const HoSoPhongApi(),
    this.kenhApi,
    this.choThueNgoaiApi = const ChoThueNgoaiApi(),
    this.onSua,
    this.onXoa,
    this.onNhanBan,
    this.onBaoTri,
    this.onKetThucBaoTri,
    this.onChiSo,
    this.onTaoHopDong,
  });

  /// Bản đang có trong sổ phòng — hiện ngay trong lúc chờ hồ sơ tải về.
  final RoomModel room;
  final ContractProvider contractProvider;
  final HoSoPhongApi api;

  /// Chỉ để test bơm API kênh giả cho mục "Kênh khai thác".
  final KenhKhaiThacApi? kenhApi;

  /// Đánh dấu phòng đã cho thuê NGOÀI APP (và gỡ dấu khi bấm nhầm).
  final ChoThueNgoaiApi choThueNgoaiApi;

  /// Thao tác sẵn có của chi tiết phòng. `RoomDetailScreen` giữ logic (hộp
  /// thoại, provider); màn này gọi rồi nạp lại hồ sơ.
  final Future<void> Function()? onSua;
  final Future<void> Function()? onXoa;
  final Future<void> Function()? onNhanBan;
  final Future<void> Function()? onBaoTri;
  final Future<void> Function()? onKetThucBaoTri;
  final Future<void> Function()? onChiSo;
  final Future<void> Function()? onTaoHopDong;

  @override
  State<HoSoPhongScreen> createState() => _HoSoPhongScreenState();
}

class _HoSoPhongScreenState extends State<HoSoPhongScreen> {
  HoSoPhong? _hs;
  String? _loi;
  bool _dangTai = false;
  bool _dangLapHoaDon = false;
  bool _hetSuaChua = false;

  RoomModel get _p => _hs?.room ?? widget.room;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  Future<void> _nap() async {
    if (!mounted) return;
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final hs = await widget.api.lay(widget.room.id);
      if (mounted) setState(() => _hs = hs);
    } catch (_) {
      if (mounted) {
        setState(() => _loi = 'Không tải được hồ sơ phòng. Kéo xuống để thử lại.');
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  // ── Hành động ─────────────────────────────────────────────────────────────

  Future<void> _lam(Future<void> Function()? viec) async {
    if (viec == null) return;
    await viec();
    await _nap();
  }

  Future<void> _moRoiNap(Widget man) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => man));
    await _nap();
  }

  void _bao(String chu) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(chu)));

  Future<void> _xemHopDong(int id) => _moRoiNap(
    ChangeNotifierProvider.value(
      value: widget.contractProvider,
      child: ContractDetailScreen(contractId: id),
    ),
  );

  Future<void> _traPhong(int id) => _moRoiNap(
    ChangeNotifierProvider.value(
      value: widget.contractProvider,
      child: ContractTerminateScreen(contractId: id),
    ),
  );

  /// Danh sách hoá đơn đầy đủ (lọc được theo tháng và trạng thái).
  Future<void> _moDsHoaDon() => _moRoiNap(
    ChangeNotifierProvider(
      create: (_) => InvoiceProvider(),
      child: const InvoiceListScreen(),
    ),
  );

  Future<void> _moHoaDon(int id) => _moRoiNap(
    ChangeNotifierProvider(
      create: (_) => InvoiceProvider(),
      child: InvoiceDetailScreen(invoiceId: id),
    ),
  );

  /// LẬP HOÁ ĐƠN THÁNG = hai bước: chốt chỉ số điện nước (chụp công tơ nếu
  /// còn thiếu) → Dịch vụ & hoá đơn. Trước đây nút này tạo thẳng một hoá đơn
  /// nháp, chủ nhà không kịp nhìn con số và không chọn được dịch vụ tháng này
  /// gồm gì; tiền điện nước cũng có thể còn bằng 0 vì chưa ai gửi chỉ số.
  Future<void> _lapHoaDon() async {
    final hs = _hs;
    final hd = hs?.hopDong;
    if (hs == null || hd == null || _dangLapHoaDon) return;
    setState(() => _dangLapHoaDon = true);
    try {
      await _moRoiNap(
        DienNuocDaiHanScreen(
          toa: [(id: hs.toa.id, ten: hs.toa.ten)],
          buildingId: hs.toa.id,
          roomIdBanDau: _p.id,
          contractIdHoaDon: hd.id,
        ),
      );
    } finally {
      if (mounted) setState(() => _dangLapHoaDon = false);
    }
  }

  /// ĐÃ CHO THUÊ NGOÀI APP — chủ nhà tự tìm được khách. Ghi nhận gọn để phòng
  /// thôi nằm trên chợ và Sổ phòng đếm đúng; giấy tờ bổ sung sau cũng được.
  Future<void> _choThueNgoai() async {
    final kq = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HopThoaiChoThueNgoai(
        roomId: _p.id,
        maPhong: _p.code,
        giaPhong: _p.basePrice,
        api: widget.choThueNgoaiApi,
      ),
    );
    if (kq == null || !mounted) return;
    _bao('Đã đánh dấu ${_p.code} cho thuê ngoài app. Tin đang rao đã đóng.');
    await _nap();
  }

  /// Bấm nhầm thì gỡ. Server chặn nếu đã có hoá đơn — lúc đó phải TRẢ PHÒNG.
  Future<void> _boChoThueNgoai() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Bỏ đánh dấu cho thuê ngoài?'),
        content: Text(
          'Phòng ${_p.code} trở lại TRỐNG và rao lại được. '
          'Ghi nhận khách thuê hiện tại sẽ bị xoá.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Huỷ')),
          TextButton(
            key: const ValueKey('xac-nhan-bo-ctn'),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Bỏ đánh dấu'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.choThueNgoaiApi.boDanhDau(_p.id);
      if (!mounted) return;
      _bao('Đã gỡ. Phòng ${_p.code} trở lại trống.');
      await _nap();
    } catch (e) {
      if (mounted) _bao(e is ApiException ? e.message : 'Không gỡ được đánh dấu');
    }
  }

  Future<void> _goi(String sdt) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: sdt));
    if (!ok && mounted) {
      await Clipboard.setData(ClipboardData(text: sdt));
      if (mounted) _bao('Đã sao chép số $sdt');
    }
  }

  Future<void> _chiaSe() async {
    final p = _p;
    final hs = _hs;
    final ten = [
      if ((hs?.toa.ten ?? '').isNotEmpty) hs!.toa.ten,
      'Phòng ${p.code}',
    ].join(' – ');
    final id = p.marketplaceHouseId;
    final gia = p.giaKenh ?? p.basePrice;
    // Lên chợ rồi → gửi link tin. Chưa lên chợ thì không có link nào — gửi bản
    // tóm tắt để nhắn Zalo cho người hỏi thuê.
    final noiDung = id != null
        ? '$ten\n${Env.housePublicUrl(id, ten)}'
        : [
            ten,
            if (gia > 0)
              'Giá: ${PriceFormat.full(gia)} ${KenhKhaiThac.hauToDonVi[p.donVi ?? 'thang'] ?? '/tháng'}',
            if (p.areaM2 != null) 'Diện tích: ${_so(p.areaM2!)} m²',
            if ((hs?.toa.diaChi ?? '').isNotEmpty) 'Địa chỉ: ${hs!.toa.diaChi}',
          ].join('\n');
    try {
      await Share.share(noiDung);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: noiDung));
      if (mounted) _bao('Đã sao chép thông tin phòng');
    }
  }

  /// Bật / tắt kênh bán của phòng — không có trong mockup nên ở menu ⋮.
  Future<void> _moKenh() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, HD.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Kênh khai thác phòng ${_p.code}', style: HD.bodyBold(size: 16)),
              const SizedBox(height: HD.s12),
              MucKenhKhaiThac(roomId: _p.id, api: widget.kenhApi),
            ],
          ),
        ),
      ),
    );
    if (mounted) await _nap();
  }

  Future<void> _moThanhToan() async {
    final hd = _hs?.hopDong;
    if (hd == null) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ThanhToanHopDongSheet(hopDong: hd, api: widget.api),
    );
    if (ok == true) await _nap();
  }

  Future<void> _moTaiSan([MucTaiSan? muc]) async {
    final ok = await moTaiSanSheet(context, roomId: _p.id, api: widget.api, muc: muc);
    if (ok) await _nap();
  }

  Future<void> _xemTatCaTaiSan() async {
    final hs = _hs;
    if (hs == null) return;
    await _moRoiNap(
      TaiSanPhongScreen(
        roomId: _p.id,
        maPhong: _p.code,
        daGhi: hs.taiSan,
        doTrongPhong: _p.doTrongPhong,
        suaDuoc: hs.suaDuoc,
        api: widget.api,
      ),
    );
  }

  /// Mở thẳng màn Điện nước của CHÍNH phòng này — một nút ra ngay trang chi
  /// tiết, không qua bảng chọn. Tự nhập số tay vẫn còn ở menu ⋮ "Chỉ số điện
  /// nước", nên không mục nào mồ côi.
  Future<void> _moDienNuoc() async {
    final hs = _hs;
    if (hs == null) return;
    await _moRoiNap(
      DienNuocDaiHanScreen(
        toa: [(id: hs.toa.id, ten: hs.toa.ten)],
        buildingId: hs.toa.id,
        roomIdBanDau: _p.id,
      ),
    );
  }

  Future<void> _ghiSuaChua() async {
    final hs = _hs;
    if (hs == null) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => GhiSuaChuaSheet(
        roomId: _p.id,
        api: widget.api,
        hienChiPhi: hs.xemTaiChinh,
      ),
    );
    if (ok == true) await _nap();
  }

  Future<void> _xongSuaChua(SuaChua x) async {
    try {
      await widget.api.danhDauXong(x.id);
      await _nap();
    } catch (e) {
      if (mounted) _bao(e is ApiException ? e.message : 'Không cập nhật được');
    }
  }

  Future<void> _xoaSuaChua(SuaChua x) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xoá "${x.tieuDe}"?'),
        content: const Text('Mục này sẽ mất khỏi lịch sử sửa chữa của phòng.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.xoaSuaChua(x.id);
      await _nap();
    } catch (e) {
      if (mounted) _bao(e is ApiException ? e.message : 'Không xoá được');
    }
  }

  Future<void> _lichSuThue() async {
    widget.contractProvider.fetchContracts(roomId: _p.id, includeTerminated: true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: HD.paper,
          appBar: AppBar(
            backgroundColor: HD.paperRaised,
            surfaceTintColor: HD.paperRaised,
            title: Text('Lịch sử thuê phòng ${_p.code}', style: HD.bodyBold(size: 16)),
          ),
          body: ListView(
            children: [
              ContractHistorySection(
                contractProvider: widget.contractProvider,
                onOpen: _xemHopDong,
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) await _nap();
  }

  // ── Dựng ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hs = _hs;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: _dauTrang(),
      bottomNavigationBar: hs == null ? null : _thanhDuoi(hs),
      body: RefreshIndicator(
        color: HD.accent,
        onRefresh: _nap,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, HD.s32),
          children: [
            if (_dangTai && hs != null)
              const Padding(
                padding: EdgeInsets.only(bottom: HD.s8),
                child: LinearProgressIndicator(minHeight: 2, color: HD.accent),
              ),
            _AnhPhong(room: _p, onSua: hs?.suaDuoc == true ? () => _lam(widget.onSua) : null),
            const SizedBox(height: HD.s12),
            _bonO(hs),
            const SizedBox(height: HD.s12),
            if (hs == null && _loi != null)
              _Loi(chu: _loi!, onThuLai: _nap)
            else if (hs == null)
              const Padding(
                padding: EdgeInsets.all(HD.s32),
                child: Center(child: CircularProgressIndicator(color: HD.accent)),
              )
            else ...[
              _theKhach(hs),
              // Chủ phòng LUÔN thấy khối tiền và khối điện nước, kể cả khi phòng
              // chưa có người thuê: khối trống nói rõ nó sẽ chứa gì và bắt đầu
              // từ đâu. Ẩn hẳn thì chủ nhà tưởng phòng dài hạn không có quản lý
              // hoá đơn / ảnh công tơ (đã xảy ra 11/09).
              if (hs.xemTaiChinh) ...[
                const SizedBox(height: HD.s12),
                hs.hopDong != null ? _theTaiChinh(hs) : _theTaiChinhTrong(hs),
                const SizedBox(height: HD.s12),
                hs.dienNuoc != null
                    ? _theDienNuoc(hs.dienNuoc!)
                    : _theDienNuocTrong(),
              ],
              const SizedBox(height: HD.s12),
              _theTaiSan(hs),
              const SizedBox(height: HD.s12),
              _theSuaChua(hs),
              // Bật / tắt kênh bán không có trong mockup — ở menu ⋮ "Kênh khai
              // thác" (bỏ hẳn là phòng mất đường ra chợ).
              ?_vungTrangThai(hs),
            ],
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _dauTrang() {
    final p = _p;
    final phu = [
      if ((_hs?.toa.ten ?? '').isNotEmpty) _hs!.toa.ten,
      if ((p.tang ?? '').isNotEmpty) 'Tầng ${p.tang}',
    ].join(' • ');
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Material(
        color: HD.paperRaised,
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: HD.s12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: HD.hairline.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              children: [
                if (Navigator.of(context).canPop()) ...[
                  _NutTron(
                    icon: Icons.chevron_left,
                    tooltip: 'Quay lại',
                    co: 36,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Hồ sơ phòng ${p.code}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HD.bodyBold(size: 16),
                            ),
                          ),
                          const SizedBox(width: HD.s8),
                          NhanTinhTrang(tinhTrang: p.tinhTrangHien),
                        ],
                      ),
                      if (phu.isNotEmpty)
                        Text(
                          phu,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HD.body(size: 11, color: HD.inkMuted),
                        ),
                    ],
                  ),
                ),
                // Lên chợ rồi thì gửi link tin; chưa thì gửi bản tóm tắt phòng.
                _NutTron(
                  icon: Icons.share_outlined,
                  tooltip: 'Chia sẻ phòng',
                  co: 32,
                  onTap: _chiaSe,
                ),
                const SizedBox(width: 6),
                _menu(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu() {
    final p = _p;
    final muc = <(String, String, bool)>[
      if (widget.onSua != null) ('sua', 'Sửa phòng', false),
      if (widget.onChiSo != null) ('chi_so', 'Chỉ số điện nước', false),
      ('kenh', 'Kênh khai thác', false),
      if (widget.onNhanBan != null) ('nhan_ban', 'Nhân bản phòng', false),
      if (p.isVacant && widget.onBaoTri != null)
        ('bao_tri', 'Đặt lịch bảo trì', false),
      if (p.isMaintenance && widget.onKetThucBaoTri != null)
        ('ket_thuc_bao_tri', 'Kết thúc bảo trì', false),
      if (_hs?.xemTaiChinh == true &&
          _hs?.hopDong == null &&
          !p.dangThue &&
          !p.isMaintenance)
        ('cho_thue_ngoai', 'Đã cho thuê ngoài app', false),
      ('lich_su', 'Lịch sử thuê phòng', false),
      if (_hs?.hopDong?.ngoaiLuong == true)
        ('bo_ctn', 'Bỏ đánh dấu cho thuê ngoài', true),
      if (widget.onXoa != null) ('xoa', 'Xoá phòng', true),
    ];
    return PopupMenuButton<String>(
      key: const ValueKey('menu-ho-so'),
      tooltip: 'Thao tác với phòng',
      position: PopupMenuPosition.under,
      onSelected: (k) => switch (k) {
        'sua' => _lam(widget.onSua),
        'chi_so' => _lam(widget.onChiSo),
        'kenh' => _moKenh(),
        'nhan_ban' => _lam(widget.onNhanBan),
        'bao_tri' => _lam(widget.onBaoTri),
        'ket_thuc_bao_tri' => _lam(widget.onKetThucBaoTri),
        'lich_su' => _lichSuThue(),
        'cho_thue_ngoai' => _choThueNgoai(),
        'bo_ctn' => _boChoThueNgoai(),
        'xoa' => _lam(widget.onXoa),
        _ => Future<void>.value(),
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

  Widget _bonO(HoSoPhong? hs) {
    final p = _p;
    final hd = hs?.hopDong;
    final dienTich = p.areaM2 == null ? null : '${_so(p.areaM2!)} m²';
    final tang = (p.tang ?? '').isEmpty ? null : 'Tầng ${p.tang}';
    final huong = RoomModel.nhanHuong[p.huong];
    final nguoi = hd != null ? '${hd.soNguoi} người' : 'Tối đa ${p.capacity}';
    // Ô "Chưa khai" bấm được — dẫn thẳng tới tờ khai phòng.
    final khai = hs?.suaDuoc == true && widget.onSua != null
        ? () => _lam(widget.onSua)
        : null;
    final o = [
      (Icons.straighten, HD.accent, 'Diện tích', dienTich),
      (Icons.layers_outlined, HD.svcBlue, 'Vị trí', tang),
      (Icons.explore_outlined, HD.svcAmber, 'Hướng', huong),
      (Icons.people_alt_outlined, HD.positive, 'Số người ở', nguoi),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < o.length; i++) ...[
            if (i > 0) const SizedBox(width: HD.s8),
            Expanded(
              child: _OThongSo(
                icon: o[i].$1,
                mau: o[i].$2,
                nhan: o[i].$3,
                giaTri: o[i].$4,
                onKhai: o[i].$4 == null ? khai : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _theKhach(HoSoPhong hs) {
    final p = _p;
    final hd = hs.hopDong;
    if (hs.xemTaiChinh && hd != null) {
      final k = hd.khach;
      final conLai = _conLai(hd);
      return _The(
        tieuDe: 'KHÁCH THUÊ HIỆN TẠI',
        cham: HD.positive,
        phai: _LienKet(chu: 'Chi tiết hồ sơ', onTap: () => _xemHopDong(hd.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: _nenO(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: HD.accentTint,
                      borderRadius: BorderRadius.circular(HD.r12),
                      border: Border.all(color: HD.paperRaised, width: 2),
                    ),
                    child: Text(
                      k == null ? '?' : _chuCaiDau(k.ten),
                      style: HD.bodyBold(size: 18, color: HD.accent),
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
                                k?.ten ?? 'Chưa ghi tên người thuê',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HD.bodyBold(size: 14),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _Nhan(
                              // Ngoài luồng thì nói thẳng: đây là ghi nhận của
                              // chủ nhà, KHÔNG phải hợp đồng có giấy tờ trong
                              // app — và người thuê không có tài khoản để gửi
                              // ảnh công tơ.
                              chu: hd.ngoaiLuong
                                  ? 'Cho thuê ngoài app'
                                  : hd.kenh == 'mat_bang'
                                  ? 'Hợp đồng mặt bằng'
                                  : 'Hợp đồng dài hạn',
                              nen: hd.ngoaiLuong ? HD.warningTint : HD.positiveTint,
                              mau: hd.ngoaiLuong ? HD.svcAmber : HD.positive,
                            ),
                          ],
                        ),
                        if (k != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 11, color: HD.inkMuted),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  [
                                    if (k.sdt.isNotEmpty) _sdtNhom(k.sdt),
                                    // Chỉ 3 số cuối được lưu — che phần đầu thay vì đuôi.
                                    k.cccdDuoi != null
                                        ? 'CCCD: xxxxxxxxx${k.cccdDuoi}'
                                        : k.coCccd
                                        ? 'Đã lưu ảnh CCCD 2 mặt'
                                        : 'Chưa có CCCD',
                                  ].join(' • '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: HD.body(size: 11, color: HD.inkMuted),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            style: HD.body(size: 11, color: HD.inkSoft),
                            children: [
                              const TextSpan(text: 'Đã ở: '),
                              TextSpan(
                                text: '${hd.daOThang} tháng',
                                style: HD.bodyBold(size: 11),
                              ),
                              const TextSpan(text: '  •  Hết hạn: '),
                              TextSpan(
                                text: _ngayVN(hd.ketThuc),
                                style: HD.bodyBold(size: 11),
                              ),
                            ],
                          ),
                        ),
                        // Ghi chú của hợp đồng ngoài luồng thường là thứ DUY
                        // NHẤT để tra ("thuê qua Facebook, chưa làm giấy tờ").
                        // Cho nhập mà không hiện ra là ô ghi chú ghi vào hư vô.
                        if ((hd.ghiChu ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.sticky_note_2_outlined,
                                size: 11,
                                color: HD.inkMuted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  hd.ghiChu!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: HD.body(size: 11, color: HD.inkMuted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HD.s12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    hd.tongThang == null
                        ? 'Tiến độ hợp đồng'
                        : 'Tiến độ hợp đồng (${hd.tongThang} tháng)',
                    style: HD.body(size: 11, color: HD.inkMuted),
                  ),
                ),
                if (conLai != null)
                  Text(
                    conLai,
                    style: HD.bodyBold(
                      size: 11,
                      color: (hd.conLaiNgay ?? 99) < 0 ? HD.negative : HD.inkSoft,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _ThanhTienDo(tyLe: hd.tyLe),
            const SizedBox(height: HD.s12),
            Row(
              children: [
                Expanded(
                  child: _NutNho(
                    icon: Icons.description_outlined,
                    mau: HD.accent,
                    chu: 'Xem HĐ',
                    onTap: () => _xemHopDong(hd.id),
                  ),
                ),
                const SizedBox(width: HD.s8),
                Expanded(
                  child: _NutNho(
                    icon: Icons.receipt_long_outlined,
                    mau: HD.svcBlue,
                    chu: 'Lập HĐơn',
                    dangChay: _dangLapHoaDon,
                    onTap: _lapHoaDon,
                  ),
                ),
                if (k != null && k.sdt.isNotEmpty) ...[
                  const SizedBox(width: HD.s8),
                  Expanded(
                    child: _NutNho(
                      icon: Icons.phone,
                      mau: HD.positive,
                      chu: 'Gọi điện',
                      onTap: () => _goi(k.sdt),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    // Không có hợp đồng mà người xem thấy được, hoặc người xem là sale.
    final (tieuDe, phu) = p.dangThue
        ? (
            hs.xemTaiChinh && (p.khachThue ?? '').isNotEmpty
                ? p.khachThue!
                : 'Đang có khách thuê',
            hs.xemTaiChinh
                ? (p.traPhongLuc != null
                      ? 'Khách lưu trú — trả phòng ${_gio(p.traPhongLuc!)}'
                      : 'Đang có người ở')
                : 'Thông tin người thuê do chủ nhà quản lý',
          )
        : (
            'Chưa có khách thuê',
            p.isMaintenance ? 'Phòng đang bảo trì' : 'Sẵn sàng cho thuê',
          );
    return _The(
      tieuDe: 'KHÁCH THUÊ HIỆN TẠI',
      cham: p.dangThue ? HD.positive : HD.inkMuted,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: _nenO(),
        child: Row(
          children: [
            p.dangThue
                ? Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: HD.positiveTint,
                      borderRadius: BorderRadius.circular(HD.r12),
                    ),
                    child: const Icon(Icons.person_outline, color: HD.positive),
                  )
                : Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(HD.r12),
                      border: Border.all(color: HD.hairlineStrong),
                    ),
                    child: const Icon(Icons.person_add_alt_outlined, color: HD.inkMuted),
                  ),
            const SizedBox(width: HD.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tieuDe, style: HD.bodyBold(size: 14)),
                  const SizedBox(height: 2),
                  Text(phu, style: HD.body(size: 11, color: HD.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _theTaiChinh(HoSoPhong hs) {
    final hd = hs.hopDong!;
    // Danh sách là nguồn thật; `hoaDonGanNhat` chỉ còn để đọc bản server cũ.
    final coHoaDon = hs.hoaDon.isNotEmpty || hs.hoaDonGanNhat != null;
    final soThangCoc = hd.tienThue > 0 && hd.tienCoc > 0 && hd.tienCoc % hd.tienThue == 0
        ? ' (Cọc ${(hd.tienCoc / hd.tienThue).round()}T)'
        : '';
    final daThu = hd.cocDaThu;
    // null = chưa ghi nhận — khác 0đ (đã kiểm, chưa thu đồng nào).
    final (IconData? iconCoc, String chuCoc, Color mauCoc) = daThu == null
        ? (null, 'Chưa ghi nhận — bấm để ghi', HD.inkMuted)
        : daThu >= hd.tienCoc
        ? (Icons.check_circle, 'Đã đóng đủ', HD.positive)
        : daThu <= 0
        ? (Icons.error_outline, 'Chưa đóng cọc', HD.negative)
        : (Icons.timelapse, 'Còn thiếu ${PriceFormat.full(hd.tienCoc - daThu)}', HD.svcAmber);
    final ngay = hd.ngayThanhToan;
    final hinhThuc = HopDongHienTai.nhanHinhThuc[hd.hinhThucThanhToan];
    return _The(
      tieuDe: 'TÀI CHÍNH & TIỀN CỌC PHÒNG',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _OTien(
                    key: const ValueKey('o-tien-coc'),
                    nhan: 'Tiền cọc giữ chỗ$soThangCoc',
                    so: PriceFormat.full(hd.tienCoc),
                    mauSo: HD.accent,
                    phu: chuCoc,
                    iconPhu: iconCoc,
                    mauPhu: mauCoc,
                    nen: HD.accentTint,
                    vien: HD.accentSoft,
                    onTap: _moThanhToan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OTien(
                    key: const ValueKey('o-ky-thanh-toan'),
                    nhan: 'Kỳ thanh toán',
                    so: ngay == null ? 'Chưa đặt ngày thu' : 'Ngày ${_hai(ngay)} hàng tháng',
                    mauSo: ngay == null ? HD.inkMuted : HD.ink,
                    phu: hinhThuc ??
                        (ngay == null ? 'Bấm để đặt ngày & hình thức' : 'Chưa ghi hình thức thu'),
                    nen: HD.paper,
                    vien: HD.hairline.withValues(alpha: 0.6),
                    onTap: _moThanhToan,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: HD.s12),
          if (coHoaDon)
            _dsHoaDon(hs)
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Chưa có hoá đơn nào cho hợp đồng này.',
                    style: HD.body(size: 12, color: HD.inkMuted),
                  ),
                ),
                TextButton(onPressed: _lapHoaDon, child: const Text('Lập hoá đơn')),
              ],
            ),
        ],
      ),
    );
  }

  /// Các kỳ hoá đơn CỦA PHÒNG, mới nhất trước. Trước đây chỗ này chỉ in đúng
  /// một hoá đơn gần nhất, nên đứng ở Hồ sơ phòng không trả lời được câu hỏi
  /// thường gặp nhất: "phòng này đã thu tới tháng nào, còn treo kỳ nào".
  Widget _dsHoaDon(HoSoPhong hs) {
    final ds = hs.hoaDon.isNotEmpty
        ? hs.hoaDon
        : [if (hs.hoaDonGanNhat != null) hs.hoaDonGanNhat!];
    final conNo = ds.where((h) => h.trangThai != 'paid').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                conNo == 0
                    ? 'Hoá đơn gần đây'
                    : 'Hoá đơn gần đây · $conNo kỳ chưa thu xong',
                style: HD.bodyBold(size: 12, color: conNo == 0 ? HD.inkSoft : HD.negative),
              ),
            ),
            _LienKet(chu: 'Xem tất cả', onTap: _moDsHoaDon),
          ],
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < ds.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _dongHoaDon(ds[i]),
        ],
      ],
    );
  }

  Widget _dongHoaDon(HoaDonGanNhat inv) => Material(
    color: HD.paper,
    borderRadius: BorderRadius.circular(HD.r12),
    child: InkWell(
      borderRadius: BorderRadius.circular(HD.r12),
      onTap: () => _moHoaDon(inv.id),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const Icon(Icons.history, size: 16, color: HD.inkMuted),
            const SizedBox(width: HD.s8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: HD.body(size: 12, color: HD.inkSoft),
                  children: [
                    TextSpan(text: 'Hóa đơn ${_kyNgan(inv.ky)}: '),
                    TextSpan(
                      text: PriceFormat.full(inv.tong),
                      style: HD.bodyBold(size: 12),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            _nhanHoaDon(inv),
          ],
        ),
      ),
    ),
  );

  /// Phòng chưa có hợp đồng: giữ chỗ khối tiền, nói nó sẽ chứa gì. Hoá đơn cuối
  /// của hợp đồng cũ (nếu có) vẫn mở được — thường là hoá đơn trả phòng.
  Widget _theTaiChinhTrong(HoSoPhong hs) {
    final coHoaDon = hs.hoaDon.isNotEmpty || hs.hoaDonGanNhat != null;
    return _The(
      tieuDe: 'TÀI CHÍNH & TIỀN CỌC PHÒNG',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GoiY(
            icon: Icons.receipt_long_outlined,
            chu: 'Chưa có hợp đồng thuê',
            phu: _p.isMaintenance
                ? 'Phòng đang bảo trì. Xong bảo trì, lập hợp đồng để ghi tiền cọc, tiền thuê và lập hoá đơn hằng tháng.'
                : 'Bấm "Tạo hợp đồng" bên dưới để ghi tiền cọc, tiền thuê — hoá đơn hằng tháng lập ngay tại đây.',
          ),
          if (coHoaDon) ...[const SizedBox(height: HD.s8), _dsHoaDon(hs)],
        ],
      ),
    );
  }

  /// Phòng chưa có người thuê: chưa ai gửi ảnh công tơ. Việc làm được ngay là
  /// ghi số lúc bàn giao — mốc để tháng đầu tính tiền điện nước.
  Widget _theDienNuocTrong() => _The(
    tieuDe: 'ĐỒNG HỒ ĐIỆN & NƯỚC ${_p.code}',
    icon: Icons.bolt,
    mauIcon: HD.svcAmber,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _GoiY(
          icon: Icons.photo_camera_outlined,
          chu: 'Chưa có người thuê gửi ảnh công tơ',
          phu: 'Có hợp đồng rồi, người thuê chụp công tơ gửi mỗi tháng — số cũ, số mới, tiêu thụ và ảnh hiện ở đây để bạn duyệt.',
        ),
        if (widget.onChiSo != null) ...[
          const SizedBox(height: HD.s12),
          OutlinedButton.icon(
            key: const ValueKey('ghi-so-ban-giao'),
            onPressed: () => _lam(widget.onChiSo),
            style: OutlinedButton.styleFrom(
              foregroundColor: HD.inkSoft,
              side: BorderSide(color: HD.hairline.withValues(alpha: 0.8)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HD.r12)),
            ),
            icon: const Icon(Icons.edit_note, size: 16, color: HD.accent),
            label: const Text('Ghi số công tơ lúc bàn giao'),
          ),
        ],
      ],
    ),
  );

  Widget _theDienNuoc(DienNuocPhong dn) {
    final nhac = _nhanChiSo(dn.trangThai);
    return _The(
      tieuDe: 'ĐỒNG HỒ ĐIỆN & NƯỚC ${_p.code}',
      icon: Icons.bolt,
      mauIcon: HD.svcAmber,
      phai: Text(
        dn.ngayChot != null ? 'Kỳ chốt: ${_ngayVN(dn.ngayChot!)}' : 'Tháng ${_kyNgan(dn.thang)}',
        style: HD.body(size: 11, color: HD.inkMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _OCongTo(
                    tieuDe: 'Số điện',
                    icon: Icons.bolt,
                    mau: HD.svcAmber,
                    gia: '${PriceFormat.full(dn.giaDien)}/kWh',
                    dung: dn.dienDung == null ? null : '${_so(dn.dienDung!)} kWh',
                    cu: dn.dienCu,
                    moi: dn.dienMoi,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OCongTo(
                    tieuDe: 'Số nước',
                    icon: Icons.water_drop,
                    mau: HD.svcBlue,
                    gia: '${PriceFormat.full(dn.giaNuoc)}/m³',
                    dung: dn.nuocDung == null ? null : '${_so(dn.nuocDung!)} m³',
                    cu: dn.nuocCu,
                    moi: dn.nuocMoi,
                  ),
                ),
              ],
            ),
          ),
          if (nhac != null) ...[
            const SizedBox(height: HD.s8),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: HD.svcAmber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(nhac, style: HD.body(size: 11, color: HD.svcAmber)),
                ),
              ],
            ),
          ],
          const SizedBox(height: HD.s12),
          OutlinedButton.icon(
            key: const ValueKey('mo-dien-nuoc'),
            onPressed: _moDienNuoc,
            style: OutlinedButton.styleFrom(
              foregroundColor: HD.inkSoft,
              side: BorderSide(color: HD.hairline.withValues(alpha: 0.8)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HD.r12)),
            ),
            icon: const Icon(Icons.bolt, size: 16, color: HD.accent),
            label: const Text('Chi tiết'),
          ),
        ],
      ),
    );
  }

  Widget _theTaiSan(HoSoPhong hs) {
    // Món đã ghi hãng / tình trạng + món tờ khai phòng nói có mà chưa ghi chi tiết.
    final ds = gopTaiSan(hs.taiSan, _p.doTrongPhong);
    return _The(
      tieuDe: 'TÀI SẢN & NỘI THẤT BÀN GIAO',
      icon: Icons.chair_outlined,
      phu: ds.isEmpty
          ? null
          : hs.hopDong != null
          ? '${ds.length} thiết bị đã bàn giao biên bản'
          : '${ds.length} thiết bị trong phòng',
      phai: hs.suaDuoc
          ? InkWell(
              key: const ValueKey('them-tai-san'),
              onTap: () => _moTaiSan(),
              borderRadius: BorderRadius.circular(HD.r8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 13, color: HD.accent),
                    const SizedBox(width: 2),
                    Text('Thêm', style: HD.bodyBold(size: 12, color: HD.accent)),
                  ],
                ),
              ),
            )
          : null,
      child: ds.isEmpty
          ? Text(
              hs.suaDuoc
                  ? 'Chưa ghi tài sản nào — bấm "Thêm" để ghi đồ bàn giao.'
                  : 'Chưa ghi tài sản nào.',
              style: HD.body(size: 12, color: HD.inkMuted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (_, c) {
                    final rong = (c.maxWidth - HD.s8) / 2;
                    return Wrap(
                      spacing: HD.s8,
                      runSpacing: HD.s8,
                      children: [
                        for (final m in ds.take(4))
                          SizedBox(
                            width: rong,
                            child: _OTaiSan(
                              muc: m,
                              onTap: hs.suaDuoc ? () => _moTaiSan(m) : null,
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: HD.hairline.withValues(alpha: 0.5)),
                _DongXemHet(
                  chu: 'Xem tất cả ${ds.length} tài sản & tình trạng hao mòn',
                  mo: false,
                  onTap: _xemTatCaTaiSan,
                ),
              ],
            ),
    );
  }

  Widget _theSuaChua(HoSoPhong hs) {
    final p = _p;
    final ds = _hetSuaChua ? hs.suaChua : hs.suaChua.take(3).toList();
    return _The(
      tieuDe: 'LỊCH SỬ SỬA CHỮA & SỰ CỐ',
      icon: Icons.build_outlined,
      phai: hs.suaChuaTon == 0
          ? const _Nhan(chu: 'Không có lỗi tồn', nen: HD.positiveTint, mau: HD.positive)
          : _Nhan(
              chu: '${hs.suaChuaTon} việc đang xử lý',
              nen: HD.warningTint,
              mau: HD.svcAmber,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.isMaintenance)
            Container(
              margin: const EdgeInsets.only(bottom: HD.s8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HD.warningTint,
                borderRadius: BorderRadius.circular(HD.r12),
              ),
              child: Text(
                [
                  'Đang bảo trì',
                  if ((p.maintenanceStart ?? '').isNotEmpty) 'từ ${_ngayNgan(p.maintenanceStart!)}',
                  if ((p.maintenanceEnd ?? '').isNotEmpty) 'đến ${_ngayNgan(p.maintenanceEnd!)}',
                ].join(' '),
                style: HD.bodyBold(size: 12, color: HD.svcAmber),
              ),
            ),
          if (hs.suaChua.isEmpty)
            Text(
              'Chưa ghi nhận lần sửa chữa nào.',
              style: HD.body(size: 12, color: HD.inkMuted),
            ),
          for (final x in ds) ...[
            _OSuaChua(
              muc: x,
              onXong: hs.suaDuoc && x.dangXuLy ? () => _xongSuaChua(x) : null,
              onXoa: hs.suaDuoc ? () => _xoaSuaChua(x) : null,
            ),
            const SizedBox(height: HD.s8),
          ],
          if (hs.suaChua.length > 3)
            _DongXemHet(
              chu: _hetSuaChua ? 'Thu gọn' : 'Xem tất cả ${hs.suaChua.length} lần sửa',
              mo: _hetSuaChua,
              onTap: () => setState(() => _hetSuaChua = !_hetSuaChua),
            ),
          if (hs.suaDuoc) ...[
            if (hs.suaChua.isEmpty) const SizedBox(height: HD.s8),
            Divider(height: 1, color: HD.hairline.withValues(alpha: 0.5)),
            InkWell(
              key: const ValueKey('ghi-sua-chua'),
              onTap: _ghiSuaChua,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: HD.s8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ghi sửa chữa / sự cố mới',
                        style: HD.bodyBold(size: 11, color: HD.accent),
                      ),
                    ),
                    const Icon(Icons.add, size: 14, color: HD.accent),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _vungTrangThai(HoSoPhong hs) {
    final p = _p;
    final hd = hs.hopDong;
    final (String, String, VoidCallback)? viec = hs.xemTaiChinh && hd != null
        ? (
            'Thanh lý hợp đồng, trả cọc, lập hoá đơn cuối',
            'Trả phòng & Chốt sổ',
            () => _traPhong(hd.id),
          )
        : p.isMaintenance && widget.onKetThucBaoTri != null
        ? (
            'Kết thúc bảo trì, phòng quay lại trống',
            'Kết thúc bảo trì',
            () => _lam(widget.onKetThucBaoTri),
          )
        : p.isVacant && !p.dangThue && widget.onBaoTri != null
        ? (
            'Khoá phòng trong thời gian sửa chữa',
            'Chuyển bảo trì',
            () => _lam(widget.onBaoTri),
          )
        : null;
    if (viec == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: HD.s12),
      child: Container(
        padding: const EdgeInsets.all(HD.s12),
        decoration: BoxDecoration(
          color: HD.accentTint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HD.accentSoft),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thao tác trạng thái phòng',
                    style: HD.bodyBold(size: 12, color: HD.accentDeep),
                  ),
                  const SizedBox(height: 2),
                  Text(viec.$1, style: HD.body(size: 10, color: HD.accent)),
                ],
              ),
            ),
            const SizedBox(width: HD.s8),
            FilledButton(
              key: const ValueKey('thao-tac-trang-thai'),
              onPressed: viec.$3,
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HD.r12)),
              ),
              child: Text(viec.$2, style: HD.bodyBold(size: 12, color: HD.paperRaised)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thanhDuoi(HoSoPhong hs) {
    final p = _p;
    final hd = hs.hopDong;
    final Widget? chinh = hs.xemTaiChinh && hd != null
        ? FilledButton.icon(
            key: const ValueKey('lap-hoa-don'),
            onPressed: _dangLapHoaDon ? null : _lapHoaDon,
            style: _kieuNutChinh(),
            icon: _dangLapHoaDon
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: HD.paperRaised),
                  )
                : const Icon(Icons.receipt_long, size: 18),
            label: const Text('Lập hóa đơn tháng này'),
          )
        : hs.xemTaiChinh && hd == null && !p.dangThue && !p.isMaintenance
        ? (widget.onTaoHopDong != null
              ? FilledButton.icon(
                  key: const ValueKey('tao-hop-dong'),
                  onPressed: () => _lam(widget.onTaoHopDong),
                  style: _kieuNutChinh(),
                  icon: const Icon(Icons.post_add, size: 18),
                  label: const Text('Tạo hợp đồng'),
                )
              // Không dựng được hợp đồng ở màn này thì "đã cho thuê ngoài"
              // chính là việc duy nhất còn làm được với phòng trống.
              : FilledButton.icon(
                  key: const ValueKey('cho-thue-ngoai-chinh'),
                  onPressed: _choThueNgoai,
                  style: _kieuNutChinh(),
                  icon: const Icon(Icons.handshake_outlined, size: 18),
                  label: const Text('Đã cho thuê ngoài app'),
                ))
        : null;
    // Phòng trống mà chủ nhà tự tìm được khách: đánh dấu ngay tại đây, đứng
    // cạnh "Tạo hợp đồng" chứ không giấu trong menu — đây là đường phổ biến
    // hơn ở nhà trọ VN, và phòng không được đánh dấu thì vẫn nằm trên chợ.
    final bool phuCtn =
        hs.xemTaiChinh &&
        hd == null &&
        !p.dangThue &&
        !p.isMaintenance &&
        widget.onTaoHopDong != null;
    return Material(
      color: HD.paperRaised,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(HD.s16, 10, HD.s16, 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: HD.hairline.withValues(alpha: 0.6))),
          ),
          child: Row(
            children: [
              if (chinh != null)
                Expanded(child: SizedBox(height: 44, child: chinh))
              else
                const Spacer(),
              if (phuCtn) ...[
                const SizedBox(width: HD.s8),
                // Nút VUÔNG chứ không phải nút chữ: ở máy 390px, thêm một nút
                // chữ nữa là thanh dưới tràn. Việc này cũng nằm trong menu ⋮.
                _NutVuong(
                  key: const ValueKey('cho-thue-ngoai'),
                  icon: Icons.handshake_outlined,
                  tooltip: 'Đã cho thuê ngoài app',
                  onTap: _choThueNgoai,
                ),
              ],
              if (hs.suaDuoc && widget.onSua != null) ...[
                const SizedBox(width: 10),
                _NutVuong(
                  icon: Icons.edit_outlined,
                  tooltip: 'Sửa thông tin phòng',
                  onTap: () => _lam(widget.onSua),
                ),
              ],
              const SizedBox(width: HD.s8),
              _NutVuong(
                icon: Icons.history,
                tooltip: 'Lịch sử thuê phòng',
                onTap: _lichSuThue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle _kieuNutChinh() => FilledButton.styleFrom(
    backgroundColor: HD.accent,
    foregroundColor: HD.paperRaised,
    textStyle: HD.bodyBold(size: 13),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HD.r12)),
  );

  Widget _nhanHoaDon(HoaDonGanNhat h) {
    final (chu, nen, mau) = switch (h.trangThai) {
      'paid' => ('Đã thanh toán', HD.positiveTint, HD.positive),
      'overdue' => ('Quá hạn', HD.negativeTint, HD.negative),
      'draft' => ('Nháp — chưa gửi', HD.paperSunken, HD.inkSoft),
      _ =>
        h.daTra > 0
            ? ('Đã trả một phần', HD.warningTint, HD.svcAmber)
            : ('Chưa thanh toán', HD.warningTint, HD.svcAmber),
    };
    return _Nhan(chu: chu, nen: nen, mau: mau);
  }
}

// ── Định dạng ────────────────────────────────────────────────────────────────

String _hai(int n) => n.toString().padLeft(2, '0');

String _ngayVN(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : '${_hai(d.day)}/${_hai(d.month)}/${d.year}';
}

String _ngayNgan(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : '${_hai(d.day)}/${_hai(d.month)}';
}

String _gio(DateTime d) =>
    '${_hai(d.hour)}:${_hai(d.minute)} ${_hai(d.day)}/${_hai(d.month)}';

/// '2026-08' → 'T8/2026'.
String _kyNgan(String ky) {
  final phan = ky.split('-');
  if (phan.length < 2) return ky;
  return 'T${int.tryParse(phan[1]) ?? phan[1]}/${phan[0]}';
}

/// Số công tơ / diện tích: số tròn in không phần lẻ, có dấu chấm nghìn.
String _so(double v) => v == v.roundToDouble()
    ? PriceFormat.full(v).replaceAll('đ', '')
    : v.toStringAsFixed(1).replaceAll('.', ',');

String _chuCaiDau(String ten) {
  final tu = ten.trim().split(RegExp(r'\s+'));
  return tu.isEmpty || tu.last.isEmpty ? '?' : tu.last.substring(0, 1).toUpperCase();
}

String? _conLai(HopDongHienTai hd) {
  final n = hd.conLaiNgay;
  if (n == null) return null;
  final han = _ngayNgan(hd.ketThuc);
  if (n < 0) return 'Quá hạn ${-n} ngày (Hạn $han)';
  if (n < 31) return 'Còn $n ngày (Hạn $han)';
  return 'Còn ${n ~/ 30} tháng (Hạn $han)';
}

String? _nhanChiSo(String trangThai) => switch (trangThai) {
  'chua_gui' => 'Người thuê chưa gửi số tháng này',
  'cho_duyet' => 'Có số mới đang chờ duyệt',
  'thieu_anh' => 'Chờ duyệt — thiếu ảnh công tơ',
  'can_chup_lai' => 'Đã yêu cầu người thuê chụp lại',
  _ => null,
};

BoxDecoration _nenO() => BoxDecoration(
  color: HD.paper,
  borderRadius: BorderRadius.circular(HD.r12),
  border: Border.all(color: HD.hairline.withValues(alpha: 0.4)),
);

/// '0982345678' → '0982 345 678' — nhóm số như mockup. Số không đủ 10 chữ số
/// (máy bàn, số nước ngoài) giữ nguyên.
String _sdtNhom(String sdt) {
  final so = sdt.replaceAll(RegExp(r'\D'), '');
  if (so.length != 10) return sdt;
  return '${so.substring(0, 4)} ${so.substring(4, 7)} ${so.substring(7)}';
}

// ── Thành phần ───────────────────────────────────────────────────────────────

/// Khung chung của mọi khối: thẻ trắng bo 16, tiêu đề chữ hoa nhỏ.
class _The extends StatelessWidget {
  const _The({
    required this.tieuDe,
    required this.child,
    this.icon,
    this.mauIcon = HD.accent,
    this.cham,
    this.phu,
    this.phai,
  });

  final String tieuDe;
  final Widget child;
  final IconData? icon;
  final Color mauIcon;
  final Color? cham;
  final String? phu;
  final Widget? phai;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HD.hairline.withValues(alpha: 0.5)),
      boxShadow: HD.sunkenShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (cham != null)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: cham, shape: BoxShape.circle),
              )
            else if (icon != null)
              Icon(icon, size: 15, color: mauIcon),
            const SizedBox(width: HD.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tieuDe,
                    style: HD.bodyBold(size: 11, color: HD.inkSoft).copyWith(letterSpacing: 0.6),
                  ),
                  if (phu != null)
                    Text(phu!, style: HD.body(size: 11, color: HD.inkMuted)),
                ],
              ),
            ),
            if (phai != null) ...[const SizedBox(width: HD.s8), phai!],
          ],
        ),
        const SizedBox(height: HD.s12),
        child,
      ],
    ),
  );
}

/// Khối trống có hướng dẫn: nói khối này sẽ chứa gì và bắt đầu từ đâu.
class _GoiY extends StatelessWidget {
  const _GoiY({required this.icon, required this.chu, required this.phu});

  final IconData icon;
  final String chu;
  final String phu;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: _nenO(),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: HD.paperRaised,
            borderRadius: BorderRadius.circular(HD.r8),
          ),
          child: Icon(icon, size: 18, color: HD.inkMuted),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(chu, style: HD.bodyBold(size: 13)),
              const SizedBox(height: 2),
              Text(phu, style: HD.body(size: 11, color: HD.inkMuted)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Nhan extends StatelessWidget {
  const _Nhan({required this.chu, required this.nen, required this.mau});

  final String chu;
  final Color nen;
  final Color mau;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: nen, borderRadius: BorderRadius.circular(HD.rPill)),
    child: Text(chu, style: HD.bodyBold(size: 10, color: mau)),
  );
}

class _LienKet extends StatelessWidget {
  const _LienKet({required this.chu, required this.onTap});

  final String chu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(HD.r8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(chu, style: HD.bodyBold(size: 11, color: HD.accent)),
          const Icon(Icons.chevron_right, size: 14, color: HD.accent),
        ],
      ),
    ),
  );
}

class _NutTron extends StatelessWidget {
  const _NutTron({
    required this.icon,
    required this.tooltip,
    required this.co,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final double co;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: HD.paperSunken,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: co,
          height: co,
          child: Icon(icon, size: co * 0.5, color: HD.inkSoft),
        ),
      ),
    ),
  );
}

class _NutVuong extends StatelessWidget {
  const _NutVuong({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: HD.paperSunken,
      borderRadius: BorderRadius.circular(HD.r12),
      child: InkWell(
        borderRadius: BorderRadius.circular(HD.r12),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: HD.inkSoft),
        ),
      ),
    ),
  );
}

class _NutNho extends StatelessWidget {
  const _NutNho({
    required this.icon,
    required this.mau,
    required this.chu,
    required this.onTap,
    this.dangChay = false,
  });

  final IconData icon;
  final Color mau;
  final String chu;
  final VoidCallback onTap;
  final bool dangChay;

  @override
  Widget build(BuildContext context) => Material(
    color: HD.paperRaised,
    borderRadius: BorderRadius.circular(HD.r12),
    child: InkWell(
      borderRadius: BorderRadius.circular(HD.r12),
      onTap: dangChay ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: HD.s8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
        ),
        child: Column(
          children: [
            dangChay
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: mau),
                  )
                : Icon(icon, size: 16, color: mau),
            const SizedBox(height: 4),
            Text(chu, style: HD.bodyBold(size: 11, color: HD.inkSoft)),
          ],
        ),
      ),
    ),
  );
}

class _ThanhTienDo extends StatelessWidget {
  const _ThanhTienDo({required this.tyLe});

  final double tyLe;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(HD.rPill),
    child: Container(
      height: 8,
      color: HD.paperSunken,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: (tyLe / 100).clamp(0.0, 1.0),
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [HD.positive, HD.accent]),
          ),
        ),
      ),
    ),
  );
}

class _OThongSo extends StatelessWidget {
  const _OThongSo({
    required this.icon,
    required this.mau,
    required this.nhan,
    required this.giaTri,
    this.onKhai,
  });

  final IconData icon;
  final Color mau;
  final String nhan;

  /// `null` = chưa khai.
  final String? giaTri;
  final VoidCallback? onKhai;

  @override
  Widget build(BuildContext context) => Material(
    color: HD.paperRaised,
    borderRadius: BorderRadius.circular(HD.r12),
    child: InkWell(
      borderRadius: BorderRadius.circular(HD.r12),
      onTap: onKhai,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: HD.hairline.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: mau.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(HD.r8),
              ),
              child: Icon(icon, size: 14, color: mau),
            ),
            const SizedBox(height: 4),
            Text(nhan, maxLines: 1, style: HD.body(size: 10, color: HD.inkMuted)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                giaTri ?? 'Chưa khai',
                maxLines: 1,
                style: HD.bodyBold(size: 12, color: giaTri == null ? HD.inkMuted : HD.ink),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OTien extends StatelessWidget {
  const _OTien({
    super.key,
    required this.nhan,
    required this.so,
    required this.mauSo,
    required this.phu,
    required this.nen,
    required this.vien,
    this.iconPhu,
    this.mauPhu = HD.inkMuted,
    this.onTap,
  });

  final String nhan;
  final String so;
  final Color mauSo;
  final String phu;
  final Color nen;
  final Color vien;

  /// Dòng phụ có biểu tượng (✓ Đã đóng đủ) thì in đậm theo màu trạng thái.
  final IconData? iconPhu;
  final Color mauPhu;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: nen,
    borderRadius: BorderRadius.circular(HD.r12),
    child: InkWell(
      borderRadius: BorderRadius.circular(HD.r12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: vien),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nhan, style: HD.body(size: 11, color: HD.inkMuted)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(so, style: HD.bodyBold(size: 14, color: mauSo)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (iconPhu != null) ...[
                  Icon(iconPhu, size: 12, color: mauPhu),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    phu,
                    style: iconPhu != null
                        ? HD.bodyBold(size: 10, color: mauPhu)
                        : HD.body(size: 10, color: mauPhu),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _OCongTo extends StatelessWidget {
  const _OCongTo({
    required this.tieuDe,
    required this.icon,
    required this.mau,
    required this.gia,
    required this.dung,
    required this.cu,
    required this.moi,
  });

  final String tieuDe;
  final IconData icon;
  final Color mau;
  final String gia;
  final String? dung;
  final double? cu;
  final double? moi;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: mau.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(HD.r12),
      border: Border.all(color: mau.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: mau),
            const SizedBox(width: 4),
            Text(tieuDe, style: HD.bodyBold(size: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: mau.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(HD.r4),
            ),
            child: Text(gia, style: HD.bodyBold(size: 10, color: mau)),
          ),
        ),
        const SizedBox(height: HD.s8),
        Row(
          children: [
            Text('Tiêu thụ:', style: HD.body(size: 11, color: HD.inkMuted)),
            const SizedBox(width: 4),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(dung ?? '—', style: HD.bodyBold(size: 14, color: mau)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(height: 1, color: mau.withValues(alpha: 0.2)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                'Cũ: ${cu == null ? '—' : _so(cu!)}',
                style: HD.body(size: 10, color: HD.inkMuted),
              ),
            ),
            Text(
              'Mới: ${moi == null ? '—' : _so(moi!)}',
              style: HD.body(size: 10, color: HD.inkMuted),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Ô tài sản: biểu tượng · tên + thông số · chấm tình trạng (xanh tốt, cam hao
/// mòn, đỏ hỏng, xám chưa ghi).
class _OTaiSan extends StatelessWidget {
  const _OTaiSan({required this.muc, this.onTap});

  final MucTaiSan muc;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, mau) = iconTaiSan(muc.loai);
    final phu = muc.thongSo ??
        (muc.taiSan == null ? 'Chưa ghi thông số' : TaiSan.nhanTinhTrang[muc.tinhTrang] ?? '');
    return Material(
      color: HD.paper,
      borderRadius: BorderRadius.circular(HD.r12),
      child: InkWell(
        borderRadius: BorderRadius.circular(HD.r12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(HD.s8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HD.r12),
            border: Border.all(color: HD.hairline.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: HD.paperRaised,
                  borderRadius: BorderRadius.circular(HD.r8),
                ),
                child: Icon(icon, size: 14, color: mau),
              ),
              const SizedBox(width: HD.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      muc.ten,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.bodyBold(size: 11),
                    ),
                    Text(
                      phu,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(size: 9, color: HD.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: TaiSan.nhanTinhTrang[muc.tinhTrang] ?? 'Chưa ghi tình trạng',
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: mauTinhTrangTaiSan(muc.tinhTrang),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OSuaChua extends StatelessWidget {
  const _OSuaChua({required this.muc, this.onXong, this.onXoa});

  final SuaChua muc;
  final VoidCallback? onXong;
  final VoidCallback? onXoa;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: _nenO(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(muc.tieuDe, style: HD.bodyBold(size: 12))),
            const SizedBox(width: 6),
            Text(_ngayVN(muc.ngay), style: HD.body(size: 10, color: HD.inkMuted)),
            if (onXoa != null)
              InkWell(
                onTap: onXoa,
                borderRadius: BorderRadius.circular(HD.r8),
                child: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.close, size: 14, color: HD.inkMuted),
                ),
              ),
          ],
        ),
        if (muc.moTa != null) ...[
          const SizedBox(height: 2),
          Text(muc.moTa!, style: HD.body(size: 11, color: HD.inkMuted)),
        ],
        if (muc.nguoiThucHien != null || muc.chiPhi != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  muc.nguoiThucHien == null ? '' : 'Thực hiện: ${muc.nguoiThucHien}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.body(size: 10, color: HD.inkMuted),
                ),
              ),
              if (muc.chiPhi != null)
                Text(
                  'Chi phí: ${PriceFormat.full(muc.chiPhi!)}',
                  style: HD.bodyBold(size: 10, color: HD.inkSoft),
                ),
            ],
          ),
        ],
        if (muc.dangXuLy) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const _Nhan(chu: 'Đang xử lý', nen: HD.warningTint, mau: HD.svcAmber),
              const Spacer(),
              if (onXong != null)
                TextButton(
                  onPressed: onXong,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: HD.positive,
                  ),
                  child: const Text('Đánh dấu xong'),
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _DongXemHet extends StatelessWidget {
  const _DongXemHet({required this.chu, required this.mo, required this.onTap});

  final String chu;
  final bool mo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: HD.s8),
      child: Row(
        children: [
          Expanded(child: Text(chu, style: HD.body(size: 11, color: HD.inkMuted))),
          Icon(mo ? Icons.expand_less : Icons.arrow_forward, size: 14, color: HD.inkMuted),
        ],
      ),
    ),
  );
}

class _Loi extends StatelessWidget {
  const _Loi({required this.chu, required this.onThuLai});

  final String chu;
  final Future<void> Function() onThuLai;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(HD.s24),
    child: Column(
      children: [
        Text(chu, textAlign: TextAlign.center, style: HD.body(size: 13, color: HD.inkMuted)),
        const SizedBox(height: HD.s12),
        OutlinedButton(onPressed: onThuLai, child: const Text('Thử lại')),
      ],
    ),
  );
}

/// Ảnh phòng + nhãn loại phòng / ban công + giá niêm yết + "Sửa tin".
class _AnhPhong extends StatefulWidget {
  const _AnhPhong({required this.room, this.onSua});

  final RoomModel room;
  final VoidCallback? onSua;

  @override
  State<_AnhPhong> createState() => _AnhPhongState();
}

class _AnhPhongState extends State<_AnhPhong> {
  int _trang = 0;

  @override
  Widget build(BuildContext context) {
    final r = widget.room;
    final anh = [for (final a in r.images) if (a.trim().isNotEmpty) a];
    final gia = r.giaKenh ?? r.basePrice;
    final hauTo = KenhKhaiThac.hauToDonVi[r.donVi ?? 'thang'] ?? '/tháng';
    final nhanLoai = [
      if ((r.loaiPhong ?? '').isNotEmpty) r.loaiPhong!,
      if (r.areaM2 != null) '${_so(r.areaM2!)} m²',
    ].join(' • ');
    final chu = HD.paperRaised;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (anh.isEmpty)
              ColoredBox(
                color: HD.inkSoft,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_camera_outlined, size: 32, color: chu.withValues(alpha: 0.6)),
                      const SizedBox(height: 4),
                      Text(
                        'Chưa có ảnh phòng',
                        style: HD.body(size: 12, color: chu.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              )
            else
              PageView.builder(
                itemCount: anh.length,
                onPageChanged: (i) => setState(() => _trang = i),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => showImageGallery(
                    context,
                    [for (final a in anh) anhTuyetDoi(a)],
                    initialIndex: i,
                  ),
                  child: CachedNetworkImage(
                    imageUrl: anhTuyetDoi(anh[i]),
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const ColoredBox(color: HD.inkSoft),
                  ),
                ),
              ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      HD.ink.withValues(alpha: 0.8),
                      HD.ink.withValues(alpha: 0.2),
                      HD.ink.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 70,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (nhanLoai.isNotEmpty)
                    _NhanAnh(chu: nhanLoai, nen: HD.ink.withValues(alpha: 0.6)),
                  if (r.doTrongPhong.contains('ban_cong'))
                    const _NhanAnh(chu: 'Có ban công', nen: HD.accent),
                ],
              ),
            ),
            if (anh.length > 1)
              Positioned(
                top: 12,
                right: 12,
                child: _NhanAnh(
                  chu: '${_trang + 1}/${anh.length}',
                  nen: HD.ink.withValues(alpha: 0.5),
                  icon: Icons.image_outlined,
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Giá thuê niêm yết',
                          style: HD.body(size: 12, color: chu.withValues(alpha: 0.8)),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: gia > 0 ? PriceFormat.full(gia) : 'Chưa đặt giá',
                                  style: HD.bodyBold(size: 20, color: chu),
                                ),
                                if (gia > 0)
                                  TextSpan(
                                    text: ' $hauTo',
                                    style: HD.body(size: 12, color: chu.withValues(alpha: 0.8)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onSua != null)
                    Material(
                      color: chu.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(HD.r12),
                      child: InkWell(
                        key: const ValueKey('sua-tin'),
                        borderRadius: BorderRadius.circular(HD.r12),
                        onTap: widget.onSua,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_outlined, size: 13, color: HD.ink),
                              const SizedBox(width: 6),
                              Text('Sửa tin', style: HD.bodyBold(size: 12)),
                            ],
                          ),
                        ),
                      ),
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

class _NhanAnh extends StatelessWidget {
  const _NhanAnh({required this.chu, required this.nen, this.icon});

  final String chu;
  final Color nen;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: nen, borderRadius: BorderRadius.circular(HD.r8)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: HD.paperRaised),
          const SizedBox(width: 4),
        ],
        Text(chu, style: HD.bodyBold(size: 11, color: HD.paperRaised)),
      ],
    ),
  );
}
