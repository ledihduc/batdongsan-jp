import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/dien_nuoc_api.dart';
import 'package:house_booking/features/guest/thue_o/ho_so_thue.dart';
import 'package:house_booking/features/guest/thue_o/khach_gui_anh_dien_nuoc_screen.dart';
import 'package:house_booking/features/guest/thue_o/widgets/thue_o_ui.dart';

/// Màn 6 — Điện nước (mockup 04/10/2026): tab Chưa gửi ảnh | Đã gửi. Kỳ tháng
/// này chưa có ảnh (hoặc chủ nhà bắt chụp lại) nằm ở "Chưa gửi ảnh" với nút
/// "Gửi ảnh"; các kỳ đã có chỉ số nằm ở "Đã gửi".
class KhachDienNuocScreen extends StatefulWidget {
  const KhachDienNuocScreen({
    super.key,
    required this.hoSo,
    this.api = const DienNuocApi(),
  });

  final HoSoThue hoSo;
  final DienNuocApi api;

  @override
  State<KhachDienNuocScreen> createState() => _KhachDienNuocScreenState();
}

/// Trạng thái kỳ tháng này còn cần người thuê chụp/gửi.
const _canGui = {'chua_gui', 'can_chup_lai', 'thieu_anh'};

class _KhachDienNuocScreenState extends State<KhachDienNuocScreen> {
  bool _chuaGui = true;
  bool _vuaGui = false;

  Future<void> _gui() async {
    final hs = widget.hoSo;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => KhachGuiAnhDienNuocScreen(
          contractId: hs.contractId,
          thang: hs.thangDienNuoc,
          nuocTheoNguoi: hs.nuocTheoNguoi,
          api: widget.api,
        ),
      ),
    );
    if (ok == true && mounted) {
      setState(() {
        _vuaGui = true;
        _chuaGui = false;
      });
    }
  }

  String _kyHienTai() {
    final p = widget.hoSo.thangDienNuoc.split('-');
    return p.length == 2 ? '${p[1]}/${p[0]}' : widget.hoSo.thangDienNuoc;
  }

  @override
  Widget build(BuildContext context) {
    final hs = widget.hoSo;
    final canGuiThangNay =
        !_vuaGui &&
        hs.thangDienNuoc.isNotEmpty &&
        _canGui.contains(hs.trangThaiDienNuoc);
    final daGui = [
      for (final k in hs.lichSuDienNuoc)
        if (!(k.thang == hs.thangDienNuoc && canGuiThangNay)) k,
    ];
    return TrangThueO(
      tieuDe: 'Điện nước',
      body: ListView(
        key: const Key('khach-dien-nuoc'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          HaiTab(
            trai: 'Chưa gửi ảnh',
            phai: 'Đã gửi',
            chonTrai: _chuaGui,
            onChon: (v) => setState(() => _chuaGui = v),
          ),
          const SizedBox(height: 14),
          if (_chuaGui) ...[
            if (canGuiThangNay)
              _TheKy(
                key: const Key('ky-chua-gui'),
                ky: _kyHienTai(),
                nhan: hs.trangThaiDienNuoc == 'can_chup_lai'
                    ? NhanTron.cam('Cần chụp lại')
                    : NhanTron.cam('Chưa gửi ảnh'),
                dong: hs.trangThaiDienNuoc == 'can_chup_lai' &&
                        hs.lyDoTraVeDienNuoc.isNotEmpty
                    ? 'Chủ nhà nhắn: ${hs.lyDoTraVeDienNuoc}'
                    : 'Vui lòng chụp ảnh đồng hồ để gửi chỉ số',
                nut: NutDo('Gửi ảnh', cao: 40, onPressed: _gui),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  // Chủ nhà tự đi ghi thì nói đúng như vậy — khách không gửi
                  // gì mà app báo "bạn đã gửi" là sai sự thật.
                  hs.nguoiGhiDienNuoc == 'chu_nha' && !_vuaGui
                      ? 'Chủ nhà đã ghi chỉ số kỳ này — xem ở tab "Đã gửi".'
                      : 'Bạn đã gửi chỉ số kỳ này. Kỳ sau app sẽ nhắc lại.',
                  key: const Key('khach-dn-ky-nay'),
                  textAlign: TextAlign.center,
                  style: HD.body(color: HD.inkMuted),
                ),
              ),
          ] else ...[
            if (_vuaGui)
              _TheKy(
                ky: _kyHienTai(),
                nhan: NhanTron.xanh('Đã gửi'),
                dong: 'Đã gửi ngày ${ngayVN(DateTime.now())}',
              ),
            if (daGui.isEmpty && !_vuaGui)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  'Chưa có kỳ nào đã gửi.',
                  textAlign: TextAlign.center,
                  style: HD.body(color: HD.inkMuted),
                ),
              ),
            for (final k in daGui)
              _TheKy(
                ky: k.ky,
                nhan: switch (k.trangThai) {
                  'cho_duyet' || 'thieu_anh' => NhanTron.cam('Chờ duyệt'),
                  'can_chup_lai' => NhanTron.cam('Cần chụp lại'),
                  _ when !k.nguoiThueGui => NhanTron.xanh('Chủ nhà ghi'),
                  _ => NhanTron.xanh('Đã gửi'),
                },
                dong: k.nguoiThueGui
                    ? 'Đã gửi ngày ${ngayVN(k.ngayGui)}'
                    : 'Chủ nhà ghi ngày ${ngayVN(k.ngayGui)}',
                anh: k.anh,
              ),
          ],
        ],
      ),
    );
  }
}

class _TheKy extends StatelessWidget {
  const _TheKy({
    super.key,
    required this.ky,
    required this.nhan,
    required this.dong,
    this.nut,
    this.anh = const [],
  });

  final String ky;
  final Widget nhan;
  final String dong;
  final Widget? nut;

  /// Ảnh công tơ của kỳ (khách hoặc chủ nhà chụp).
  final List<String> anh;

  @override
  Widget build(BuildContext context) => KhoiTrang(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const IconTaiLieu(mau: HD.inkSoft),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kỳ tháng $ky',
                      style: HD.bodyBold(size: 14.5, color: HD.ink),
                    ),
                  ),
                  nhan,
                ],
              ),
              const SizedBox(height: 4),
              Text(dong, style: HD.body(size: 12.5, color: HD.inkMuted)),
              if (anh.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final u in anh) ...[
                      _AnhNho(url: u),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
              if (nut != null) ...[const SizedBox(height: 10), nut!],
            ],
          ),
        ),
        if (nut == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(Icons.chevron_right_rounded, color: HD.inkMuted),
          ),
      ],
    ),
  );
}

/// Ảnh công tơ thu nhỏ trong thẻ kỳ — bấm để xem to.
class _AnhNho extends StatelessWidget {
  const _AnhNho({required this.url});

  final String url;

  String get _day => url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InteractiveViewer(child: CachedNetworkImage(imageUrl: _day, fit: BoxFit.contain)),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ],
        ),
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: _day,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => Container(
          width: 48,
          height: 48,
          color: HD.paperSunken,
          child: const Icon(Icons.broken_image_outlined, size: 16),
        ),
      ),
    ),
  );
}
