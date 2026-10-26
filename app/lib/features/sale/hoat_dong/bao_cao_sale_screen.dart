import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

/// Màn 10 — "Báo cáo" (mockup 05/10/2026): chọn kỳ (Tháng này ›), bốn ô số
/// (Bài đăng · Khách mới · Lịch xem · Đã chốt), biểu đồ "Hiệu quả bài đăng"
/// (lượt xem tin + yêu cầu mới từng ngày) và hoa hồng (dài hạn).
/// API: `GET /api/sale/van-hanh/bao-cao?kenh=&ky=`.
class BaoCaoSaleScreen extends StatefulWidget {
  const BaoCaoSaleScreen({
    super.key,
    this.kenh = kKenhDaiHan,
    this.api = const SaleVanHanhApi(),
  });

  final String kenh;
  final SaleVanHanhApi api;

  @override
  State<BaoCaoSaleScreen> createState() => _BaoCaoSaleScreenState();
}

class _BaoCaoSaleScreenState extends State<BaoCaoSaleScreen> {
  String _ky = 'thang_nay';

  Future<void> _chonKy(BaoCaoSale bc) async {
    final chon = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: SaleMau.nen,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final k in bc.cacKy)
              ListTile(
                key: Key('ky-${k.khoa}'),
                title: Text(k.nhan, style: HD.body(size: 15, color: HD.ink)),
                trailing: k.khoa == _ky
                    ? const Icon(Icons.check_rounded, color: HD.accent)
                    : null,
                onTap: () => Navigator.of(ctx).pop(k.khoa),
              ),
          ],
        ),
      ),
    );
    if (chon != null && chon != _ky) setState(() => _ky = chon);
  }

  @override
  Widget build(BuildContext context) => TrangSale(
    tieuDe: 'Báo cáo',
    phuDe: '(${nhanKenh(widget.kenh)})',
    body: TaiSale<BaoCaoSale>(
      khoaTai: _ky,
      tai: () => widget.api.baoCao(widget.kenh, _ky),
      dung: (context, bc, taiLai) {
        final ngan = widget.kenh == kKenhNganHan;
        return RefreshIndicator(
          color: HD.accent,
          onRefresh: taiLai,
          child: ListView(
            key: const Key('bao-cao-sale'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Material(
                color: SaleMau.nenXam,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: const Key('chon-ky'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _chonKy(bc),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 20, color: HD.ink),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            bc.ky.nhan,
                            style: HD.bodyBold(size: 15, color: HD.ink),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: HD.inkMuted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _OSo(so: bc.so.baiDang, nhan: 'Bài đăng'),
                  const SizedBox(width: 8),
                  _OSo(so: bc.so.khachMoi, nhan: 'Khách mới'),
                  const SizedBox(width: 8),
                  _OSo(so: bc.so.lichXem, nhan: ngan ? 'Đơn đặt' : 'Lịch xem'),
                  const SizedBox(width: 8),
                  _OSo(so: bc.so.choChot, nhan: ngan ? 'Hoàn tất' : 'Đã chốt', noiBat: true),
                ],
              ),
              const SizedBox(height: 20),
              Text('Hiệu quả bài đăng', style: HD.bodyBold(size: 16, color: HD.ink)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ChuGiai(mau: SaleMau.lam, chu: 'Lượt xem'),
                  const SizedBox(width: 14),
                  _ChuGiai(mau: HD.accent, chu: ngan ? 'Đơn đặt' : 'Yêu cầu'),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                key: const Key('bieu-do-sale'),
                height: 200,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _VeBieuDo(
                    diem: bc.bieuDo,
                    mauXem: SaleMau.lam,
                    mauYeuCau: HD.accent.withValues(alpha: 0.55),
                    mauLuoi: SaleMau.vien,
                    kieuChu: HD.body(size: 11, color: HD.inkMuted),
                  ),
                ),
              ),
              if (bc.bieuDo.every((d) => d.luotXem == 0))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Lượt xem được ghi theo ngày từ 05/10/2026.',
                    style: HD.body(size: 12, color: HD.inkMuted),
                  ),
                ),
              if (bc.hoaHongDuKien != null) ...[
                const SizedBox(height: 20),
                Text('Hoa hồng', style: HD.bodyBold(size: 16, color: HD.ink)),
                const SizedBox(height: 10),
                TheSale(
                  child: Row(
                    children: [
                      _CotTien(nhan: 'Dự kiến tháng', tien: bc.hoaHongDuKien ?? 0),
                      _CotTien(nhan: 'Đã nhận', tien: bc.hoaHongDaNhan ?? 0),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${bc.phanTram ?? 0}%',
                              style: HD.bodyBold(size: 16, color: HD.ink),
                            ),
                            const SizedBox(height: 2),
                            Text('Tỷ lệ', style: HD.body(size: 12, color: HD.inkMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class _OSo extends StatelessWidget {
  const _OSo({required this.so, required this.nhan, this.noiBat = false});

  final int so;
  final String nhan;
  final bool noiBat;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: noiBat ? HD.accentTint : SaleMau.nenXam,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$so',
            style: HD.bodyBold(size: 22, color: noiBat ? HD.accent : HD.ink),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(nhan, style: HD.body(size: 12.5, color: HD.inkSoft)),
          ),
        ],
      ),
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
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: mau, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 5),
      Text(chu, style: HD.body(size: 12.5, color: HD.inkSoft)),
    ],
  );
}

class _CotTien extends StatelessWidget {
  const _CotTien({required this.nhan, required this.tien});

  final String nhan;
  final double tien;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(tienSale(tien), style: HD.bodyBold(size: 16, color: HD.ink)),
        ),
        const SizedBox(height: 2),
        Text(nhan, style: HD.body(size: 12, color: HD.inkMuted)),
      ],
    ),
  );
}

/// Cột đôi mỗi ngày: xanh = lượt xem tin, đỏ nhạt = yêu cầu mới. Trục dọc 4
/// mốc "tròn", nhãn ngày mỗi 7 ngày (01/10 · 08/10 …).
class _VeBieuDo extends CustomPainter {
  _VeBieuDo({
    required this.diem,
    required this.mauXem,
    required this.mauYeuCau,
    required this.mauLuoi,
    required this.kieuChu,
  });

  final List<DiemBieuDo> diem;
  final Color mauXem;
  final Color mauYeuCau;
  final Color mauLuoi;
  final TextStyle kieuChu;

  static int _buocTron(int giaTri) {
    for (final b in const [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000]) {
      if (b * 3 >= giaTri) return b;
    }
    return ((giaTri / 3) / 1000).ceil() * 1000;
  }

  void _chu(Canvas c, String s, Offset tam, {bool canPhai = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: kieuChu),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = canPhai ? tam.dx - tp.width : tam.dx - tp.width / 2;
    tp.paint(c, Offset(dx, tam.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const trai = 30.0;
    const duoi = 22.0;
    final rong = size.width - trai;
    final cao = size.height - duoi - 6;
    if (rong <= 0 || cao <= 0) return;
    final lonNhat = diem.fold<int>(0, (m, d) => math.max(m, math.max(d.luotXem, d.yeuCau)));
    final buoc = _buocTron(math.max(lonNhat, 1));
    final dinh = buoc * 3;
    final luoi = Paint()
      ..color = mauLuoi
      ..strokeWidth = 1;
    for (var k = 0; k <= 3; k++) {
      final y = 6 + cao - cao * k / 3;
      canvas.drawLine(Offset(trai, y), Offset(size.width, y), luoi);
      _chu(canvas, '${buoc * k}', Offset(trai - 6, y), canPhai: true);
    }
    if (diem.isEmpty) return;
    final o = rong / diem.length;
    final cot = math.max(1.5, math.min(7.0, o * 0.34));
    final xem = Paint()..color = mauXem;
    final yc = Paint()..color = mauYeuCau;
    for (var i = 0; i < diem.length; i++) {
      final giua = trai + o * i + o / 2;
      final hXem = cao * diem[i].luotXem / dinh;
      final hYc = cao * diem[i].yeuCau / dinh;
      final day = 6 + cao;
      if (hXem > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(giua - cot - 0.5, day - hXem, cot, hXem),
            topLeft: const Radius.circular(2),
            topRight: const Radius.circular(2),
          ),
          xem,
        );
      }
      if (hYc > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(giua + 0.5, day - hYc, cot, hYc),
            topLeft: const Radius.circular(2),
            topRight: const Radius.circular(2),
          ),
          yc,
        );
      }
      if (i % 7 == 0) {
        final d = diem[i].ngay;
        _chu(
          canvas,
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}',
          Offset(giua, size.height - duoi / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VeBieuDo old) => old.diem != diem;
}
