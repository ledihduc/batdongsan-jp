import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/sale_yeu_cau_api.dart';
import 'package:house_booking/features/sale/chon_can_sheet.dart';
import 'package:house_booking/features/sale/chi_tiet_yeu_cau_khach_screen.dart';
import 'package:house_booking/features/sale/gui_ho_so_chot_thue_screen.dart';
import 'package:house_booking/features/sale/widgets/sale_chung.dart';
import 'package:house_booking/features/shared/pipeline_thue.dart';

/// MÀN 3 — "Chi tiết yêu cầu" (mockup VuaNhà 23/09/2026).
///
/// Ba khối: khách + nhu cầu, căn đã gắn, và PIPELINE 7 bước có mốc thời gian.
/// Tiến trình đọc từ bảng mốc chứ không từ `updated_at`: đổi trạng thái lần
/// hai là mất dấu lần đầu, mà "gửi căn lúc nào" mới là thứ sale cần nhìn.
///
/// API: GET/POST /api/sale/yeu-cau/{id}[/chuyen-buoc]
class YeuCauChiTietScreen extends StatefulWidget {
  const YeuCauChiTietScreen({
    super.key,
    required this.yeuCauId,
    this.api = const SaleYeuCauApi(),
    this.moLink,
  });

  final int yeuCauId;
  final SaleYeuCauApi api;

  /// Chỉ để test: chặn mở trình quay số thật.
  final Future<void> Function(Uri)? moLink;

  @override
  State<YeuCauChiTietScreen> createState() => _YeuCauChiTietScreenState();
}

class _YeuCauChiTietScreenState extends State<YeuCauChiTietScreen> {
  YeuCauChiTiet? _yc;
  bool _dangTai = true;
  bool _dangGui = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    try {
      final yc = await widget.api.chiTiet(widget.yeuCauId);
      if (!mounted) return;
      setState(() {
        _yc = yc;
        _dangTai = false;
        _loi = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = e is ApiException ? e.message : 'Chưa tải được yêu cầu';
      });
    }
  }

  Future<void> _chuyen() async {
    final yc = _yc;
    final ke = yc?.buocKe;
    if (yc == null || ke == null || _dangGui) return;
    setState(() => _dangGui = true);
    try {
      final moi = await widget.api.chuyenBuoc(yc.id, ke);
      if (!mounted) return;
      setState(() {
        _yc = moi;
        _dangGui = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã chuyển sang "${moi.nhan}"')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _dangGui = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Chưa chuyển được'),
        ),
      );
    }
  }

  Future<void> _themCan() async {
    final yc = _yc;
    if (yc == null) return;
    final coGan = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChonCanSheet(yeuCauId: yc.id, api: widget.api),
    );
    if (coGan == true && mounted) await _nap();
  }

  Future<void> _chonCan(CanLienQuan c) async {
    final yc = _yc;
    if (yc == null || _dangGui) return;
    setState(() => _dangGui = true);
    try {
      final moi = await widget.api.chonCan(yc.id, c.id);
      if (!mounted) return;
      setState(() {
        _yc = moi;
        _dangGui = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Khách chốt ${c.ten}')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _dangGui = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Chưa chọn được căn'),
        ),
      );
    }
  }

  Future<void> _goi() async {
    final sdt = _yc?.khach.sdt ?? '';
    if (sdt.isEmpty) return;
    final uri = Uri.parse('tel:$sdt');
    if (widget.moLink != null) {
      await widget.moLink!(uri);
      return;
    }
    await launchUrl(uri);
  }

  Future<void> _huyYeuCau() async {
    final yc = _yc;
    if (yc == null || _dangGui) return;
    final lyDo = TextEditingController();
    final dongY = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hủy yêu cầu?'),
        content: TextField(
          key: const Key('sale-huy-yeu-cau-ly-do'),
          controller: lyDo,
          maxLength: 300,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Lý do hủy *',
            hintText: 'Ví dụ: Khách đổi nhu cầu',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ yêu cầu'),
          ),
          FilledButton(
            key: const Key('sale-xac-nhan-huy-yeu-cau'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: HD.negative),
            child: const Text('Hủy yêu cầu'),
          ),
        ],
      ),
    );
    final noiDung = lyDo.text.trim();
    // AlertDialog còn một nhịp animation sau khi pop. Trì hoãn dispose để
    // TextField không đọc lại controller đã bị hủy trong nhịp đó.
    WidgetsBinding.instance.addPostFrameCallback((_) => lyDo.dispose());
    if (dongY != true || !mounted) return;
    if (noiDung.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nhập lý do hủy yêu cầu.')));
      return;
    }
    setState(() => _dangGui = true);
    try {
      final moi = await widget.api.huyYeuCau(yc.id, noiDung);
      if (!mounted) return;
      setState(() {
        _yc = moi;
        _dangGui = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã hủy yêu cầu.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _dangGui = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Chưa hủy được'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final yc = _yc;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.paperRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: HD.ink),
        title: Text('Chi tiết yêu cầu', style: HD.bodyBold(size: 16)),
      ),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : RefreshIndicator(
              color: HD.accent,
              onRefresh: _nap,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (_loi != null) SaleBaoLoi(loi: _loi!, onThuLai: _nap),
                  if (yc != null) ...[
                    _khach(yc),
                    const SizedBox(height: 16),
                    _nhuCau(yc),
                    const SizedBox(height: 16),
                    _can(yc),
                    const SizedBox(height: 16),
                    Text('Pipeline xử lý', style: HD.sectionTitle()),
                    const SizedBox(height: 10),
                    _pipeline(yc),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: yc == null ? null : _thanhDuoi(yc),
    );
  }

  Widget _khach(YeuCauChiTiet yc) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(HD.r12),
      border: Border.all(color: HD.hairline),
    ),
    child: Row(
      children: [
        SaleAnhKhach(ten: yc.khach.hoTen, kichThuoc: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      yc.khach.hoTen,
                      style: HD.bodyBold(size: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SaleNhan(chu: yc.nhan, mau: saleMauBuoc(yc.trangThai)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${yc.ma}${yc.khach.sdt.isEmpty ? '' : ' · ${yc.khach.sdt}'}',
                style: HD.body(size: 12.5, color: HD.accent),
              ),
              if (!yc.khach.coTaiKhoan)
                Text(
                  'Khách chưa có tài khoản trên app',
                  style: HD.body(size: 11.5, color: HD.inkMuted),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _nhuCau(YeuCauChiTiet yc) {
    final dong = <(IconData, String, String)>[
      if (yc.nganSach.isNotEmpty)
        (Icons.payments_outlined, 'Ngân sách', '${yc.nganSach}/tháng'),
      if (yc.vaoOTu != null)
        (
          Icons.event_outlined,
          'Muốn vào ở',
          'Tháng ${yc.vaoOTu!.month}/${yc.vaoOTu!.year}',
        ),
      if (yc.loaiCan.isNotEmpty)
        (Icons.home_work_outlined, 'Loại căn', yc.loaiCan),
      if (yc.khuVuc.isNotEmpty)
        (Icons.place_outlined, 'Khu vực quan tâm', yc.khuVuc),
    ];
    if (dong.isEmpty && yc.ghiChu.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nhu cầu & thông tin thêm', style: HD.sectionTitle()),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: HD.paperRaised,
            borderRadius: BorderRadius.circular(HD.r12),
            border: Border.all(color: HD.hairline),
          ),
          child: Column(
            children: [
              for (final (icon, nhan, gt) in dong)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 17, color: HD.inkMuted),
                      const SizedBox(width: 8),
                      Text(
                        nhan,
                        style: HD.body(size: 12.5, color: HD.inkMuted),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          gt,
                          textAlign: TextAlign.right,
                          style: HD.bodyBold(size: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              if (yc.ghiChu.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    yc.ghiChu,
                    style: HD.body(size: 12.5, color: HD.inkSoft),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _can(YeuCauChiTiet yc) {
    final dau = Row(
      children: [
        Expanded(child: Text('Căn / toà liên quan', style: HD.sectionTitle())),
        TextButton.icon(
          key: const Key('sale-them-can'),
          onPressed: _themCan,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Thêm căn'),
          style: TextButton.styleFrom(foregroundColor: HD.accent),
        ),
      ],
    );
    if (yc.canLienQuan.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          dau,
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HD.paperSunken,
              borderRadius: BorderRadius.circular(HD.r12),
            ),
            child: Text(
              'Chưa gắn căn nào. Gắn căn từ toà liên kết hoặc bài đăng của '
              'bạn — chốt thuê cần biết khách thuê căn nào để tính hoa hồng.',
              style: HD.body(size: 12.5, color: HD.inkSoft),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        dau,
        const SizedBox(height: 4),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: yc.canLienQuan.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final c = yc.canLienQuan[i];
              return Container(
                width: 160,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: HD.paperRaised,
                  borderRadius: BorderRadius.circular(HD.r12),
                  border: Border.all(
                    color: c.khachThich ? HD.accent : HD.hairline,
                    width: c.khachThich ? 1.6 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        c.ten,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: HD.bodyBold(size: 13),
                      ),
                    ),
                    if (c.diaChi.isNotEmpty)
                      Text(
                        c.diaChi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HD.body(size: 11.5, color: HD.inkMuted),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      saleTien(c.gia, hau: '/tháng'),
                      style: HD.bodyBold(size: 13.5, color: HD.accent),
                    ),
                    // Căn khách chốt quyết định giá thuê của đơn — và do đó
                    // hoa hồng. Phải là một lựa chọn dứt khoát, không phải
                    // cái nhãn trang trí.
                    if (c.khachThich)
                      Text(
                        'Khách chốt căn này',
                        style: HD.bodyBold(size: 11.5, color: HD.positive),
                      )
                    else
                      SizedBox(
                        height: 28,
                        child: TextButton(
                          key: Key('sale-chon-can-${c.id}'),
                          onPressed: yc.daChot ? null : () => _chonCan(c),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: HD.accent,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text(
                            'Khách chọn căn này',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _pipeline(YeuCauChiTiet yc) => PipelineThue(buoc: yc.pipeline);

  Future<void> _moHoSo(int journeyId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuiHoSoChotThueScreen(journeyId: journeyId),
      ),
    );
    if (mounted) _nap();
  }

  Future<void> _moLich(int appointmentId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChiTietYeuCauKhachScreen(appointmentId: appointmentId),
      ),
    );
    if (mounted) _nap();
  }

  Widget _thanhDuoi(YeuCauChiTiet yc) {
    if (yc.dongLyDo != null) {
      return SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          key: const Key('sale-yeu-cau-da-huy'),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: HD.negative.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(HD.r12),
          ),
          child: Text(
            'Đã hủy · ${yc.dongLyDo}',
            textAlign: TextAlign.center,
            style: HD.bodyBold(size: 13, color: HD.negative),
          ),
        ),
      );
    }
    final ke = yc.buocKe;
    final nhanKe = ke == null
        ? null
        : yc.pipeline.firstWhere((b) => b.buoc == ke).nhan;
    // Chốt mà chưa chỉ rõ khách thuê căn nào thì server trả 409 (giá 0 →
    // không sinh hoa hồng). Nói trước ở nút, đừng để bấm rồi mới báo.
    final thieuCanChot =
        ke == 'da_chot' && !yc.canLienQuan.any((c) => c.khachThich);
    final lich = yc.appointmentId;
    // Lịch khách tự đặt còn chờ: việc tiếp theo là XÁC NHẬN LỊCH, không phải
    // tự bấm sang "Đã liên hệ" — bước sẽ tự nhảy khi lịch được xác nhận.
    // Khách đã báo muốn thuê: khách chỉ chuyển cọc được SAU khi sale gửi
    // hợp đồng + số cọc — thiếu nút này thì cả hai bên cùng đứng chờ.
    final canGuiHoSo =
        yc.journeyId != null &&
        (yc.trangThai == 'muon_thue' || yc.trangThai == 'cho_coc');
    final choXacNhanLich =
        lich != null &&
        (yc.trangThai == 'lead_moi' || yc.trangThai == 'da_lien_he');
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (yc.khach.sdt.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('sale-goi-khach'),
                    onPressed: _goi,
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Gọi khách'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HD.accent,
                      side: const BorderSide(color: HD.accent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (lich != null && !choXacNhanLich) ...[
                if (yc.khach.sdt.isNotEmpty) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('sale-mo-lich-xem'),
                    onPressed: () => _moLich(lich),
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: const Text('Lịch xem'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HD.accent,
                      side: const BorderSide(color: HD.accent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (canGuiHoSo) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                key: const Key('sale-gui-ho-so-chot'),
                onPressed: () => _moHoSo(yc.journeyId!),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HD.accent,
                  side: const BorderSide(color: HD.accent),
                ),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Hợp đồng & ảnh cọc'),
              ),
            ),
          ],
          if (choXacNhanLich) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                key: const Key('sale-xac-nhan-lich'),
                onPressed: () => _moLich(lich),
                style: FilledButton.styleFrom(backgroundColor: HD.accent),
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Xem & xác nhận lịch xem'),
              ),
            ),
          ] else if (ke != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                key: const Key('sale-chuyen-trang-thai'),
                onPressed: _dangGui || thieuCanChot ? null : _chuyen,
                style: FilledButton.styleFrom(
                  backgroundColor: HD.accent,
                  disabledBackgroundColor: HD.accent.withValues(alpha: .35),
                ),
                icon: Icon(
                  thieuCanChot ? Icons.info_outline : Icons.arrow_forward,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  thieuCanChot
                      ? 'Chọn căn khách thuê trước'
                      : 'Chuyển sang: $nhanKe',
                  style: HD.bodyBold(size: 14.5, color: Colors.white),
                ),
              ),
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HD.positiveTint,
                borderRadius: BorderRadius.circular(HD.r12),
              ),
              child: Text(
                'Đã chốt — hoa hồng được ghi nhận cho yêu cầu này.',
                textAlign: TextAlign.center,
                style: HD.bodyBold(size: 13, color: HD.positive),
              ),
            ),
          const SizedBox(height: 4),
          TextButton.icon(
            key: const Key('sale-huy-yeu-cau'),
            onPressed: _dangGui ? null : _huyYeuCau,
            style: TextButton.styleFrom(foregroundColor: HD.negative),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('Hủy yêu cầu'),
          ),
        ],
      ),
    );
  }
}
