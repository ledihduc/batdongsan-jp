import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/sale/hoat_dong/chi_tiet_lich_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/nhan_sale.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

/// Màn 9 — "Hợp đồng" (mockup 05/10/2026): giao dịch sale đã chốt theo vòng
/// đời Đang xử lý (chờ chủ xác nhận / đang ký) · Hiệu lực · Đã kết thúc.
/// API: `GET /api/sale/van-hanh/hop-dong?kenh=`.
class HopDongSaleScreen extends StatefulWidget {
  const HopDongSaleScreen({
    super.key,
    this.kenh = kKenhDaiHan,
    this.api = const SaleVanHanhApi(),
  });

  final String kenh;
  final SaleVanHanhApi api;

  @override
  State<HopDongSaleScreen> createState() => _HopDongSaleScreenState();
}

class _HopDongSaleScreenState extends State<HopDongSaleScreen> {
  String _loc = 'dang_xu_ly';

  @override
  Widget build(BuildContext context) => TrangSale(
    tieuDe: 'Hợp đồng',
    phuDe: '(${nhanKenh(widget.kenh)})',
    body: TaiSale<DanhSachSale<HopDongSale>>(
      tai: () => widget.api.hopDong(widget.kenh),
      dung: (context, d, taiLai) {
        final ds = [for (final h in d.ds) if (h.nhom == _loc) h];
        return Column(
          children: [
            const SizedBox(height: 4),
            DaiChipSale(
              chip: [for (final c in d.chip) (c.khoa, c.nhan, c.so)],
              chon: _loc,
              onChon: (k) => setState(() => _loc = k),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                color: HD.accent,
                onRefresh: taiLai,
                child: ds.isEmpty
                    ? ListView(
                        children: [
                          RongSale(
                            chu: d.ghiChu.isNotEmpty
                                ? d.ghiChu
                                : 'Chưa có hợp đồng nào ở mục này.',
                            icon: Icons.description_outlined,
                          ),
                        ],
                      )
                    : ListView.builder(
                        key: const Key('ds-hop-dong'),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: ds.length,
                        itemBuilder: (_, i) => _TheHopDong(
                          h: ds[i],
                          onTap: ds[i].appointmentId == null
                              ? null
                              : () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ChiTietLichSaleScreen(
                                        appointmentId: ds[i].appointmentId!,
                                        api: widget.api,
                                      ),
                                    ),
                                  );
                                  await taiLai();
                                },
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _TheHopDong extends StatelessWidget {
  const _TheHopDong({required this.h, required this.onTap});

  final HopDongSale h;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (chu, tong) = nhanHopDong(h.nhan);
    final ngay = h.ngayTao;
    return TheSale(
      key: Key('the-hop-dong-${h.khoa}'),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnhSale(url: h.phongAnh, co: 80),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        h.phongTen,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: HD.bodyBold(size: 14.5, color: HD.ink),
                      ),
                    ),
                    const SizedBox(width: 6),
                    NhanSale.tong(chu, tong),
                  ],
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Khách: ',
                        style: HD.body(size: 13.5, color: HD.inkMuted),
                      ),
                      TextSpan(
                        text: h.khachTen,
                        style: HD.bodyBold(size: 13.5, color: HD.inkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ngay == null ? '' : 'Ngày tạo: ${ngayDayDu(ngay)}',
                  style: HD.body(size: 13, color: HD.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
