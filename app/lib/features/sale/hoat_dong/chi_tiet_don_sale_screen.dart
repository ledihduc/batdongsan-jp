import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/chi_tiet_ca_thue_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/nhan_sale.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

/// "Xem chi tiết" một đơn đặt phòng ngắn hạn phía sale: theo dõi, liên lạc
/// hai bên, và nút "Xử lý đơn" sang màn quầy dùng chung với chủ nhà — ở đó
/// sale duyệt / từ chối / xác nhận nhận-trả phòng; phần TIỀN vẫn của chủ phòng
/// (server chặn, màn tự ẩn).
/// API: `GET /api/sale/van-hanh/don/{id}`.
class ChiTietDonSaleScreen extends StatelessWidget {
  const ChiTietDonSaleScreen({
    super.key,
    required this.reservationId,
    this.api = const SaleVanHanhApi(),
  });

  final int reservationId;
  final SaleVanHanhApi api;

  @override
  Widget build(BuildContext context) => TrangSale(
    tieuDe: 'Chi tiết đơn đặt phòng',
    body: TaiSale<LichSale>(
      tai: () => api.chiTietDon(reservationId),
      dung: (context, d, taiLai) => RefreshIndicator(
        color: HD.accent,
        onRefresh: taiLai,
        child: ListView(
          key: const Key('chi-tiet-don-sale'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _dau(d),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.icon(
                key: const Key('don-sale-xu-ly'),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ChiTietCaThueScreen(reservationId: reservationId),
                    ),
                  );
                  await taiLai();
                },
                icon: const Icon(Icons.task_alt_rounded, size: 18),
                label: const Text('Xử lý đơn · duyệt, nhận/trả phòng'),
                style: FilledButton.styleFrom(
                  backgroundColor: HD.accent,
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
            ),
            if (d.nhan == 'cho_chu_xac_nhan')
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SaleMau.camNen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: SaleMau.cam, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đơn đang chờ xác nhận. Bạn duyệt được ngay ở "Xử lý '
                        'đơn", hoặc gọi chủ nhà rồi báo lại cho khách.',
                        style: HD.body(size: 13, color: HD.ink),
                      ),
                    ),
                  ],
                ),
              ),
            TheSale(
              child: Column(
                children: [
                  _dong('Nhận phòng', d.batDau == null ? '—' : '${gioPhut(d.batDau!)} ${ngayDayDu(d.batDau!)}'),
                  _dong('Trả phòng', d.ketThuc == null ? '—' : '${gioPhut(d.ketThuc!)} ${ngayDayDu(d.ketThuc!)}'),
                  if (d.kieu.isNotEmpty) _dong('Kiểu thuê', d.kieu),
                  _dong('Số khách', '${d.soNguoi} người'),
                  if (d.tongTien != null) _dong('Tổng tiền', tienSale(d.tongTien!), cuoi: true),
                ],
              ),
            ),
            _nguoi(context, 'Khách hàng', d.khachTen, d.khachAnh, d.khachSdt, d.khachId, true),
            if (d.chuNhaTen.isNotEmpty)
              _nguoi(context, 'Chủ nhà', d.chuNhaTen, null, d.chuNhaSdt, d.chuNhaId, false),
            if (d.loiNhan.isNotEmpty)
              TheSale(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Ghi chú', style: HD.bodyBold(size: 14, color: HD.ink)),
                    const SizedBox(height: 6),
                    Text(d.loiNhan, style: HD.body(size: 13.5, color: HD.inkSoft)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _dau(LichSale d) {
    final (chu, tong) = nhanLich(d.nhan);
    return TheSale(
      child: Row(
        children: [
          AnhSale(url: d.phongAnh, co: 72),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.phongTen, style: HD.bodyBold(size: 15.5, color: HD.ink)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    NhanSale.tong(chu, tong),
                    const SizedBox(width: 8),
                    if (d.ma.isNotEmpty)
                      Text(d.ma, style: HD.body(size: 12.5, color: HD.inkMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dong(String nhan, String giaTri, {bool cuoi = false}) => Padding(
    padding: EdgeInsets.only(bottom: cuoi ? 0 : 10),
    child: Row(
      children: [
        Expanded(child: Text(nhan, style: HD.body(size: 13.5, color: HD.inkMuted))),
        Text(giaTri, style: HD.bodyBold(size: 13.5, color: HD.ink)),
      ],
    ),
  );

  Widget _nguoi(
    BuildContext context,
    String vai,
    String ten,
    String? anh,
    String sdt,
    int? userId,
    bool choNhan,
  ) => TheSale(
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
              if (sdt.isNotEmpty) Text(sdt, style: HD.body(size: 13, color: HD.inkSoft)),
            ],
          ),
        ),
        NutTronSale(
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
}
