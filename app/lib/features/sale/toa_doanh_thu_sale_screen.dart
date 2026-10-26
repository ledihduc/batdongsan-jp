import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/sale_yeu_cau_api.dart';
import 'package:house_booking/features/sale/widgets/sale_chung.dart';

/// MÀN 5 — "Toà liên kết & Doanh thu" (mockup VuaNhà 23/09/2026).
///
/// Hai câu hỏi của sale cuối tháng: mình đang có nguồn hàng nào, và tháng này
/// kiếm được bao nhiêu. Doanh thu ở đây là GIÁ TRỊ HỢP ĐỒNG đã chốt (giá thuê
/// × số tháng) — sale bán cả kỳ thuê, không bán một tháng; hoa hồng mới là
/// tiền của sale.
///
/// API: GET /api/sale/toa-doanh-thu
class ToaDoanhThuSaleScreen extends StatefulWidget {
  const ToaDoanhThuSaleScreen({
    super.key,
    this.api = const SaleYeuCauApi(),
    this.moTaiDoanhThu = false,
  });

  final SaleYeuCauApi api;

  /// Vào từ ô "Doanh thu" thì cuộn thẳng tới khối tiền.
  final bool moTaiDoanhThu;

  @override
  State<ToaDoanhThuSaleScreen> createState() => _ToaDoanhThuSaleScreenState();
}

class _ToaDoanhThuSaleScreenState extends State<ToaDoanhThuSaleScreen> {
  final _khoiTien = GlobalKey();
  ToaVaDoanhThu? _du;
  bool _dangTai = true;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    try {
      final d = await widget.api.toaDoanhThu();
      if (!mounted) return;
      setState(() {
        _du = d;
        _dangTai = false;
        _loi = null;
      });
      if (widget.moTaiDoanhThu) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _khoiTien.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 300),
            );
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = e is ApiException ? e.message : 'Chưa tải được số liệu';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _du;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.paperRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: HD.ink),
        title: Text('Toà liên kết & Doanh thu', style: HD.bodyBold(size: 16)),
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
                  if (d != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text('Toà liên kết', style: HD.sectionTitle()),
                        ),
                        Text(
                          '${d.toa.length} toà · ${d.soChuLienKet} chủ nhà',
                          style: HD.body(size: 12, color: HD.inkMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (d.toa.isEmpty)
                      SaleRong(
                        icon: Icons.apartment_outlined,
                        tieuDe: 'Chưa liên kết toà nào',
                        mo:
                            'Nhận mã mời từ chủ nhà để được giao nguồn hàng. '
                            'Chưa có toà thì yêu cầu của khách không có căn để gửi.',
                      ),
                    for (final t in d.toa) _theToa(t),
                    const SizedBox(height: 20),
                    Text(
                      'Doanh thu & hoa hồng',
                      key: _khoiTien,
                      style: HD.sectionTitle(),
                    ),
                    const SizedBox(height: 10),
                    _tien(d),
                    const SizedBox(height: 18),
                    Text('Doanh thu 6 tháng', style: HD.sectionTitle()),
                    const SizedBox(height: 10),
                    _bieuDo(d),
                    const SizedBox(height: 18),
                    Text('Giao dịch gần đây', style: HD.sectionTitle()),
                    const SizedBox(height: 10),
                    if (d.ganDay.isEmpty)
                      Text(
                        'Chưa có đơn nào chốt.',
                        style: HD.body(size: 12.5, color: HD.inkMuted),
                      ),
                    for (final g in d.ganDay) _theGiaoDich(g),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _theToa(ToaLienKet t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      key: Key('sale-toa-${t.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: HD.svcViolet.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(HD.r12),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              size: 22,
              color: HD.svcViolet,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.ten,
                  overflow: TextOverflow.ellipsis,
                  style: HD.bodyBold(size: 14),
                ),
                if (t.diaChi.isNotEmpty)
                  Text(
                    t.diaChi,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 11.5, color: HD.inkMuted),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${t.soPhong} phòng · ${t.phongTrong} phòng trống',
                  style: HD.body(size: 12, color: HD.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _tien(ToaVaDoanhThu d) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: SaleOSo(
              icon: Icons.task_alt,
              so: '${d.donDaChot}',
              nhan: 'Đơn đã chốt tháng này',
              mau: HD.accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SaleOSo(
              icon: Icons.bar_chart_rounded,
              so: saleTien(d.doanhThuThang),
              nhan: 'Giá trị hợp đồng',
              mau: HD.svcViolet,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: SaleOSo(
              icon: Icons.savings_outlined,
              so: saleTien(d.hoaHongDuKien),
              nhan: 'Hoa hồng dự kiến',
              mau: HD.svcAmber,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SaleOSo(
              icon: Icons.account_balance_wallet_outlined,
              so: saleTien(d.hoaHongDaNhan),
              nhan: 'Hoa hồng đã nhận',
              mau: HD.positive,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _bieuDo(ToaVaDoanhThu d) {
    final ds = d.theoThang;
    final dinh = ds.fold<double>(0, (a, b) => b.doanhThu > a ? b.doanhThu : a);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      height: 190,
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: dinh <= 0
          ? Center(
              child: Text(
                'Chưa có đơn chốt nào trong 6 tháng qua.',
                style: HD.body(size: 12.5, color: HD.inkMuted),
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final t in ds)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          t.doanhThu <= 0 ? '' : saleTien(t.doanhThu),
                          style: HD.bodyBold(size: 10, color: HD.inkSoft),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: (t.doanhThu / dinh * 110).clamp(4, 110),
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            // Cột 0 đồng tô xám: tô đỏ như tháng có tiền là
                            // vẽ một tháng làm ăn được trong khi không có gì.
                            color: t.doanhThu > 0 ? HD.accent : HD.hairline,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'T${t.thang.month}',
                          style: HD.body(size: 11, color: HD.inkMuted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _theGiaoDich(GiaoDichGanDay g) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: HD.positive),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${g.ma} · ${g.khach}', style: HD.bodyBold(size: 13)),
                Text(
                  saleTruoc(g.chotLuc),
                  style: HD.body(size: 11.5, color: HD.inkMuted),
                ),
              ],
            ),
          ),
          Text(
            saleTien(g.giaThue, hau: '/tháng'),
            style: HD.bodyBold(size: 13, color: HD.accent),
          ),
        ],
      ),
    ),
  );
}
