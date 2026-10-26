import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/sale/hoat_dong/hanh_dong_lich.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/the_lich_sale.dart';

/// Màn 5 — "Đơn & lịch xem" (mockup 05/10/2026).
///
/// Dài hạn: lịch xem khách đặt — Từ chối / Xác nhận · Đổi lịch / Cập nhật kết
/// quả · Xem chi tiết. Ngắn hạn: đơn đặt phòng (chủ nhà duyệt, sale theo dõi).
/// API: `GET /api/sale/van-hanh/lich?kenh=`.
class DonLichXemScreen extends StatefulWidget {
  const DonLichXemScreen({
    super.key,
    this.kenh = kKenhDaiHan,
    this.api = const SaleVanHanhApi(),
    this.lichXemApi = const LichXemApi(),
    this.locBanDau = 'tat_ca',
  });

  final String kenh;
  final SaleVanHanhApi api;
  final LichXemApi lichXemApi;

  /// Mở sẵn một chip (vd. "Chờ xác nhận" khi bấm từ Tổng quan).
  final String locBanDau;

  @override
  State<DonLichXemScreen> createState() => _DonLichXemScreenState();
}

class _DonLichXemScreenState extends State<DonLichXemScreen> {
  late String _kenh = widget.kenh;
  late String _loc = widget.locBanDau;
  int _lan = 0;

  @override
  Widget build(BuildContext context) => TrangSale(
    tieuDe: 'Đơn & lịch xem',
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: CongTacHaiO(
            trai: 'Dài hạn',
            phai: 'Ngắn hạn',
            chonTrai: _kenh == kKenhDaiHan,
            onChon: (trai) => setState(() {
              _kenh = trai ? kKenhDaiHan : kKenhNganHan;
              _loc = 'tat_ca';
            }),
          ),
        ),
        Expanded(
          child: TaiSale<DanhSachSale<LichSale>>(
            khoaTai: '$_kenh-$_lan',
            tai: () => widget.api.lich(_kenh),
            dung: (context, d, taiLai) {
              final chip = [for (final c in d.chip) (c.khoa, c.nhan, c.so)];
              if (!d.chip.any((c) => c.khoa == _loc)) _loc = 'tat_ca';
              final ds = _loc == 'tat_ca'
                  ? d.ds
                  : [for (final l in d.ds) if (l.nhom.contains(_loc)) l];
              return Column(
                children: [
                  DaiChipSale(
                    chip: chip,
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
                                  chu: _kenh == kKenhDaiHan
                                      ? 'Chưa có lịch xem nào ở mục này.'
                                      : 'Chưa có đơn đặt phòng nào ở mục này.',
                                  icon: Icons.event_note_outlined,
                                ),
                              ],
                            )
                          : ListView.builder(
                              key: const Key('ds-lich-sale'),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: ds.length,
                              itemBuilder: (_, i) => TheLichSale(
                                lich: ds[i],
                                onHanhDong: (hd) async {
                                  final doi = await chayHanhDongLich(
                                    context,
                                    ds[i],
                                    hd,
                                    api: widget.api,
                                    lichXemApi: widget.lichXemApi,
                                  );
                                  if (doi && mounted) setState(() => _lan++);
                                },
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
