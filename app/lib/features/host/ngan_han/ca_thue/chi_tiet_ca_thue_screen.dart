import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/ca_thue_api.dart';
import 'package:house_booking/data/services/short_stay_api.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/ca_thue_chung.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/dang_o_screen.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/nhan_phong_screen.dart';

/// CHI TIẾT ĐẶT PHÒNG — dựng theo mockup "#BK-8821" (12/09/2026).
///
/// Cửa vào của cả luồng quầy lễ tân:
///
///     chi tiết đặt → nhận phòng → đang ở → trả phòng
///
/// Màn này trả lời "ca này là ai, mấy giờ, thu bao nhiêu, đã cọc chưa" rồi đẩy
/// sang bước kế. Mỗi bước là một màn riêng vì người trực làm từng bước ở từng
/// thời điểm khác nhau, không phải một biểu mẫu dài.
///
/// API: [CaThueApi.lay] một lượt cho cả màn; huỷ đặt vẫn đi [ShortStayApi] vì
/// huỷ là việc của vòng đời đặt phòng, không phải của quầy.
class ChiTietCaThueScreen extends StatefulWidget {
  const ChiTietCaThueScreen({
    super.key,
    required this.reservationId,
    this.api = const CaThueApi(),
    this.shortStayApi = const ShortStayApi(),
  });

  final int reservationId;
  final CaThueApi api;
  final ShortStayApi shortStayApi;

  @override
  State<ChiTietCaThueScreen> createState() => _ChiTietCaThueScreenState();
}

class _ChiTietCaThueScreenState extends State<ChiTietCaThueScreen> {
  CaThue? _ca;
  bool _dangTai = false;
  bool _dangLam = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final ca = await widget.api.lay(widget.reservationId);
      if (mounted) setState(() => _ca = ca);
    } catch (e) {
      if (mounted) {
        setState(
          () => _loi = e is ApiException ? e.message : 'Không tải được đặt phòng',
        );
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  void _bao(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _goi(String sdt) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: sdt));
    if (!ok) _bao('Không mở được ứng dụng gọi');
  }

  Future<void> _nhanTin(String sdt) async {
    final ok = await launchUrl(Uri(scheme: 'sms', path: sdt));
    if (!ok) _bao('Không mở được ứng dụng nhắn tin');
  }

  Future<void> _sangNhanPhong(CaThue ca) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NhanPhongScreen(reservationId: ca.id, api: widget.api),
      ),
    );
    if (mounted) await _nap();
  }

  Future<void> _sangDangO(CaThue ca) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DangOScreen(reservationId: ca.id, api: widget.api),
      ),
    );
    if (mounted) await _nap();
  }

  Future<void> _giaHan(CaThue ca) async {
    final phut = await _hoiSoPhut(context);
    if (phut == null || !mounted) return;
    setState(() => _dangLam = true);
    try {
      await widget.api.giaHan(ca.id, themPhut: phut);
      _bao('Đã gia hạn ${doDai(phut)}.');
      await _nap();
    } catch (e) {
      _bao(e is ApiException ? e.message : 'Không gia hạn được');
    } finally {
      if (mounted) setState(() => _dangLam = false);
    }
  }

  Future<void> _huy(CaThue ca) async {
    final ly = await _hoiLyDo(context);
    if (ly == null || !mounted) return;
    setState(() => _dangLam = true);
    try {
      await widget.shortStayApi.action(ca.id, 'cancel', ly);
      _bao('Đã huỷ đặt phòng ${ca.maDat}.');
      await _nap();
    } catch (e) {
      _bao(e is ApiException ? e.message : 'Không huỷ được');
    } finally {
      if (mounted) setState(() => _dangLam = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ca = _ca;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        title: Text('Đặt phòng', style: HD.bodyBold(size: 16)),
        actions: [
          IconButton(
            key: const Key('ca-thue-tai-lai'),
            onPressed: _dangTai ? null : _nap,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ],
      ),
      body: ca == null
          ? Center(
              child: _dangTai
                  ? const CircularProgressIndicator()
                  : Text(
                      _loi ?? 'Không có dữ liệu',
                      style: HD.body(color: HD.inkMuted),
                    ),
            )
          : RefreshIndicator(
              onRefresh: _nap,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(HD.s16, HD.s16, HD.s16, 24),
                children: [
                  _theMa(ca),
                  const SizedBox(height: HD.s12),
                  if (ca.choNhan) ...[
                    _theDemNguoc(ca),
                    const SizedBox(height: HD.s12),
                  ],
                  _thePhong(ca),
                  const SizedBox(height: HD.s12),
                  _theGoiThue(ca),
                  const SizedBox(height: HD.s12),
                  _theKhach(ca),
                  if (ca.xemTaiChinh && ca.tien != null) ...[
                    const SizedBox(height: HD.s12),
                    _theTien(ca),
                  ],
                  if (!ca.daTra) ...[
                    const SizedBox(height: HD.s12),
                    _hangNut(ca),
                  ],
                  // Tới giờ mà khách chưa đến: nhả phòng để bán lại phần còn
                  // lại của khung, thay vì để đơn "đã duyệt" treo mãi.
                  if (ca.trangThai == 'approved' && !ca.bayGio.isBefore(ca.vao))
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const Key('ca-thue-khong-den'),
                        onPressed: _dangLam ? null : () => _khongDen(ca),
                        icon: const Icon(Icons.person_off_outlined, size: 18),
                        label: const Text('Khách không đến · nhả phòng'),
                        style: TextButton.styleFrom(foregroundColor: HD.negative),
                      ),
                    ),
                ],
              ),
            ),
      bottomNavigationBar: ca == null ? null : _thanhDuoi(ca),
    );
  }

  // ── Mã đặt ────────────────────────────────────────────────────────────────

  Widget _theMa(CaThue ca) => Container(
    padding: const EdgeInsets.all(HD.s16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [HD.accent, HD.accentDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mã xác nhận lượt thuê',
                style: HD.body(size: 11.5, color: Colors.white70),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                ChipTrangThai.mo(ca).$1,
                style: HD.bodyBold(size: 11, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                ca.maDat.isEmpty ? '#${ca.id}' : '#${ca.maDat}',
                style: HD.bodyBold(size: 24, color: Colors.white),
              ),
            ),
            IconButton(
              key: const Key('ca-thue-chep-ma'),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: ca.maDat.isEmpty ? '${ca.id}' : ca.maDat),
                );
                _bao('Đã chép mã đặt phòng.');
              },
              icon: const Icon(Icons.content_copy, size: 18, color: Colors.white),
            ),
          ],
        ),
        Text(
          [
            ca.nhanKieu,
            if (ca.saleTen != null)
              'qua sale ${ca.saleTen}'
            else
              ca.nguon == 'marketplace' ? 'Đặt online' : 'Khách tại quầy',
          ].join(' · '),
          key: const Key('ca-thue-nguon'),
          style: HD.body(size: 12, color: Colors.white70),
        ),
      ],
    ),
  );

  // ── Đếm ngược ─────────────────────────────────────────────────────────────

  Widget _theDemNguoc(CaThue ca) {
    final con = ca.tienDo.conToiGioVao;
    final tre = con == 0 && ca.bayGio.isAfter(ca.vao);
    final mau = tre ? HD.negative : (con <= 60 ? HD.accent : HD.positive);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: mau.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: mau.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.hourglass_top, color: mau, size: 21),
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đếm ngược nhận phòng',
                  style: HD.body(size: 11.5, color: HD.inkMuted),
                ),
                Text(
                  tre
                      ? 'Khách trễ ${doDai(ca.bayGio.difference(ca.vao).inMinutes)}'
                      : (con == 0
                            ? 'Đã tới giờ nhận phòng'
                            : 'Còn ${doDai(con)} nữa khách đến'),
                  key: const Key('ca-thue-dem-nguoc'),
                  style: HD.bodyBold(size: 15, color: mau),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(gioPhut(ca.vao), style: HD.bodyBold(size: 17, color: HD.ink)),
              Text(
                ngayTuongDoi(ca.vao, ca.bayGio),
                style: HD.body(size: 11, color: HD.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Phòng ─────────────────────────────────────────────────────────────────

  Widget _thePhong(CaThue ca) => TheCa(
    tieuDe: ca.toaTen.isEmpty ? 'PHÒNG' : ca.toaTen.toUpperCase(),
    phai: ca.phong.tang == null
        ? null
        : Text(
            'Tầng ${ca.phong.tang}',
            style: HD.body(size: 11, color: HD.inkMuted),
          ),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: HD.accentTint,
            borderRadius: BorderRadius.circular(HD.r12),
          ),
          child: const Icon(Icons.meeting_room, color: HD.accent, size: 22),
        ),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phòng ${ca.phong.ma}',
                style: HD.bodyBold(size: 17, color: HD.ink),
              ),
              Text(
                [
                  if (ca.phong.hang != null) ca.phong.hang!,
                  if (ca.phong.giuong != null) ca.phong.giuong!,
                  if (ca.phong.sucChua != null) '${ca.phong.sucChua} khách',
                ].join(' • '),
                style: HD.body(size: 12, color: HD.inkMuted),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Gói thuê ──────────────────────────────────────────────────────────────

  Widget _theGoiThue(CaThue ca) {
    final tong = ca.ra.difference(ca.vao);
    final moTa = ca.kieu == 'theo_gio'
        ? 'Gói thuê theo giờ (${tong.inHours} tiếng)'
        : (ca.kieu == 'qua_dem'
              ? 'Gói qua đêm (trả phòng 12:00)'
              : 'Gói theo ngày (${(tong.inHours / 24).ceil()} ngày)');
    return TheCa(
      tieuDe: 'GÓI THUÊ',
      cham: HD.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: HD.warning),
              const SizedBox(width: 6),
              Expanded(
                child: Text(moTa, style: HD.bodyBold(size: 13.5, color: HD.ink)),
              ),
            ],
          ),
          const SizedBox(height: HD.s12),
          Row(
            children: [
              Expanded(
                child: ONhanh(
                  nhan: 'Giờ nhận',
                  so: gioPhut(ca.vao),
                  phu: ngayVN(ca.vao),
                  icon: Icons.login,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: HD.s8),
                child: Column(
                  children: [
                    Text(
                      doDaiNgan(tong.inMinutes),
                      style: HD.bodyBold(size: 11, color: HD.accent),
                    ),
                    const Icon(Icons.arrow_forward, size: 16, color: HD.accent),
                  ],
                ),
              ),
              Expanded(
                child: ONhanh(
                  nhan: 'Giờ trả',
                  so: gioPhut(ca.ra),
                  phu: ngayVN(ca.ra),
                  icon: Icons.logout,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Khách ─────────────────────────────────────────────────────────────────

  Widget _theKhach(CaThue ca) {
    final ten = ca.khachTen ?? (ca.xemTaiChinh ? 'Khách lẻ' : 'Khách');
    final sdt = ca.khachSdt;
    return TheCa(
      tieuDe: 'THÔNG TIN KHÁCH HÀNG',
      cham: HD.pinBusiness,
      phai: ca.phong.sucChua == null
          ? null
          : Text(
              '${ca.phong.sucChua} người',
              style: HD.body(size: 11, color: HD.inkMuted),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: HD.pinBusiness.withValues(alpha: 0.12),
                child: Text(
                  ten.trim().isEmpty ? '?' : ten.trim()[0].toUpperCase(),
                  style: HD.bodyBold(size: 16, color: HD.pinBusiness),
                ),
              ),
              const SizedBox(width: HD.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ten, style: HD.bodyBold(size: 15, color: HD.ink)),
                    Text(
                      sdt ?? 'Chưa có số điện thoại',
                      style: HD.body(size: 12.5, color: HD.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (sdt != null) ...[
            const SizedBox(height: HD.s12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('ca-thue-goi'),
                    onPressed: () => _goi(sdt),
                    icon: const Icon(Icons.call, size: 16),
                    label: const Text('Gọi điện'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HD.positive,
                      side: BorderSide(
                        color: HD.positive.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(HD.r12),
                      ),
                      textStyle: HD.bodyBold(size: 12.5),
                    ),
                  ),
                ),
                const SizedBox(width: HD.s8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('ca-thue-nhan-tin'),
                    onPressed: () => _nhanTin(sdt),
                    icon: const Icon(Icons.sms_outlined, size: 16),
                    label: const Text('Nhắn tin'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HD.pinBusiness,
                      side: BorderSide(
                        color: HD.pinBusiness.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(HD.r12),
                      ),
                      textStyle: HD.bodyBold(size: 12.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Tiền ──────────────────────────────────────────────────────────────────

  Widget _theTien(CaThue ca) {
    final t = ca.tien!;
    return TheCa(
      tieuDe: 'CHI PHÍ & TIỀN CỌC',
      cham: HD.positive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HangTien('Tiền phòng (${ca.nhanKieu.toLowerCase()})', tien(t.tienPhong)),
          for (final p in ca.phuThu)
            HangTien(
              p.ten,
              '+${tien(p.thanhTien)}',
              phu: p.soLuong == 1
                  ? null
                  : '${tien(p.donGia)} × ${p.soLuong.toStringAsFixed(0)}',
            ),
          const Divider(height: 18, color: HD.hairline),
          HangTien('Tổng giá trị đơn đặt', tien(t.phaiThu), dam: true),
          if (t.coc > 0)
            HangTien(
              'Cọc giữ phòng',
              '-${tien(t.coc)}',
              mau: HD.positive,
              icon: Icons.account_balance_wallet_outlined,
            ),
          for (final x in ca.thanhToan)
            HangTien(
              x.ghiChu ?? (x.laHoan ? 'Hoàn khách' : 'Đã thu'),
              '${x.laHoan ? '+' : '-'}${tien(x.soTien)}',
              phu: [
                x.hinhThuc == 'tien_mat' ? 'Tiền mặt' : 'Chuyển khoản',
                if (x.luc != null) gioPhut(x.luc!),
              ].join(' · '),
              mau: x.laHoan ? HD.warning : HD.positive,
            ),
          const SizedBox(height: HD.s8),
          Container(
            padding: const EdgeInsets.all(HD.s12),
            decoration: BoxDecoration(
              color: t.conLai > 0 ? HD.accentTint : HD.positiveTint,
              borderRadius: BorderRadius.circular(HD.r12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.conLai > 0
                        ? 'Còn lại cần thu'
                        : (t.conLai < 0 ? 'Phải hoàn lại khách' : 'Đã thu đủ'),
                    style: HD.bodyBold(size: 13, color: HD.ink),
                  ),
                ),
                Text(
                  tien(t.conLai),
                  key: const Key('ca-thue-con-lai'),
                  style: HD.bodyBold(
                    size: 18,
                    color: t.conLai > 0 ? HD.accent : HD.positive,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hành động ─────────────────────────────────────────────────────────────

  Widget _hangNut(CaThue ca) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          key: const Key('ca-thue-gia-han'),
          // Gia hạn cộng tiền vào ca → chỉ người cầm tiền (chủ phòng) bấm.
          onPressed: _dangLam || !ca.xemTaiChinh ? null : () => _giaHan(ca),
          icon: const Icon(Icons.more_time, size: 16),
          label: const Text('Gia hạn giờ'),
          style: OutlinedButton.styleFrom(
            foregroundColor: HD.warning,
            side: BorderSide(color: HD.warning.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HD.r12),
            ),
            textStyle: HD.bodyBold(size: 12.5),
          ),
        ),
      ),
      const SizedBox(width: HD.s8),
      Expanded(
        child: OutlinedButton.icon(
          key: const Key('ca-thue-huy'),
          onPressed: _dangLam || ca.dangO ? null : () => _huy(ca),
          icon: const Icon(Icons.cancel_outlined, size: 16),
          label: const Text('Huỷ đặt'),
          style: OutlinedButton.styleFrom(
            foregroundColor: HD.negative,
            side: BorderSide(color: HD.negative.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HD.r12),
            ),
            textStyle: HD.bodyBold(size: 12.5),
          ),
        ),
      ),
    ],
  );

  Future<void> _khongDen(CaThue ca) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đánh dấu khách không đến?'),
        content: const Text(
          'Phòng được nhả ngay để nhận khách khác. Khách và sale sẽ nhận '
          'thông báo. Không hoàn tác được.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Thôi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Khách không đến'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _dangLam = true);
    try {
      await widget.shortStayApi.action(ca.id, 'no_show', null);
      _bao('Đã đánh dấu không đến ${ca.maDat}.');
      await _nap();
    } catch (e) {
      _bao(e is ApiException ? e.message : 'Không thực hiện được');
    } finally {
      if (mounted) setState(() => _dangLam = false);
    }
  }

  Future<void> _quyet(CaThue ca, {required bool duyet}) async {
    String? lyDo;
    if (!duyet) {
      lyDo = await hoiLyDoTuChoi(context);
      if (lyDo == null || !mounted) return;
    }
    setState(() => _dangLam = true);
    try {
      await widget.shortStayApi.action(ca.id, duyet ? 'approve' : 'reject', lyDo);
      _bao(duyet ? 'Đã duyệt đơn ${ca.maDat}.' : 'Đã từ chối đơn ${ca.maDat}.');
      await _nap();
    } catch (e) {
      _bao(e is ApiException ? e.message : 'Không thực hiện được');
    } finally {
      if (mounted) setState(() => _dangLam = false);
    }
  }

  /// Người KHÔNG cầm tiền (sale phụ trách) nhận/trả phòng bằng một nút xác
  /// nhận: màn Nhận phòng/Trả phòng của quầy có thu tiền nên sẽ 403. Server
  /// vẫn tự khoá dọn phòng sau khi trả, như ở quầy.
  Future<void> _xacNhan(CaThue ca, {required bool traPhong}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(traPhong ? 'Xác nhận trả phòng?' : 'Xác nhận khách đã nhận phòng?'),
        content: Text(
          traPhong
              ? 'Tiền phòng và phụ thu do chủ phòng quyết toán tại quầy.'
              : 'Chỉ nhận phòng được trong khung giờ đã đặt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Thôi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _dangLam = true);
    try {
      await widget.shortStayApi.action(
        ca.id,
        traPhong ? 'check_out' : 'check_in',
        null,
      );
      _bao(traPhong ? 'Đã trả phòng ${ca.maDat}.' : 'Khách đã nhận phòng ${ca.maDat}.');
      await _nap();
    } catch (e) {
      _bao(e is ApiException ? e.message : 'Không thực hiện được');
    } finally {
      if (mounted) setState(() => _dangLam = false);
    }
  }

  Widget _thanhDuoiKhongTien(CaThue ca, {required bool dangO}) => SafeArea(
    minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
    child: SizedBox(
      height: 50,
      child: FilledButton.icon(
        key: const Key('ca-thue-xac-nhan-sale'),
        onPressed: _dangLam ? null : () => _xacNhan(ca, traPhong: dangO),
        icon: Icon(dangO ? Icons.logout : Icons.login, size: 19),
        label: Text(
          dangO ? 'Xác nhận trả phòng' : 'Xác nhận khách đã nhận phòng',
          style: HD.bodyBold(size: 14.5, color: Colors.white),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: dangO ? HD.positive : HD.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HD.r12),
          ),
        ),
      ),
    ),
  );

  Widget _thanhDuoi(CaThue ca) {
    if (ca.daTra ||
        ca.trangThai == 'cancelled' ||
        ca.trangThai == 'rejected') {
      return const SizedBox.shrink();
    }
    // ĐƠN CHỜ DUYỆT: việc đầu tiên là quyết nhận hay không, chưa phải check-in.
    if (ca.trangThai == 'pending') {
      return SafeArea(
        minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  key: const Key('ca-thue-tu-choi'),
                  onPressed: _dangLam ? null : () => _quyet(ca, duyet: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HD.negative,
                    side: BorderSide(color: HD.negative.withValues(alpha: 0.45)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(HD.r12),
                    ),
                    textStyle: HD.bodyBold(size: 14),
                  ),
                  child: const Text('Từ chối'),
                ),
              ),
            ),
            const SizedBox(width: HD.s8),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 50,
                child: FilledButton.icon(
                  key: const Key('ca-thue-duyet'),
                  onPressed: _dangLam ? null : () => _quyet(ca, duyet: true),
                  icon: const Icon(Icons.check_circle_outline, size: 19),
                  label: Text(
                    'Duyệt đơn',
                    style: HD.bodyBold(size: 14.5, color: Colors.white),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: HD.positive,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(HD.r12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final dangO = ca.dangO;
    if (!ca.xemTaiChinh) return _thanhDuoiKhongTien(ca, dangO: dangO);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
      child: SizedBox(
        height: 50,
        child: FilledButton.icon(
          key: const Key('ca-thue-buoc-ke'),
          onPressed: _dangLam
              ? null
              : () => dangO ? _sangDangO(ca) : _sangNhanPhong(ca),
          icon: Icon(dangO ? Icons.hotel : Icons.login, size: 19),
          label: Text(
            dangO ? 'Quản lý khách đang ở' : 'Tiến hành Check-in ngay',
            style: HD.bodyBold(size: 14.5, color: Colors.white),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: dangO ? HD.positive : HD.accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HD.r12),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hỏi gia hạn thêm bao lâu — các mốc quen tay của quầy, có ô tự nhập.
Future<int?> _hoiSoPhut(BuildContext context) => showModalBottomSheet<int>(
  context: context,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (ctx) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(HD.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Gia hạn thêm', style: HD.bodyBold(size: 16)),
          const SizedBox(height: 4),
          Text(
            'Giờ trả mới luôn được làm tròn lên giờ chẵn — khách dư thời gian, '
            'không bao giờ thiếu.',
            style: HD.body(size: 12, color: HD.inkMuted),
          ),
          const SizedBox(height: HD.s16),
          for (final p in const [30, 60, 120, 180])
            ListTile(
              key: Key('gia-han-$p'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.more_time, color: HD.warning, size: 20),
              title: Text(doDai(p), style: HD.bodyBold(size: 14)),
              onTap: () => Navigator.of(ctx).pop(p),
            ),
        ],
      ),
    ),
  ),
);

Future<String?> _hoiLyDo(BuildContext context) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Huỷ đặt phòng', style: HD.bodyBold(size: 16)),
      content: TextField(
        key: const Key('ca-thue-ly-do-huy'),
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Lý do huỷ',
          hintText: 'Khách báo bận, đổi lịch…',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Đóng'),
        ),
        FilledButton(
          key: const Key('ca-thue-xac-nhan-huy'),
          onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: HD.negative),
          child: const Text('Huỷ đặt'),
        ),
      ],
    ),
  );
}
