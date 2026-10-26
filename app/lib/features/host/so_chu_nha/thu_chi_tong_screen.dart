import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/thu_chi_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/the_dong_tien.dart';

/// Tab "Thu chi" của chủ nhà — mọi phòng đang cho thuê tháng trong một kỳ.
///
/// Kỳ (tháng) → Đã thu · Còn phải thu · Chi phí → tab Thu tiền | Chi phí →
/// từng phòng (Chưa thu lên trước), chạm mở "Thu chi – Phòng …".
/// API: `GET /api/host/so-chu-nha/thu-chi?thang=`.
class ThuChiTongScreen extends StatefulWidget {
  const ThuChiTongScreen({super.key, this.api = const SoChuNhaApi(), this.laTab = true});

  final SoChuNhaApi api;
  final bool laTab;

  @override
  State<ThuChiTongScreen> createState() => _ThuChiTongScreenState();
}

class _ThuChiTongScreenState extends State<ThuChiTongScreen> {
  String? _thang;
  int _tab = 0;
  int _lan = 0;

  Future<void> _moPhong(int roomId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ThuChiPhongScreen(roomId: roomId, api: widget.api)),
    );
    if (mounted) setState(() => _lan++);
  }

  @override
  Widget build(BuildContext context) {
    return ManCN(
      tieuDe: 'Thu chi',
      coNutLui: !widget.laTab,
      body: TaiCN<ThuChiTongCN>(
        khoaTai: '$_thang-$_lan',
        tai: () => widget.api.thuChiTong(thang: _thang),
        dung: (context, d, taiLai) => RefreshIndicator(
          color: HD.accent,
          onRefresh: taiLai,
          child: ListView(
            key: const Key('cn-thu-chi-tong'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              OChonKyCN(
                nhan: 'Kỳ',
                ky: d.thang,
                cacKy: d.kyChon,
                onChon: (t) => setState(() => _thang = t),
              ),
              const SizedBox(height: 14),
              _tong(d),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: TabCN(
                  tab: ['Thu tiền (${d.thu.length})', 'Chi phí (${d.chiPhi.length})'],
                  chon: _tab,
                  onChon: (i) => setState(() => _tab = i),
                ),
              ),
              const SizedBox(height: 12),
              if (_tab == 0) ...[
                if (d.thu.isEmpty)
                  const RongCN('Chưa có phòng nào đang cho thuê tháng.', icon: Icons.receipt_long_outlined),
                for (final k in d.thu) _dongThu(k),
              ] else ...[
                if (d.chiPhi.isEmpty)
                  const RongCN('Kỳ này chưa có khoản chi nào.', icon: Icons.build_circle_outlined),
                for (final c in d.chiPhi) _dongChi(c),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tong(ThuChiTongCN d) {
    Widget o(String nhan, double tien, Color mau) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nhan, style: HD.body(size: 12.5, color: HD.paperRaised.withValues(alpha: 0.88))),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(tienCN(tien), style: HD.bodyBold(size: 17, color: mau)),
          ),
        ],
      ),
    );
    return Container(
      key: const Key('cn-thu-chi-tong-the'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [HD.accent, HD.accentDeep]),
      ),
      child: Row(
        children: [
          o('Đã thu', d.daThu, HD.paperRaised),
          o('Còn phải thu', d.conPhaiThu, HD.paperRaised),
          o('Chi phí', d.tongChi, HD.paperRaised),
        ],
      ),
    );
  }

  Widget _dongThu(KhoanThuCN k) {
    return TheCN(
      key: Key('cn-thu-${k.roomId}'),
      margin: const EdgeInsets.only(bottom: 10),
      onTap: k.roomId == null ? null : () => _moPhong(k.roomId!),
      child: Row(
        children: [
          OIconCN(
            k.trangThai == 'da_thu' ? Icons.task_alt_rounded : Icons.door_front_door_outlined,
            mau: k.trangThai == 'da_thu' ? MauCN.xanh : HD.accent,
            nen: k.trangThai == 'da_thu' ? MauCN.xanhNen : HD.accentTint,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k.tenPhong ?? '', style: HD.bodyBold(size: 15, color: HD.ink)),
                const SizedBox(height: 2),
                Text(
                  [if (k.khach != null) k.khach!, 'Hạn ${ngayNganCN(k.han)}'].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.body(size: 12.5, color: HD.inkMuted),
                ),
                if (k.tenToa != null)
                  Text(
                    k.tenToa!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 12, color: HD.inkMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(tienCN(k.tong), style: HD.bodyBold(size: 14.5, color: HD.ink)),
              const SizedBox(height: 4),
              NhanCN.trangThai(k.trangThai),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dongChi(ChiPhiCN c) {
    return TheCN(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const OIconCN(Icons.handyman_outlined, mau: MauCN.cam, nen: MauCN.camNen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.tieuDe, style: HD.bodyBold(size: 15, color: HD.ink)),
                const SizedBox(height: 2),
                Text(
                  [if (c.tenPhong != null) c.tenPhong!, ngayCN(c.ngay)].join(' · '),
                  style: HD.body(size: 12.5, color: HD.inkMuted),
                ),
              ],
            ),
          ),
          Text('-${tienCN(c.soTien)}', style: HD.bodyBold(size: 14.5, color: HD.accent)),
        ],
      ),
    );
  }
}
