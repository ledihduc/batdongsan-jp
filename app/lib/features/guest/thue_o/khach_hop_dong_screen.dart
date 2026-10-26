import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/data/services/giay_to_hop_dong_api.dart';
import 'package:house_booking/features/shared/giay_to_hop_dong_section.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/guest/thue_o/ho_so_thue.dart';
import 'package:house_booking/features/guest/thue_o/widgets/thue_o_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Màn 3 — Hợp đồng (mockup 04/10/2026): "Hợp đồng hiện tại · Đang hiệu lực"
/// → tệp hợp đồng + nút "Xem hợp đồng" → Thông tin hợp đồng → Gia hạn.
/// Dữ liệu: hồ sơ phòng màn 2 đã tải ([HoSoThue]).
class KhachHopDongScreen extends StatelessWidget {
  const KhachHopDongScreen({
    super.key,
    required this.hoSo,
    this.giayToApi = const GiayToHopDongApi(),
  });

  final HoSoThue hoSo;
  final GiayToHopDongApi giayToApi;

  void _xem(BuildContext context) {
    final anh = hoSo.anhHopDong;
    if (anh.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa có ảnh hợp đồng. Bạn chụp bản đã ký rồi tải lên ở mục '
            '"Giấy tờ hợp đồng" bên dưới — chủ nhà cũng thấy.',
          ),
        ),
      );
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _XemTepHopDong(anh: anh)));
  }

  /// Gia hạn là việc hai bên thoả thuận — app chưa tự lập hợp đồng mới, nên
  /// đưa thẳng tới người quản lý phòng (gọi điện), kèm mốc hết hạn để nói.
  Future<void> _giaHan(BuildContext context) {
    final lh = hoSo.lienHe;
    final sdt = (lh?['sdt'] as String?) ?? '';
    final ten = [
      (lh?['vai'] as String?) ?? 'Chủ nhà / Quản lý',
      if (((lh?['ten'] as String?) ?? '').isNotEmpty) lh!['ten'] as String,
    ].join(' · ');
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Gia hạn hợp đồng', style: HD.bodyBold(size: 17)),
              const SizedBox(height: 8),
              Text(
                'Hợp đồng hết hạn ngày ${ngayVN(hoSo.ketThuc)}. '
                'Liên hệ $ten để thống nhất thời hạn và giá thuê mới.',
                style: HD.body(size: 13.5, color: HD.inkMuted),
              ),
              const SizedBox(height: 16),
              NutDo(
                sdt.isEmpty ? 'Chưa có số điện thoại' : 'Gọi $sdt',
                key: const Key('goi-gia-han'),
                onPressed: sdt.isEmpty
                    ? null
                    : () => launchUrl(Uri(scheme: 'tel', path: sdt)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hs = hoSo;
    final tienCoc = hs.tienCoc;
    return TrangThueO(
      tieuDe: 'Hợp đồng',
      body: ListView(
        key: const Key('khach-hop-dong'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          KhoiTrang(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TieuDeKhoi(
                  'Hợp đồng hiện tại',
                  phai: NhanTron.xanh('Đang hiệu lực'),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kVien),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kVien),
                        ),
                        child: const IconTaiLieu(to: true),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hợp đồng thuê nhà',
                              style: HD.bodyBold(size: 14.5, color: HD.ink),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              hs.tenTepHopDong,
                              style: HD.body(size: 12.5, color: HD.inkMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ngày ký: ${ngayVN(hs.ngayKy)}',
                              style: HD.body(size: 12.5, color: HD.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                NutDo(
                  'Xem hợp đồng',
                  key: const Key('xem-hop-dong'),
                  onPressed: () => _xem(context),
                ),
              ],
            ),
          ),
          KhoiTrang(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TieuDeKhoi('Thông tin hợp đồng'),
                DongThongTin(
                  'Thời hạn',
                  '${ngayVN(hs.batDau)} – ${ngayVN(hs.ketThuc)}',
                ),
                DongThongTin(
                  'Còn lại',
                  conLai(hs.ketThuc).replaceFirst('Còn ', ''),
                ),
                DongThongTin('Tiền thuê', '${tienVN(hs.tienThue)}/tháng'),
                DongThongTin(
                  'Tiền cọc',
                  tienCoc > 0 ? tienVN(tienCoc) : 'Chưa ghi nhận',
                ),
                DongThongTin('Hình thức thanh toán', hs.hinhThucThanhToan),
                DongThongTin(
                  'Ngày thanh toán hàng tháng',
                  hs.ngayThanhToan == null
                      ? '—'
                      : 'Ngày ${hai(hs.ngayThanhToan!)}',
                  vach: false,
                ),
              ],
            ),
          ),
          KhoiTrang(
            padding: EdgeInsets.zero,
            child: ListTile(
              key: const Key('gia-han-hop-dong'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: const Icon(Icons.history_rounded, color: HD.inkSoft),
              title: Text(
                'Gia hạn hợp đồng',
                style: HD.body(size: 14.5, color: HD.ink),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _giaHan(context),
            ),
          ),
          // Ảnh hợp đồng + minh chứng cọc — khách hoặc chủ nhà tải, cùng thấy.
          if (hoSo.contractId > 0)
            GiayToHopDongSection(contractId: hoSo.contractId, api: giayToApi),
        ],
      ),
    );
  }
}

/// Xem các trang hợp đồng đã ký (ảnh sale/chủ nhà tải lên).
class _XemTepHopDong extends StatelessWidget {
  const _XemTepHopDong({required this.anh});

  final List<String> anh;

  @override
  Widget build(BuildContext context) => TrangThueO(
    tieuDe: 'Bản hợp đồng',
    body: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: anh.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InteractiveViewer(
          child: CachedNetworkImage(imageUrl: anh[i], fit: BoxFit.contain),
        ),
      ),
    ),
  );
}
