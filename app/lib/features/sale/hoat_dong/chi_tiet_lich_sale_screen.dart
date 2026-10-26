import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/sale/hoat_dong/hanh_dong_lich.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/nhan_sale.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

/// "Xem chi tiết" một lịch xem phía sale: phòng, giờ hẹn, khách (gọi /
/// nhắn), chủ nhà (gọi), lời nhắn, kết quả — và đúng các nút server cho phép.
/// API: `GET /api/sale/van-hanh/lich-xem/{id}`.
class ChiTietLichSaleScreen extends StatefulWidget {
  const ChiTietLichSaleScreen({
    super.key,
    required this.appointmentId,
    this.api = const SaleVanHanhApi(),
    this.lichXemApi = const LichXemApi(),
  });

  final int appointmentId;
  final SaleVanHanhApi api;
  final LichXemApi lichXemApi;

  @override
  State<ChiTietLichSaleScreen> createState() => _ChiTietLichSaleScreenState();
}

class _ChiTietLichSaleScreenState extends State<ChiTietLichSaleScreen> {
  int _lan = 0;

  @override
  Widget build(BuildContext context) => TrangSale(
    tieuDe: 'Chi tiết lịch xem',
    body: TaiSale<LichSale>(
      khoaTai: _lan,
      tai: () => widget.api.chiTietLich(widget.appointmentId),
      dung: (context, l, taiLai) => Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: HD.accent,
              onRefresh: taiLai,
              child: ListView(
                key: const Key('chi-tiet-lich-sale'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _dau(l),
                  _thoiGian(l),
                  _nguoi(
                    context,
                    vai: 'Khách hàng',
                    ten: l.khachTen,
                    anh: l.khachAnh,
                    sdt: l.khachSdt,
                    userId: l.khachId,
                    choNhan: true,
                  ),
                  if (l.chuNhaTen.isNotEmpty)
                    _nguoi(
                      context,
                      vai: 'Chủ nhà',
                      ten: l.chuNhaTen,
                      anh: null,
                      sdt: l.chuNhaSdt,
                      userId: l.chuNhaId,
                      choNhan: false,
                    ),
                  if (l.loiNhan.isNotEmpty) _khoiChu('Lời nhắn của khách', l.loiNhan),
                  if (l.ketQua != null) _ketQua(l),
                ],
              ),
            ),
          ),
          _thanhNut(context, l),
        ],
      ),
    ),
  );

  Widget _dau(LichSale l) {
    final (chu, tong) = nhanLich(l.nhan);
    return TheSale(
      child: Row(
        children: [
          AnhSale(url: l.phongAnh, co: 72),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.phongTen, style: HD.bodyBold(size: 15.5, color: HD.ink)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    NhanSale.tong(chu, tong),
                    const SizedBox(width: 8),
                    if (l.ma.isNotEmpty)
                      Text(l.ma, style: HD.body(size: 12.5, color: HD.inkMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thoiGian(LichSale l) {
    final bd = l.batDau;
    return TheSale(
      child: Column(
        children: [
          _dong(
            Icons.event_outlined,
            'Thời gian',
            bd == null ? khungGio(l.gio) : '${ngayDayDu(bd)} • ${khungGio(l.gio)}',
          ),
          _dong(
            Icons.videocam_outlined,
            'Hình thức',
            l.hinhThuc == 'video' ? 'Xem qua video call' : 'Xem trực tiếp',
          ),
          _dong(Icons.group_outlined, 'Số người', '${l.soNguoi} người'),
          if (l.diaChi.isNotEmpty)
            _dong(Icons.location_on_outlined, 'Địa chỉ', l.diaChi, cuoi: true),
        ],
      ),
    );
  }

  Widget _dong(IconData icon, String nhan, String giaTri, {bool cuoi = false}) =>
      Padding(
        padding: EdgeInsets.only(bottom: cuoi ? 0 : 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: HD.inkMuted),
            const SizedBox(width: 8),
            SizedBox(
              width: 82,
              child: Text(nhan, style: HD.body(size: 13.5, color: HD.inkMuted)),
            ),
            Expanded(
              child: Text(giaTri, style: HD.body(size: 13.5, color: HD.ink)),
            ),
          ],
        ),
      );

  Widget _nguoi(
    BuildContext context, {
    required String vai,
    required String ten,
    required String? anh,
    required String sdt,
    required int? userId,
    required bool choNhan,
  }) => TheSale(
    child: Row(
      children: [
        AvatarSale(ten: ten, url: anh, co: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(vai, style: HD.body(size: 12, color: HD.inkMuted)),
              Text(ten, style: HD.bodyBold(size: 15, color: HD.ink)),
              if (sdt.isNotEmpty)
                Text(sdt, style: HD.body(size: 13, color: HD.inkSoft)),
            ],
          ),
        ),
        NutTronSale(
          key: Key('goi-$vai'),
          icon: Icons.call_rounded,
          tooltip: 'Gọi $ten',
          onTap: () => goiSo(context, sdt),
        ),
        if (choNhan) ...[
          const SizedBox(width: 8),
          NutTronSale(
            icon: Icons.chat_rounded,
            tooltip: 'Nhắn tin',
            onTap: () => nhanTinVoi(context, userId: userId, ten: ten, anh: anh),
          ),
        ],
      ],
    ),
  );

  Widget _khoiChu(String tieuDe, String noiDung) => TheSale(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tieuDe, style: HD.bodyBold(size: 14, color: HD.ink)),
        const SizedBox(height: 6),
        Text(noiDung, style: HD.body(size: 13.5, color: HD.inkSoft)),
      ],
    ),
  );

  Widget _ketQua(LichSale l) {
    final chot = l.ketQua == 'chot';
    final mau = chot ? SaleMau.xanh : HD.accent;
    return TheSale(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(chot ? Icons.check_circle_rounded : Icons.cancel_rounded, color: mau),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chot ? 'Khách muốn thuê' : 'Khách không thuê',
                  style: HD.bodyBold(size: 14.5, color: mau),
                ),
                const SizedBox(height: 2),
                Text(
                  chot
                      ? 'Đang chờ chủ nhà xác nhận chốt và lập hợp đồng.'
                      : 'Lịch xem đã kết thúc.',
                  style: HD.body(size: 13, color: HD.inkMuted),
                ),
                if (l.ghiChuKetQua.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('“${l.ghiChuKetQua}”', style: HD.body(size: 13, color: HD.inkSoft)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thanhNut(BuildContext context, LichSale l) {
    final nut = [for (final n in l.hanhDong) if (n != 'xem_chi_tiet') n];
    if (nut.isEmpty) return const SizedBox.shrink();
    Future<void> chay(String hd) async {
      final doi = await chayHanhDongLich(
        context,
        l,
        hd,
        api: widget.api,
        lichXemApi: widget.lichXemApi,
      );
      if (doi && mounted) setState(() => _lan++);
    }

    final cap = <(String, KieuNutSale, String)>[
      if (nut.contains('tu_choi')) ('Từ chối', KieuNutSale.vienDo, 'tu_choi'),
      if (nut.contains('doi_lich')) ('Đổi lịch', KieuNutSale.vienDo, 'doi_lich'),
      if (nut.contains('xac_nhan')) ('Xác nhận', KieuNutSale.do_, 'xac_nhan'),
      if (nut.contains('cap_nhat_ket_qua'))
        ('Cập nhật kết quả', KieuNutSale.lam, 'cap_nhat_ket_qua'),
    ];
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: SaleMau.nen,
          border: Border(top: BorderSide(color: SaleMau.vien)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < cap.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: NutSale(
                  cap[i].$1,
                  key: Key('ct-${cap[i].$3}'),
                  kieu: cap[i].$2,
                  cao: 46,
                  onPressed: () => chay(cap[i].$3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
