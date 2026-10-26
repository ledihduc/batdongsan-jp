import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/dong_viec_sale.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

/// "Xem tất cả" của khối "Cần xử lý hôm nay" — toàn bộ việc, cùng kiểu dòng.
/// API: `GET /api/sale/van-hanh/tong-quan?kenh=`.
class CanXuLySaleScreen extends StatefulWidget {
  const CanXuLySaleScreen({
    super.key,
    this.kenh = kKenhDaiHan,
    this.api = const SaleVanHanhApi(),
  });

  final String kenh;
  final SaleVanHanhApi api;

  @override
  State<CanXuLySaleScreen> createState() => _CanXuLySaleScreenState();
}

class _CanXuLySaleScreenState extends State<CanXuLySaleScreen> {
  int _lan = 0;

  @override
  Widget build(BuildContext context) => TrangSale(
    tieuDe: 'Cần xử lý',
    phuDe: '(${nhanKenh(widget.kenh)})',
    body: TaiSale<TongQuanVanHanh>(
      khoaTai: _lan,
      tai: () => widget.api.tongQuan(widget.kenh),
      dung: (context, d, taiLai) => RefreshIndicator(
        color: HD.accent,
        onRefresh: taiLai,
        child: d.canXuLy.isEmpty
            ? ListView(
                children: const [
                  RongSale(
                    chu: 'Không còn việc nào cần xử lý.',
                    icon: Icons.task_alt_rounded,
                  ),
                ],
              )
            : ListView.separated(
                key: const Key('ds-can-xu-ly'),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: d.canXuLy.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: SaleMau.vien),
                itemBuilder: (_, i) => DongViecSale(
                  v: d.canXuLy[i],
                  onTap: () async {
                    await moViecSale(context, d.canXuLy[i], widget.kenh, api: widget.api);
                    if (mounted) setState(() => _lan++);
                  },
                ),
              ),
      ),
    ),
  );
}
