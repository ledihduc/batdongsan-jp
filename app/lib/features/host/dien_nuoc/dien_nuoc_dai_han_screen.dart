import 'package:flutter/material.dart';

import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/dien_nuoc_api.dart';
import 'package:house_booking/features/host/dien_nuoc/bang_duyet_thang_section.dart';
import 'package:house_booking/features/host/dien_nuoc/chup_cong_to_sheet.dart';
import 'package:house_booking/features/host/dien_nuoc/dien_nuoc_chung.dart';
import 'package:house_booking/features/host/hoa_don/dich_vu_hoa_don_screen.dart';

export 'package:house_booking/features/host/dien_nuoc/dien_nuoc_chung.dart'
    show anhTuyetDoi;

/// ĐIỆN NƯỚC — chỉ số và chi phí hàng tháng của phòng thuê DÀI HẠN, dựng theo
/// mockup "Điện nước" (12/09/2026): ba ô chọn toà · phòng · tháng → tổng quan
/// tháng (số điện, số nước, tổng chi phí, % so với tháng trước) + thanh ba bước
/// duyệt · hai thẻ đồng hồ kèm ảnh công tơ · biểu đồ 6 tháng gần nhất.
/// Route: không — `Navigator.push` từ Trang chủ chủ nhà và Hồ sơ phòng.
/// API: [DienNuocApi] (`/api/host/dien-nuoc`, `/api/host/dien-nuoc/phong`).
///
/// Mở từ nút "Lập hoá đơn tháng này" thì có thêm thanh dưới "Tiếp tục" —
/// chỉ số điện nước là thứ phải chốt TRƯỚC khi tính tiền, nên nó là bước một
/// của luồng lập hoá đơn, không phải một màn rời.
///
/// Chọn "Tất cả phòng" ở ô phòng thì thân màn là bảng duyệt cả toà
/// ([BangDuyetThangSection]) — chủ nhà hai mươi phòng cần duyệt hàng loạt.
///
/// Mọi con số là số THẬT từ server. Tháng chưa ai gửi chỉ số thì ghi "Chưa gửi",
/// KHÔNG vẽ cột 0 — cột 0 đọc ra "tháng đó không dùng điện". Mũi tên tăng/giảm
/// chỉ hiện khi có cả hai tháng để so.
class DienNuocDaiHanScreen extends StatefulWidget {
  const DienNuocDaiHanScreen({
    super.key,
    required this.toa,
    this.buildingId,
    this.api = const DienNuocApi(),
    this.thangBanDau,
    this.roomIdBanDau,
    this.tatCaPhongBanDau = false,
    this.contractIdHoaDon,
  });

  /// Toà người này đứng tên — lấy sẵn từ Tổng quan, khỏi gọi thêm một API.
  final List<({int id, String ten})> toa;
  final int? buildingId;
  final DienNuocApi api;

  /// 'YYYY-MM'. Chỉ để test ghim tháng; bình thường là tháng hiện tại.
  final String? thangBanDau;

  /// Mở thẳng chi tiết một phòng (từ Hồ sơ phòng).
  final int? roomIdBanDau;

  /// Mở thẳng bảng duyệt cả toà.
  final bool tatCaPhongBanDau;

  /// Khác `null` = đang trong luồng LẬP HOÁ ĐƠN của hợp đồng này: chốt chỉ số
  /// (chụp công tơ nếu còn thiếu) rồi bấm "Tiếp tục" sang Dịch vụ & hoá đơn.
  /// `null` = vào xem điện nước bình thường, không có thanh dưới.
  final int? contractIdHoaDon;

  @override
  State<DienNuocDaiHanScreen> createState() => _DienNuocDaiHanScreenState();
}

class _DienNuocDaiHanScreenState extends State<DienNuocDaiHanScreen> {
  late int? _toaId =
      widget.buildingId ?? (widget.toa.isEmpty ? null : widget.toa.first.id);
  late String _thang = widget.thangBanDau ?? _thangNay();
  late int? _phongId = widget.roomIdBanDau;
  late bool _tatCa = widget.tatCaPhongBanDau;
  BangDienNuoc? _bang;
  ChiTietDienNuoc? _ct;
  bool _dangTai = false;
  String? _loi;

  static String _thangNay() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  Future<void> _nap() async {
    final id = _toaId;
    if (id == null) return;
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final b = await widget.api.bangThang(id, _thang);
      if (!mounted) return;
      setState(() {
        _bang = b;
        _phongId = _phongDauTien(b);
      });
      await _napChiTiet();
    } catch (e) {
      if (mounted) setState(() => _loi = 'Không tải được chỉ số. $e');
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  /// Phòng nào mở sẵn: phòng đang chọn nếu còn trong toà, không thì phòng CẦN
  /// làm trước (chờ duyệt / thiếu ảnh) — chủ nhà mở màn là để xử lý việc đó.
  int? _phongDauTien(BangDienNuoc b) {
    if (_tatCa) return null;
    final cu = _phongId;
    // Phòng mở THẲNG từ Hồ sơ phòng phải giữ nguyên, kể cả khi tháng này chưa
    // có dòng nào trong bảng (chưa ai gửi chỉ số, hợp đồng vừa ký). Nhảy sang
    // phòng khác là trả lời câu hỏi của phòng khác — càng tệ trong luồng lập
    // hoá đơn, vì hoá đơn sẽ là của phòng mình không chọn.
    if (cu != null && cu == widget.roomIdBanDau) return cu;
    if (b.dong.isEmpty) return null;
    if (cu != null && b.dong.any((d) => d.roomId == cu)) return cu;
    return b.dong
        .firstWhere(
          (d) => d.trangThai == 'cho_duyet' || d.trangThai == 'thieu_anh',
          orElse: () => b.dong.first,
        )
        .roomId;
  }

  Future<void> _napChiTiet() async {
    final rid = _phongId;
    if (rid == null) {
      if (mounted) setState(() => _ct = null);
      return;
    }
    try {
      final ct = await widget.api.chiTietPhong(rid, _thang);
      if (mounted) setState(() => _ct = ct);
    } catch (e) {
      if (mounted) setState(() => _loi = 'Không tải được chi tiết phòng. $e');
    }
  }

  Future<void> _duyet(int readingId, String maPhong) async {
    try {
      await widget.api.duyet(readingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã duyệt chỉ số phòng $maPhong')),
      );
      await _nap();
    } catch (e) {
      _baoLoi(e);
    }
  }

  /// Chủ nhà TỰ chụp công tơ: camera trực tiếp, ảnh đóng dấu giờ + toạ độ.
  /// Khác nút "Yêu cầu chụp lại" (bắt NGƯỜI THUÊ chụp) ở khối tổng quan.
  Future<void> _tuChup(ChiTietDienNuoc ct, String loai) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ChupCongToSheet(
        roomId: ct.roomId,
        maPhong: ct.maPhong,
        loai: loai,
        chiSoCu: loai == 'dien' ? ct.dienCu : ct.nuocCu,
        // Chưa ai gửi tháng này thì không có số để đối chiếu.
        chiSoDangGhi: ct.readingId == null
            ? null
            : (loai == 'dien' ? ct.dienMoi : ct.nuocMoi),
        nguonDangGhi: ct.nguoiGui.isNotEmpty ? 'Người thuê gửi' : 'Đang ghi',
      ),
    );
    if (ok == true) await _nap();
  }

  Future<void> _chupLai(int readingId, String maPhong) async {
    final lyDo = await showDialog<String>(
      context: context,
      builder: (_) => HopThoaiChupLai(maPhong: maPhong),
    );
    if (lyDo == null) return;
    try {
      await widget.api.chupLai(readingId, lyDo);
      await _nap();
    } catch (e) {
      _baoLoi(e);
    }
  }

  void _baoLoi(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Không thực hiện được. $e')));
  }

  void _chonPhong(int? roomId) {
    setState(() {
      _tatCa = roomId == null;
      _phongId = roomId;
      _ct = null;
    });
    _napChiTiet();
  }

  void _doiThang(String t) {
    setState(() {
      _thang = t;
      _bang = null;
      _ct = null;
    });
    _nap();
  }

  List<String> _muoiHaiThang() {
    final n = DateTime.now();
    return [
      for (var i = 0; i < 12; i++)
        () {
          final d = DateTime(n.year, n.month - i, 1);
          return '${d.year}-${d.month.toString().padLeft(2, '0')}';
        }(),
    ];
  }

  Future<void> _huongDan() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(HD.s20, 0, HD.s20, HD.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Điện nước chạy thế nào', style: HD.bodyBold(size: 16)),
            const SizedBox(height: HD.s12),
            for (final (i, chu) in const [
              (1, 'Người thuê chụp công tơ và gửi chỉ số qua app.'),
              (2, 'Bạn mở ảnh, đối chiếu rồi bấm Duyệt — hoặc yêu cầu chụp lại kèm lý do.'),
              (3, 'Hoá đơn tháng CHỈ tính trên chỉ số đã duyệt.'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: HD.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: HD.accentTint,
                        shape: BoxShape.circle,
                      ),
                      child: Text('$i', style: HD.bodyBold(size: 11, color: HD.accent)),
                    ),
                    const SizedBox(width: HD.s8),
                    Expanded(child: Text(chu, style: HD.body(size: 13))),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final b = _bang;
    final ct = _ct;
    return Scaffold(
      backgroundColor: HD.paper,
      bottomNavigationBar: widget.contractIdHoaDon == null
          ? null
          : _thanhTiepTuc(ct),
      body: SafeArea(
        child: RefreshIndicator(
          color: HD.accent,
          onRefresh: _nap,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s32),
            children: [
              _dauTrang(),
              const SizedBox(height: HD.s12),
              _baOChon(b),
              const SizedBox(height: HD.s12),
              if (_dangTai && b != null)
                const Padding(
                  padding: EdgeInsets.only(bottom: HD.s8),
                  child: LinearProgressIndicator(minHeight: 2, color: HD.accent),
                ),
              if (widget.toa.isEmpty)
                const DienNuocRong('Bạn chưa có toà nhà nào.')
              else if (_loi != null)
                Text(_loi!, style: HD.body(size: 13, color: HD.negative))
              else if (b == null)
                const Padding(
                  padding: EdgeInsets.all(HD.s32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_tatCa || b.tongPhong == 0)
                BangDuyetThangSection(
                  bang: b,
                  nhanThangHien: nhanThang(_thang),
                  onDuyet: (d) => _duyet(d.readingId!, d.maPhong),
                  onChupLai: (d) => _chupLai(d.readingId!, d.maPhong),
                  onXem: (d) => _chonPhong(d.roomId),
                )
              else if (ct == null)
                const Padding(
                  padding: EdgeInsets.all(HD.s32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _theTongQuan(ct),
                const SizedBox(height: HD.s12),
                _haiThePhongTo(ct),
                const SizedBox(height: HD.s12),
                _theLichSu(ct),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Bước một xong thì đi tiếp. Chỉ số chưa duyệt KHÔNG chặn — chủ nhà có
  /// quyền gửi hoá đơn chỉ tiền phòng rồi bổ sung điện nước sau; trang kế tiếp
  /// sẽ nói rõ hoá đơn đang thiếu gì.
  Widget _thanhTiepTuc(ChiTietDienNuoc? ct) {
    final daDuyet = ct?.trangThai == 'da_duyet';
    return Container(
      padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, HD.s12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: HD.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Bước 1 · Chốt chỉ số', style: HD.bodyBold(size: 13)),
                  Text(
                    daDuyet
                        ? 'Đã có chỉ số ${nhanThang(_thang).toLowerCase()}'
                        : 'Chưa có chỉ số đã duyệt tháng này',
                    style: HD.body(
                      size: 11,
                      color: daDuyet ? HD.positive : HD.svcAmber,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: HD.s12),
            FilledButton.icon(
              key: const ValueKey('tiep-tuc-hoa-don'),
              onPressed: ct == null ? null : _tiepTuc,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Tiếp tục'),
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: HD.s16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HD.r12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tiepTuc() async {
    final id = widget.contractIdHoaDon;
    if (id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DichVuHoaDonScreen(contractId: id, thang: _thang),
      ),
    );
    // Gửi hoá đơn xong quay lại đây: chỉ số có thể đã đổi trạng thái.
    if (mounted) await _napChiTiet();
  }

  Widget _dauTrang() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.maybePop(context),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Điện nước', style: HD.bodyBold(size: 21)),
            Text(
              'Quản lý chỉ số và chi phí hàng tháng',
              style: HD.body(size: 12, color: HD.inkMuted),
            ),
          ],
        ),
      ),
      IconButton(
        key: const ValueKey('huong-dan'),
        tooltip: 'Luồng duyệt chỉ số',
        icon: const Icon(Icons.help_outline, color: HD.inkMuted),
        onPressed: _huongDan,
      ),
    ],
  );

  Widget _baOChon(BangDienNuoc? b) => Row(
    children: [
      Expanded(
        child: _Pill(
          icon: Icons.apartment,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              key: const ValueKey('chon-toa'),
              isExpanded: true,
              value: _toaId,
              hint: const Text('Chọn toà'),
              style: HD.body(size: 12),
              items: [
                for (final t in widget.toa)
                  DropdownMenuItem(
                    value: t.id,
                    child: Text(t.ten, overflow: TextOverflow.ellipsis),
                  ),
                // Mở thẳng từ Hồ sơ phòng: toà đang xem có thể không nằm trong
                // danh sách truyền vào. DropdownButton ĐÒI đúng một mục khớp
                // `value`, thiếu là ném assert → màn đỏ, nên tự thêm mục đó.
                if (_toaId != null && !widget.toa.any((t) => t.id == _toaId))
                  DropdownMenuItem(
                    value: _toaId,
                    child: Text(
                      (_bang?.tenToa.isNotEmpty ?? false)
                          ? _bang!.tenToa
                          : 'Toà đang xem',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) {
                setState(() {
                  _toaId = v;
                  _bang = null;
                  _ct = null;
                  _phongId = null;
                });
                _nap();
              },
            ),
          ),
        ),
      ),
      const SizedBox(width: HD.s8),
      Expanded(
        child: _Pill(
          icon: Icons.bed,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              key: const ValueKey('chon-phong'),
              isExpanded: true,
              value: _tatCa ? null : _phongId,
              style: HD.body(size: 12),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Tất cả phòng'),
                ),
                for (final d in b?.dong ?? const <DongDienNuoc>[])
                  DropdownMenuItem<int?>(
                    value: d.roomId,
                    child: Text(d.maPhong, overflow: TextOverflow.ellipsis),
                  ),
                // Phòng mở thẳng từ Hồ sơ phòng chưa chắc có trong bảng tháng
                // (bảng chưa tải xong, hoặc phòng không có hợp đồng tháng này).
                if (!_tatCa &&
                    _phongId != null &&
                    !(b?.dong ?? const <DongDienNuoc>[]).any(
                      (d) => d.roomId == _phongId,
                    ))
                  DropdownMenuItem<int?>(
                    value: _phongId,
                    child: Text(
                      _ct?.maPhong ?? 'Phòng đang xem',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _chonPhong,
            ),
          ),
        ),
      ),
      const SizedBox(width: HD.s8),
      Expanded(
        child: _Pill(
          icon: Icons.calendar_month,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const ValueKey('chon-thang'),
              isExpanded: true,
              value: _thang,
              style: HD.body(size: 12),
              items: [
                for (final t in {..._muoiHaiThang(), _thang})
                  DropdownMenuItem(
                    value: t,
                    child: Text(nhanThang(t), overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) {
                if (v != null) _doiThang(v);
              },
            ),
          ),
        ),
      ),
    ],
  );

  // ── chi tiết một phòng ─────────────────────────────────────────────────────

  Widget _theTongQuan(ChiTietDienNuoc ct) {
    final n = nhanTrangThaiChiSo(ct.trangThai);
    final daGui = ct.readingId != null;
    return _The(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: HD.accentTint,
                  borderRadius: BorderRadius.circular(HD.r12),
                ),
                child: const Icon(Icons.apartment, size: 20, color: HD.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng quan ${nhanThang(ct.thang).toLowerCase()}',
                      style: HD.bodyBold(size: 13),
                    ),
                    Text(
                      daGui
                          ? 'Phòng ${ct.maPhong} · cập nhật từ ảnh đồng hồ'
                          : 'Phòng ${ct.maPhong} · chưa có số tháng này',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(size: 11, color: HD.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: HD.s8),
              _NhanTron(chu: n.chu, mau: n.mau, icon: n.icon),
            ],
          ),
          const SizedBox(height: HD.s12),
          Divider(height: 1, color: HD.hairline.withValues(alpha: 0.6)),
          const SizedBox(height: HD.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _OSo(
                  icon: Icons.bolt,
                  mau: HD.accent,
                  nhan: 'Số điện',
                  so: ct.dienDung == null ? '—' : '${soDienNuoc(ct.dienDung)} kWh',
                  phu: ct.tienDien == null
                      ? '${PriceFormat.full(ct.giaDien)}/kWh'
                      : '≈ ${PriceFormat.full(ct.tienDien!)}',
                  phanTram: ct.dienPhanTram,
                ),
              ),
              Expanded(
                child: _OSo(
                  icon: Icons.water_drop,
                  mau: HD.svcBlue,
                  nhan: 'Số nước',
                  so: ct.nuocDung == null ? '—' : '${soDienNuoc(ct.nuocDung)} m³',
                  phu: ct.tienNuoc == null
                      ? '${PriceFormat.full(ct.giaNuoc)}/m³'
                      : '≈ ${PriceFormat.full(ct.tienNuoc!)}',
                  phanTram: ct.nuocPhanTram,
                ),
              ),
              Expanded(
                child: _OSo(
                  icon: Icons.account_balance_wallet_outlined,
                  mau: HD.accent,
                  nhan: 'Tổng chi phí',
                  so: ct.thanhTien == null ? '—' : PriceFormat.full(ct.thanhTien!),
                  mauSo: HD.accent,
                  phu: '',
                  phanTram: ct.tienPhanTram,
                ),
              ),
            ],
          ),
          const SizedBox(height: HD.s12),
          Divider(height: 1, color: HD.hairline.withValues(alpha: 0.6)),
          const SizedBox(height: HD.s12),
          _BaBuoc(ct: ct),
          if ((ct.lyDoTraVe ?? '').isNotEmpty) ...[
            const SizedBox(height: HD.s12),
            Row(
              children: [
                const Icon(Icons.refresh, size: 14, color: HD.negative),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Đã yêu cầu chụp lại: ${ct.lyDoTraVe}',
                    style: HD.body(size: 11, color: HD.negative),
                  ),
                ),
              ],
            ),
          ],
          // Mockup không vẽ hai nút này (nó là màn người thuê xem), nhưng chủ
          // nhà đứng ở bước 2 của chính thanh tiến độ trên — không có nút thì
          // thanh đó đứng mãi.
          if (daGui && ct.trangThai != 'da_duyet') ...[
            const SizedBox(height: HD.s12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('duyet-chi-so'),
                    style: FilledButton.styleFrom(backgroundColor: HD.accent),
                    onPressed: () => _duyet(ct.readingId!, ct.maPhong),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Duyệt chỉ số'),
                  ),
                ),
                if (ct.trangThai != 'can_chup_lai') ...[
                  const SizedBox(width: HD.s8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('yeu-cau-chup-lai'),
                      onPressed: () => _chupLai(ct.readingId!, ct.maPhong),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yêu cầu chụp lại'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _haiThePhongTo(ChiTietDienNuoc ct) {
    // Chụp được cả khi tháng này đã có số: chủ nhà đứng tại công tơ là người có
    // thẩm quyền hơn con số cũ. Ghi đè chỉ đổi số của THÁNG NÀY; hoá đơn đã
    // phát hành giữ nguyên dòng tiền đã in.
    final ghiChu = ct.nguonAnh == 'chu_nha' && ct.chupLuc != null
        ? 'Chủ nhà chụp ${ngayGioVN(ct.chupLuc)}'
              '${ct.chupLat != null ? ' · có vị trí' : ''}'
        : null;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TheCongTo(
              tieuDe: 'Đồng hồ điện',
              icon: Icons.bolt,
              mau: HD.accent,
              anh: ct.anhDien,
              nhanAnh: 'điện',
              cu: ct.dienCu,
              moi: ct.dienMoi,
              dung: ct.dienDung,
              donVi: 'kWh',
              ghiChu: ghiChu,
              onChupLai: () => _tuChup(ct, 'dien'),
            ),
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: _TheCongTo(
              tieuDe: 'Đồng hồ nước',
              icon: Icons.water_drop,
              mau: HD.svcBlue,
              anh: ct.anhNuoc,
              nhanAnh: 'nước',
              cu: ct.nuocCu,
              moi: ct.nuocMoi,
              dung: ct.nuocDung,
              donVi: 'm³',
              ghiChu: ghiChu,
              onChupLai: () => _tuChup(ct, 'nuoc'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _theLichSu(ChiTietDienNuoc ct) => _The(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: HD.accentTint,
                borderRadius: BorderRadius.circular(HD.r8),
              ),
              child: const Icon(Icons.bar_chart, size: 18, color: HD.accent),
            ),
            const SizedBox(width: HD.s8),
            Expanded(
              child: Text(
                'Lịch sử ${ct.lichSu.length} tháng gần nhất',
                style: HD.bodyBold(size: 13),
              ),
            ),
            InkWell(
              key: const ValueKey('xem-chi-tiet-lich-su'),
              onTap: () => _bangLichSu(ct),
              borderRadius: BorderRadius.circular(HD.r8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Xem chi tiết',
                      style: HD.bodyBold(size: 12, color: HD.accent),
                    ),
                    const Icon(Icons.chevron_right, size: 14, color: HD.accent),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: HD.s8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ChuGiai(mau: HD.accent, chu: 'Điện (kWh)'),
            const SizedBox(width: HD.s20),
            _ChuGiai(mau: HD.svcBlue, chu: 'Nước (m³)'),
          ],
        ),
        const SizedBox(height: HD.s8),
        _BieuDoLichSu(ds: ct.lichSu, thangHien: ct.thang),
        const SizedBox(height: HD.s8),
        Container(
          padding: const EdgeInsets.all(HD.s12),
          decoration: BoxDecoration(
            color: HD.accentTint,
            borderRadius: BorderRadius.circular(HD.r12),
            border: Border.all(color: HD.accentSoft),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: HD.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lightbulb, size: 13, color: HD.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mẹo nhỏ', style: HD.bodyBold(size: 12, color: HD.accentDeep)),
                    const SizedBox(height: 2),
                    Text(
                      'Nhắc người thuê chụp ảnh đồng hồ rõ nét, đủ ánh sáng và '
                      'thấy rõ chỉ số — bạn duyệt nhanh hơn, khỏi phải trả về.',
                      style: HD.body(size: 11, color: HD.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _bangLichSu(ChiTietDienNuoc ct) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(HD.s20, 0, HD.s20, HD.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Điện nước phòng ${ct.maPhong} theo tháng',
              style: HD.bodyBold(size: 16),
            ),
            const SizedBox(height: HD.s12),
            for (final m in ct.lichSu.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: HD.s8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(thangNgan(m.thang), style: HD.bodyBold(size: 12)),
                    ),
                    Expanded(
                      child: Text(
                        m.dienDung == null && m.nuocDung == null
                            ? 'Chưa có chỉ số'
                            : '${soDienNuoc(m.dienDung)} kWh · '
                                  '${soDienNuoc(m.nuocDung)} m³',
                        style: HD.body(size: 12, color: HD.inkSoft),
                      ),
                    ),
                    Text(
                      m.thanhTien == null ? '—' : PriceFormat.full(m.thanhTien!),
                      style: HD.bodyBold(size: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// ── thành phần ───────────────────────────────────────────────────────────────

/// Thẻ trắng bo 16 — khung chung của mọi khối trên màn.
class _The extends StatelessWidget {
  const _The({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
    ),
    child: child,
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.child});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(HD.r12),
      border: Border.all(color: HD.hairline),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: HD.accent),
        const SizedBox(width: 2),
        Expanded(child: child),
      ],
    ),
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
        Icon(icon, size: 13, color: mau),
        const SizedBox(width: 4),
        Text(chu, style: HD.bodyBold(size: 11, color: mau)),
      ],
    ),
  );
}

/// Một trong ba ô số của khối tổng quan: biểu tượng · nhãn · số · tiền · % so
/// với tháng trước.
class _OSo extends StatelessWidget {
  const _OSo({
    required this.icon,
    required this.mau,
    required this.nhan,
    required this.so,
    required this.phu,
    required this.phanTram,
    this.mauSo,
  });

  final IconData icon;
  final Color mau;
  final String nhan;
  final String so;
  final String phu;

  /// `null` = không có tháng trước để so — không vẽ mũi tên.
  final int? phanTram;
  final Color? mauSo;

  @override
  Widget build(BuildContext context) {
    final pt = phanTram;
    // Dùng NHIỀU hơn tháng trước là tiền tăng → cam; dùng ít đi → xanh. Mockup
    // tô một màu cho cả hai chiều, nhưng màu đó đang nói sai một nửa số ca.
    final tang = (pt ?? 0) > 0;
    final mauPt = pt == null || pt == 0
        ? HD.inkMuted
        : (tang ? HD.svcAmber : HD.positive);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: mau.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 13, color: mau),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  nhan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.body(size: 11, color: HD.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(so, style: HD.bodyBold(size: 15, color: mauSo ?? HD.ink)),
          ),
          if (phu.isNotEmpty)
            Text(
              phu,
              maxLines: 1,
              style: HD.body(size: 10, color: HD.inkMuted),
            ),
          const SizedBox(height: 4),
          if (pt == null)
            Text(
              'Chưa có tháng trước để so',
              maxLines: 2,
              style: HD.body(size: 10, color: HD.inkMuted),
            )
          else if (pt == 0)
            Text('Bằng tháng trước', style: HD.body(size: 10, color: HD.inkMuted))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tang ? '▲' : '▼',
                  style: TextStyle(fontSize: 8, color: mauPt),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    '${pt.abs()}% so với tháng trước',
                    maxLines: 2,
                    style: HD.bodyBold(size: 10, color: mauPt),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Thanh ba bước: người thuê chụp → chủ nhà duyệt → đã xác nhận, kèm mốc giờ.
class _BaBuoc extends StatelessWidget {
  const _BaBuoc({required this.ct});

  final ChiTietDienNuoc ct;

  @override
  Widget build(BuildContext context) {
    final daGui = ct.readingId != null;
    final daDuyet = ct.trangThai == 'da_duyet';
    final buoc = <(String, String, _Moc)>[
      (
        ct.nguoiGui.isEmpty && daGui ? 'Chủ nhà tự ghi' : 'Người thuê đã chụp',
        daGui ? ngayGioVN(ct.guiLuc) : 'Chưa gửi chỉ số',
        daGui ? _Moc.xong : _Moc.cho,
      ),
      (
        'Chờ chủ nhà duyệt',
        ct.trangThai == 'can_chup_lai'
            ? 'Đã yêu cầu chụp lại'
            : daDuyet
            ? 'Đã xong'
            : daGui
            ? 'Đang chờ xác nhận'
            : 'Chưa có gì để duyệt',
        daDuyet
            ? _Moc.xong
            : daGui
            ? _Moc.dangLam
            : _Moc.cho,
      ),
      (
        'Đã xác nhận',
        daDuyet ? ngayGioVN(ct.duyetLuc) : '--/--/----',
        daDuyet ? _Moc.xong : _Moc.cho,
      ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < buoc.length; i++) ...[
          if (i > 0)
            Container(
              width: 18,
              height: 2,
              margin: const EdgeInsets.only(top: 9),
              color: buoc[i].$3 == _Moc.cho ? HD.hairline : HD.accent,
            ),
          Expanded(
            child: Column(
              children: [
                _ChamBuoc(moc: buoc[i].$3),
                const SizedBox(height: 6),
                Text(
                  buoc[i].$1,
                  textAlign: TextAlign.center,
                  style: buoc[i].$3 == _Moc.dangLam
                      ? HD.bodyBold(size: 10, color: HD.accent)
                      : HD.body(
                          size: 10,
                          color: buoc[i].$3 == _Moc.cho ? HD.inkMuted : HD.ink,
                        ),
                ),
                Text(
                  buoc[i].$2,
                  textAlign: TextAlign.center,
                  style: HD.body(size: 9, color: HD.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

enum _Moc { xong, dangLam, cho }

class _ChamBuoc extends StatelessWidget {
  const _ChamBuoc({required this.moc});

  final _Moc moc;

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: switch (moc) {
        _Moc.xong => HD.accent,
        _Moc.dangLam => Colors.white,
        _Moc.cho => HD.hairline,
      },
      border: Border.all(
        color: moc == _Moc.cho ? HD.hairline : HD.accent,
        width: 2,
      ),
    ),
    child: switch (moc) {
      _Moc.xong => const Icon(Icons.check, size: 13, color: Colors.white),
      _Moc.dangLam => Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: HD.accent, shape: BoxShape.circle),
        ),
      ),
      _Moc.cho => const SizedBox.shrink(),
    },
  );
}

/// Thẻ một đồng hồ: ảnh công tơ + chỉ số cũ / mới / sản lượng tiêu thụ.
class _TheCongTo extends StatelessWidget {
  const _TheCongTo({
    required this.tieuDe,
    required this.icon,
    required this.mau,
    required this.anh,
    required this.nhanAnh,
    required this.cu,
    required this.moi,
    required this.dung,
    required this.donVi,
    this.ghiChu,
    this.onChupLai,
  });

  final String tieuDe;
  final IconData icon;
  final Color mau;
  final String? anh;
  final String nhanAnh;
  final double? cu;
  final double? moi;
  final double? dung;
  final String donVi;

  /// Dòng nhỏ dưới ảnh: ai chụp, lúc nào — `null` thì không vẽ.
  final String? ghiChu;
  final VoidCallback? onChupLai;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: mau.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 13, color: mau),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                tieuDe,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.bodyBold(size: 12),
              ),
            ),
            if (onChupLai != null)
              InkWell(
                onTap: onChupLai,
                borderRadius: BorderRadius.circular(HD.r8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: mau.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(HD.r8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_camera_outlined, size: 12, color: mau),
                      const SizedBox(width: 2),
                      // Chưa có ảnh nào thì là chụp LẦN ĐẦU, "Chụp lại" đọc sai.
                      Text(
                        anh == null || anh!.isEmpty ? 'Chụp' : 'Chụp lại',
                        style: HD.bodyBold(size: 10, color: mau),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: HD.s8),
        AnhCongTo(
          url: anh,
          nhan: nhanAnh,
          mau: mau,
          cao: 112,
          nutMoRong: true,
        ),
        if (ghiChu != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.verified_outlined, size: 11, color: HD.positive),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  ghiChu!,
                  maxLines: 2,
                  style: HD.body(size: 9, color: HD.positive),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: HD.s8),
        _Dong(nhan: 'Chỉ số cũ', gt: soDienNuoc(cu)),
        _Dong(nhan: 'Chỉ số mới', gt: soDienNuoc(moi)),
        const SizedBox(height: 4),
        Divider(height: 1, color: HD.hairline.withValues(alpha: 0.6)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                'Sản lượng tiêu thụ',
                style: HD.body(size: 11, color: HD.inkSoft),
              ),
            ),
            Text(
              dung == null ? '—' : '${soDienNuoc(dung)} $donVi',
              style: HD.bodyBold(size: 12, color: mau),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Dong extends StatelessWidget {
  const _Dong({required this.nhan, required this.gt});

  final String nhan;
  final String gt;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: [
        Expanded(child: Text(nhan, style: HD.body(size: 11, color: HD.inkMuted))),
        Text(gt, style: HD.bodyBold(size: 11)),
      ],
    ),
  );
}

class _ChuGiai extends StatelessWidget {
  const _ChuGiai({required this.mau, required this.chu});

  final Color mau;
  final String chu;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: mau, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(chu, style: HD.body(size: 11, color: HD.inkMuted)),
    ],
  );
}

/// Biểu đồ cột 6 tháng: cột điện (đỏ) và cột nước (xanh) cạnh nhau, tháng đang
/// xem được tô nền. Tháng chưa có chỉ số KHÔNG có cột — cột 0 đọc ra "tháng đó
/// không dùng điện".
class _BieuDoLichSu extends StatelessWidget {
  const _BieuDoLichSu({required this.ds, required this.thangHien});

  final List<ThangDienNuoc> ds;
  final String thangHien;

  static const _caoCot = 92.0;

  @override
  Widget build(BuildContext context) {
    final moc = <double>[
      for (final m in ds) ...[m.dienDung ?? 0, m.nuocDung ?? 0],
    ];
    final tran = moc.fold<double>(0, (a, b) => b > a ? b : a);
    return SizedBox(
      height: _caoCot + 34,
      child: CustomPaint(
        painter: _LuoiNgang(tran),
        child: Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final m in ds)
                Expanded(
                  child: _CotThang(
                    muc: m,
                    tran: tran,
                    caoCot: _caoCot,
                    dangXem: m.thang == thangHien,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CotThang extends StatelessWidget {
  const _CotThang({
    required this.muc,
    required this.tran,
    required this.caoCot,
    required this.dangXem,
  });

  final ThangDienNuoc muc;
  final double tran;
  final double caoCot;
  final bool dangXem;

  double _cao(double? v) =>
      v == null || tran <= 0 ? 0 : (v / tran * caoCot).clamp(2.0, caoCot);

  @override
  Widget build(BuildContext context) {
    final chuaCo = muc.dienDung == null && muc.nuocDung == null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      decoration: dangXem
          ? BoxDecoration(
              color: HD.accentTint,
              borderRadius: BorderRadius.circular(HD.r8),
            )
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (chuaCo)
            Text('—', style: HD.body(size: 9, color: HD.inkMuted))
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Cot(
                  gt: muc.dienDung,
                  cao: _cao(muc.dienDung),
                  rong: 13,
                  mau: HD.accent,
                  dam: dangXem,
                ),
                const SizedBox(width: 2),
                _Cot(
                  gt: muc.nuocDung,
                  cao: _cao(muc.nuocDung),
                  rong: 8,
                  mau: HD.svcBlue,
                  dam: dangXem,
                ),
              ],
            ),
          const SizedBox(height: 3),
          Text(
            thangNgan(muc.thang),
            maxLines: 1,
            style: dangXem
                ? HD.bodyBold(size: 9)
                : HD.body(size: 9, color: HD.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _Cot extends StatelessWidget {
  const _Cot({
    required this.gt,
    required this.cao,
    required this.rong,
    required this.mau,
    required this.dam,
  });

  final double? gt;
  final double cao;
  final double rong;
  final Color mau;
  final bool dam;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        gt == null ? '' : soDienNuoc(gt),
        style: dam
            ? HD.bodyBold(size: 9, color: mau)
            : HD.body(size: 9, color: HD.inkSoft),
      ),
      const SizedBox(height: 1),
      Container(
        width: rong,
        height: cao,
        decoration: BoxDecoration(
          color: gt == null ? HD.hairline : mau,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      ),
    ],
  );
}

/// Ba đường kẻ ngang + nhãn trục (0 · nửa · trần) — để mắt đọc được cột cao bao
/// nhiêu mà không cần bảng số.
class _LuoiNgang extends CustomPainter {
  _LuoiNgang(this.tran);

  final double tran;

  @override
  void paint(Canvas canvas, Size size) {
    final duoi = size.height - 34; // chừa chỗ nhãn tháng
    final p = Paint()
      ..color = HD.hairline.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = duoi * i / 2;
      canvas.drawLine(Offset(26, y), Offset(size.width, y), p);
      final tp = TextPainter(
        text: TextSpan(
          text: _nhan(tran * (2 - i) / 2),
          style: HD.body(size: 9, color: HD.inkMuted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }
  }

  static String _nhan(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.round().toString();

  @override
  bool shouldRepaint(covariant _LuoiNgang old) => old.tran != tran;
}
