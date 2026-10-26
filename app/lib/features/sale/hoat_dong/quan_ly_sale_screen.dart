import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/sale/hoat_dong/bai_dang_cua_toi_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/bao_cao_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/chu_nha_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/don_lich_xem_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/hop_dong_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/khach_hang_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/toa_nha_phong_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

/// Màn 3 — Menu "Quản lý" (mockup 05/10/2026): công tắc Dài hạn | Ngắn hạn và
/// bảy lối vào — Bài đăng của tôi · Đơn & lịch xem · Khách hàng · Chủ nhà ·
/// Tòa nhà & phòng (chỉ xem) · Hợp đồng · Báo cáo.
class QuanLySaleScreen extends StatefulWidget {
  const QuanLySaleScreen({
    super.key,
    this.kenh = kKenhDaiHan,
    this.api = const SaleVanHanhApi(),
  });

  final String kenh;
  final SaleVanHanhApi api;

  @override
  State<QuanLySaleScreen> createState() => _QuanLySaleScreenState();
}

class _QuanLySaleScreenState extends State<QuanLySaleScreen> {
  late String _kenh = widget.kenh;

  void _mo(Widget man) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    final muc = <(String, String?, String, IconData, Color, Widget Function())>[
      (
        'Bài đăng của tôi',
        null,
        'Quản lý, chỉnh sửa, theo dõi hiệu quả',
        Icons.article_outlined,
        SaleMau.camDam,
        () => BaiDangCuaToiScreen(kenh: _kenh, api: api),
      ),
      (
        'Đơn & lịch xem',
        null,
        _kenh == kKenhNganHan
            ? 'Theo dõi đơn đặt phòng của khách'
            : 'Quản lý yêu cầu, lịch xem, cập nhật kết quả',
        Icons.event_note_outlined,
        HD.svcCyan,
        () => DonLichXemScreen(kenh: _kenh, api: api),
      ),
      (
        'Khách hàng',
        null,
        'Danh sách khách, lịch sử trao đổi',
        Icons.people_alt_outlined,
        SaleMau.lam,
        () => KhachHangSaleScreen(kenh: _kenh, api: api),
      ),
      (
        'Chủ nhà',
        null,
        'Danh sách chủ, liên hệ, tòa nhà',
        Icons.home_work_outlined,
        SaleMau.cam,
        () => ChuNhaSaleScreen(kenh: _kenh, api: api),
      ),
      (
        'Tòa nhà & phòng',
        '(chỉ xem)',
        'Xem thông tin tòa nhà và tình trạng phòng',
        Icons.apartment_outlined,
        HD.svcTeal,
        () => ToaNhaPhongSaleScreen(kenh: _kenh, api: api),
      ),
      (
        'Hợp đồng',
        null,
        _kenh == kKenhNganHan
            ? 'Lưu trú ngắn hạn không lập hợp đồng'
            : 'Theo dõi các hợp đồng đã chốt',
        Icons.description_outlined,
        SaleMau.tim,
        () => HopDongSaleScreen(kenh: _kenh, api: api),
      ),
      (
        'Báo cáo',
        null,
        'Thống kê hiệu quả, hoa hồng',
        Icons.bar_chart_rounded,
        HD.svcRose,
        () => BaoCaoSaleScreen(kenh: _kenh, api: api),
      ),
    ];
    return TrangSale(
      tieuDe: 'Quản lý',
      body: ListView(
        key: const Key('menu-quan-ly-sale'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          CongTacHaiO(
            trai: 'Dài hạn',
            phai: 'Ngắn hạn',
            chonTrai: _kenh == kKenhDaiHan,
            onChon: (trai) =>
                setState(() => _kenh = trai ? kKenhDaiHan : kKenhNganHan),
          ),
          const SizedBox(height: 14),
          for (final (ten, phu, mo, icon, mau, man) in muc)
            TheSale(
              key: Key('muc-$ten'),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              onTap: () => _mo(man()),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: mau,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: ten,
                                style: HD.bodyBold(size: 15.5, color: HD.ink),
                              ),
                              if (phu != null)
                                TextSpan(
                                  text: ' $phu',
                                  style: HD.body(size: 15, color: HD.inkSoft),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(mo, style: HD.body(size: 13, color: HD.inkMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
