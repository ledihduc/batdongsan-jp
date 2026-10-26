import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/dich_vu_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/dien_nuoc_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/hop_dong_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/lich_su_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/sua_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/tao_hoa_don_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/tai_khoan_nhan_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/thu_chi_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/thu_tien_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';

/// Màn 4 — THÔNG TIN PHÒNG (Tổng quan).
///
/// Ảnh lớn (quay lại · "Sửa" · 1/5) → tên phòng + nhãn → "Tầng · m² · loại" →
/// giá + "Thu tiền 05/10" → lối tắt Hợp đồng · Điện nước · Thu chi · Dịch vụ ·
/// Lịch sử → người thuê (+ Đại diện sale) → hợp đồng (Còn N tháng, Cọc đã thu)
/// → "Dịch vụ đang áp dụng" → đáy: Thu tiền / Tạo hóa đơn.
/// API: `GET /api/host/so-chu-nha/phong/{id}`.
class ThongTinPhongScreen extends StatefulWidget {
  const ThongTinPhongScreen({super.key, required this.roomId, this.api = const SoChuNhaApi()});

  final int roomId;
  final SoChuNhaApi api;

  @override
  State<ThongTinPhongScreen> createState() => _ThongTinPhongScreenState();
}

class _ThongTinPhongScreenState extends State<ThongTinPhongScreen> {
  int _lan = 0;
  int _anh = 0;

  Future<void> _day(Widget man) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));
    if (mounted) setState(() => _lan++);
  }

  @override
  Widget build(BuildContext context) {
    return TaiCN<PhongCN>(
      khoaTai: _lan,
      tai: () => widget.api.phong(widget.roomId),
      dung: (context, p, taiLai) => Scaffold(
        backgroundColor: MauCN.nen,
        body: RefreshIndicator(
          color: HD.accent,
          onRefresh: taiLai,
          child: ListView(
            key: const Key('cn-thong-tin-phong'),
            padding: EdgeInsets.zero,
            children: [
              _anhLon(p),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _dau(p),
                    const SizedBox(height: 16),
                    _loiTat(p),
                    const SizedBox(height: 12),
                    // Khách chuyển khoản / quét VietQR vào tài khoản này.
                    TheCN(
                      key: const Key('cn-tai-khoan-phong'),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      onTap: () => _day(TaiKhoanNhanScreen.phong(roomId: p.id, api: widget.api)),
                      child: Row(
                        children: [
                          const OIconCN(Icons.account_balance_outlined, mau: MauCN.xanh, nen: MauCN.xanhNen, co: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Tài khoản nhận tiền', style: HD.bodyBold(size: 15, color: HD.ink)),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: HD.inkMuted),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (p.khach != null) ...[_nguoiThue(p), const SizedBox(height: 12)],
                    if (p.coHopDong) ...[_hopDong(p), const SizedBox(height: 12)],
                    _dichVu(p),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: MauCN.the,
              border: Border(top: BorderSide(color: MauCN.vien)),
            ),
            child: p.coHopDong
                ? HaiNutCN(
                    trai: NutCN(
                      'Thu tiền',
                      key: const Key('cn-nut-thu-tien'),
                      kieu: KieuNutCN.vien,
                      icon: Icons.payments_outlined,
                      onPressed: () => _day(ThuTienScreen(roomId: p.id, api: widget.api)),
                    ),
                    phai: NutCN(
                      'Tạo hóa đơn',
                      key: const Key('cn-nut-tao-hoa-don'),
                      icon: Icons.receipt_long_outlined,
                      onPressed: () => _day(TaoHoaDonScreen(roomId: p.id, api: widget.api)),
                    ),
                  )
                : NutCN(
                    'Sửa thông tin phòng',
                    key: const Key('cn-nut-sua-phong'),
                    kieu: KieuNutCN.vien,
                    icon: Icons.edit_outlined,
                    onPressed: () => _day(SuaPhongScreen(toaId: p.toaId, roomId: p.id, api: widget.api)),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _anhLon(PhongCN p) {
    final top = MediaQuery.of(context).padding.top;
    final tong = p.anh.length;
    Widget nutTron(Widget child, {Key? key, VoidCallback? onTap}) => Material(
      color: HD.paperRaised.withValues(alpha: 0.92),
      shape: const StadiumBorder(),
      child: InkWell(key: key, customBorder: const StadiumBorder(), onTap: onTap, child: child),
    );
    return SizedBox(
      height: 270 + top,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (tong == 0)
            const AnhCN(url: null, rong: double.infinity, cao: 270, bo: 0)
          else
            PageView.builder(
              itemCount: tong,
              onPageChanged: (i) => setState(() => _anh = i),
              itemBuilder: (_, i) => AnhCN(url: p.anh[i], rong: double.infinity, cao: 270 + top, bo: 0),
            ),
          Positioned(
            top: top + 10,
            left: 12,
            child: nutTron(
              const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: HD.ink),
              ),
              key: const Key('cn-lui'),
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            top: top + 10,
            right: 12,
            child: nutTron(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_outlined, size: 16, color: HD.ink),
                    const SizedBox(width: 5),
                    Text('Sửa', style: HD.bodyBold(size: 14, color: HD.ink)),
                  ],
                ),
              ),
              key: const Key('cn-sua-phong'),
              onTap: () => _day(SuaPhongScreen(toaId: p.toaId, roomId: p.id, api: widget.api)),
            ),
          ),
          if (tong > 0)
            Positioned(
              right: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: HD.ink.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_anh + 1}/$tong',
                  style: HD.bodyBold(size: 12.5, color: HD.paperRaised),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dau(PhongCN p) {
    final phu = [
      if (p.tang.isNotEmpty && p.tang != 'Khác') 'Tầng ${p.tang}',
      if (p.dienTich != null) '${soCN(p.dienTich)} m²',
      nhanLoaiThue(p.loaiThue),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(p.ten, style: HD.bodyBold(size: 23, color: HD.ink))),
            NhanCN.trangThai(p.trangThai),
          ],
        ),
        const SizedBox(height: 4),
        Text(phu, style: HD.body(size: 14, color: HD.inkMuted)),
        if (p.tenToa.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(p.tenToa, style: HD.body(size: 13, color: HD.inkMuted)),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(giaCN(p.gia, p.donVi), style: HD.bodyBold(size: 19, color: HD.accent)),
            ),
            if (p.thuTienNgay != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: MauCN.camNen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_outlined, size: 15, color: MauCN.cam),
                    const SizedBox(width: 4),
                    Text(
                      'Thu tiền ${ngayNganCN(p.thuTienNgay)}',
                      style: HD.bodyBold(size: 12.5, color: MauCN.cam),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _loiTat(PhongCN p) {
    final o = <(String, IconData, Color, Widget Function())>[
      ('Hợp đồng', Icons.description_outlined, HD.accent, () => HopDongPhongScreen(roomId: p.id, api: widget.api)),
      ('Điện nước', Icons.bolt_rounded, MauCN.cam, () => DienNuocPhongScreen(roomId: p.id, api: widget.api)),
      ('Thu chi', Icons.account_balance_wallet_outlined, MauCN.xanh, () => ThuChiPhongScreen(roomId: p.id, api: widget.api)),
      ('Dịch vụ', Icons.room_service_outlined, MauCN.tim, () => DichVuPhongScreen(roomId: p.id, api: widget.api)),
      ('Lịch sử', Icons.history_rounded, MauCN.lam, () => LichSuPhongScreen(roomId: p.id, api: widget.api)),
    ];
    return TheCN(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          for (final x in o)
            Expanded(
              child: InkWell(
                key: Key('cn-loi-tat-${x.$1}'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => _day(x.$4()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      OIconCN(x.$2, mau: x.$3, nen: x.$3.withValues(alpha: 0.12), co: 40),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(x.$1, style: HD.body(size: 12.5, color: HD.inkSoft)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _nguoiThue(PhongCN p) {
    final k = p.khach!;
    final chu = k.ten.trim().isEmpty ? '?' : k.ten.trim().split(' ').last.characters.first.toUpperCase();
    return TheCN(
      key: const Key('cn-nguoi-thue'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Người thuê', style: HD.bodyBold(size: 15.5, color: HD.ink)),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: HD.accentTint,
                child: Text(chu, style: HD.bodyBold(size: 18, color: HD.accent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k.ten, style: HD.bodyBold(size: 15, color: HD.ink)),
                    if (k.sdt != null) ...[
                      const SizedBox(height: 2),
                      Text(k.sdt!, style: HD.body(size: 13.5, color: HD.inkMuted)),
                    ],
                  ],
                ),
              ),
              if (k.sdt != null)
                Material(
                  color: MauCN.xanhNen,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const Key('cn-goi-khach'),
                    customBorder: const CircleBorder(),
                    onTap: () => launchUrl(Uri(scheme: 'tel', path: k.sdt)),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.call_outlined, color: MauCN.xanh, size: 20),
                    ),
                  ),
                ),
            ],
          ),
          if (p.daiDien != null) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: MauCN.vien),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.support_agent_outlined, size: 18, color: HD.inkMuted),
                const SizedBox(width: 6),
                Text('Đại diện: ', style: HD.body(size: 13.5, color: HD.inkMuted)),
                Expanded(
                  child: Text(
                    '${p.daiDien!.ten} (${p.daiDien!.vai ?? 'Sale'})',
                    style: HD.bodyBold(size: 13.5, color: HD.ink),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _hopDong(PhongCN p) {
    return TheCN(
      key: const Key('cn-the-hop-dong'),
      onTap: () => _day(HopDongPhongScreen(roomId: p.id, api: widget.api)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Hợp đồng', style: HD.bodyBold(size: 15.5, color: HD.ink))),
              if (p.conThang != null)
                NhanCN('Còn ${p.conThang} tháng', mau: MauCN.xanh, nen: MauCN.xanhNen),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _moc('Bắt đầu', ngayCN(p.hdBatDau))),
              Container(width: 1, height: 34, color: MauCN.vien),
              const SizedBox(width: 14),
              Expanded(child: _moc('Kết thúc', ngayCN(p.hdKetThuc))),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: MauCN.vien),
          DongCN(
            'Cọc đã thu',
            p.cocDaThu == null ? 'Chưa ghi nhận' : tienCN(p.cocDaThu!),
            dam: true,
            dem: 8,
          ),
        ],
      ),
    );
  }

  Widget _moc(String nhan, String gia) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(nhan, style: HD.body(size: 12.5, color: HD.inkMuted)),
      const SizedBox(height: 3),
      Text(gia, style: HD.bodyBold(size: 14.5, color: HD.ink)),
    ],
  );

  Widget _dichVu(PhongCN p) {
    final ds = p.dichVu.take(4).toList();
    return TheCN(
      key: const Key('cn-dich-vu-ap-dung'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TieuDeKhoiCN(
            'Dịch vụ đang áp dụng',
            phai: 'Xem tất cả',
            onPhai: () => _day(DichVuPhongScreen(roomId: p.id, api: widget.api)),
          ),
          for (var i = 0; i < ds.length; i++) ...[
            if (i > 0) Divider(height: 1, color: MauCN.vien),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Builder(
                    builder: (_) {
                      final (icon, mau) = bieuTuongDichVu(ds[i].ma, ds[i].ten);
                      return OIconCN(icon, mau: mau, nen: mau.withValues(alpha: 0.12), co: 34);
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(ds[i].ten, style: HD.body(size: 14.5, color: HD.ink))),
                  Text(
                    '${tienCN(ds[i].gia)}/${ds[i].donVi}',
                    style: HD.bodyBold(size: 14, color: HD.ink),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
