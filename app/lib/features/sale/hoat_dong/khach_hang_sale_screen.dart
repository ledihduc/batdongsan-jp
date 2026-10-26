import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/sale/hoat_dong/chu_nha_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/nhan_sale.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

/// Màn 6 — "Khách hàng" (mockup 05/10/2026): hai tab Khách hàng | Chủ nhà,
/// ô tìm, chip trạng thái, mỗi dòng: avatar · tên · "Đang tư vấn • 3 lịch
/// xem" · nút gọi · nút nhắn.
/// API: `GET /api/sale/van-hanh/khach-hang?kenh=` (+ `/chu-nha` ở tab sau).
class KhachHangSaleScreen extends StatefulWidget {
  const KhachHangSaleScreen({
    super.key,
    this.kenh = kKenhDaiHan,
    this.api = const SaleVanHanhApi(),
  });

  final String kenh;
  final SaleVanHanhApi api;

  @override
  State<KhachHangSaleScreen> createState() => _KhachHangSaleScreenState();
}

class _KhachHangSaleScreenState extends State<KhachHangSaleScreen> {
  bool _tabKhach = true;
  String _loc = 'tat_ca';
  String _tim = '';

  bool _khop(KhachCuaSale k) {
    final q = _tim.trim().toLowerCase();
    if (q.isEmpty) return true;
    return k.ten.toLowerCase().contains(q) || k.sdt.contains(q);
  }

  @override
  Widget build(BuildContext context) => TrangSale(
    tieuDe: 'Khách hàng',
    phuDe: '(${nhanKenh(widget.kenh)})',
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: CongTacHaiO(
            trai: 'Khách hàng',
            phai: 'Chủ nhà',
            chonTrai: _tabKhach,
            khoaTrai: const Key('tab-khach-hang'),
            khoaPhai: const Key('tab-chu-nha'),
            onChon: (trai) => setState(() => _tabKhach = trai),
          ),
        ),
        Expanded(
          child: _tabKhach
              ? TaiSale<DanhSachSale<KhachCuaSale>>(
                  tai: () => widget.api.khachHang(widget.kenh),
                  dung: (context, d, taiLai) => _danhSach(d, taiLai),
                )
              : DanhSachChuNhaSale(api: widget.api),
        ),
      ],
    ),
  );

  Widget _danhSach(DanhSachSale<KhachCuaSale> d, Future<void> Function() taiLai) {
    final ds = [
      for (final k in d.ds)
        if ((_loc == 'tat_ca' || k.trangThai == _loc) && _khop(k)) k,
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: OTimSale(
            goiY: 'Tìm khách hàng...',
            onDoi: (v) => setState(() => _tim = v),
          ),
        ),
        DaiChipSale(
          chip: [for (final c in d.chip) (c.khoa, c.nhan, c.so)],
          chon: _loc,
          onChon: (k) => setState(() => _loc = k),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            color: HD.accent,
            onRefresh: taiLai,
            child: ds.isEmpty
                ? ListView(
                    children: [
                      RongSale(
                        chu: d.ds.isEmpty
                            ? 'Chưa có khách nào. Khách đặt lịch xem phòng bạn phụ trách '
                                  'sẽ tự vào đây.'
                            : 'Không tìm thấy khách phù hợp.',
                        icon: Icons.people_alt_outlined,
                      ),
                    ],
                  )
                : ListView.separated(
                    key: const Key('ds-khach-hang'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: ds.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: SaleMau.vien),
                    itemBuilder: (_, i) => _DongKhach(
                      k: ds[i],
                      donVi: widget.kenh == kKenhNganHan ? 'đơn đặt' : 'lịch xem',
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _DongKhach extends StatelessWidget {
  const _DongKhach({required this.k, required this.donVi});

  final KhachCuaSale k;
  final String donVi;

  @override
  Widget build(BuildContext context) {
    final (chu, tong) = nhanKhach(k.trangThai);
    final (mau, _) = mauTong(tong);
    return Padding(
      key: Key('khach-${k.id ?? k.userId ?? k.ten}'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          AvatarSale(ten: k.ten, url: k.anh, co: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k.ten, style: HD.bodyBold(size: 15.5, color: HD.ink)),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: chu, style: HD.body(size: 13, color: mau)),
                      TextSpan(
                        text: '  •  ${k.soLichXem} $donVi',
                        style: HD.body(size: 13, color: HD.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          NutTronSale(
            key: Key('goi-khach-${k.id ?? k.userId}'),
            icon: Icons.call_rounded,
            tooltip: 'Gọi ${k.ten}',
            onTap: () => goiSo(context, k.sdt),
          ),
          const SizedBox(width: 8),
          NutTronSale(
            key: Key('nhan-khach-${k.id ?? k.userId}'),
            icon: Icons.chat_rounded,
            tooltip: 'Nhắn tin',
            onTap: () => nhanTinVoi(context, userId: k.userId, ten: k.ten, anh: k.anh),
          ),
        ],
      ),
    );
  }
}
