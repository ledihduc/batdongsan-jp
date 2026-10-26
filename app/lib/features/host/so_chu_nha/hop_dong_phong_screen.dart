import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/giay_to_hop_dong_api.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/shared/giay_to_hop_dong_section.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';

/// Màn 5 — "Hợp đồng – Phòng 201".
///
/// Thẻ đầu: nhãn Đang hiệu lực · số HĐ · thời hạn; bảng: Ngày lập HĐ · Ngày dự
/// kiến rời đi · Chu kỳ thu tiền · Giá thuê · Cọc đã thu · Đại diện/Sale; đáy:
/// Xem hợp đồng / Gia hạn; cuối màn là khối Giấy tờ (ảnh hợp đồng + minh
/// chứng cọc, chủ nhà hoặc khách tải bổ sung — thuê trước, bổ sung sau).
/// API: `GET /api/host/so-chu-nha/phong/{id}/hop-dong`, `POST …/hop-dong/gia-han`.
class HopDongPhongScreen extends StatefulWidget {
  const HopDongPhongScreen({
    super.key,
    required this.roomId,
    this.api = const SoChuNhaApi(),
    this.giayToApi = const GiayToHopDongApi(),
  });

  final int roomId;
  final SoChuNhaApi api;
  final GiayToHopDongApi giayToApi;

  @override
  State<HopDongPhongScreen> createState() => _HopDongPhongScreenState();
}

class _HopDongPhongScreenState extends State<HopDongPhongScreen> {
  late Future<HopDongCN?> _f = widget.api.hopDong(widget.roomId);
  bool _dang = false;

  Future<void> _giaHan(HopDongCN h) async {
    final soThang = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: MauCN.the,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gia hạn hợp đồng', style: HD.bodyBold(size: 18, color: HD.ink)),
              const SizedBox(height: 4),
              Text(
                'Hiện kết thúc ${ngayCN(h.ketThuc)}. Gia hạn thêm:',
                style: HD.body(size: 14, color: HD.inkMuted),
              ),
              const SizedBox(height: 14),
              for (final n in const [3, 6, 12])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: NutCN(
                    '$n tháng',
                    key: Key('cn-gia-han-$n'),
                    kieu: n == 6 ? KieuNutCN.do_ : KieuNutCN.vien,
                    onPressed: () => Navigator.pop(context, n),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (soThang == null || !mounted) return;
    setState(() => _dang = true);
    try {
      final moi = await widget.api.giaHan(widget.roomId, soThang);
      if (!mounted) return;
      setState(() {
        _f = Future.value(moi);
        _dang = false;
      });
      baoCN(context, 'Đã gia hạn đến ${ngayCN(moi?.ketThuc)}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _dang = false);
      baoCN(context, loiCN(e), loi: true);
    }
  }

  void _xem(HopDongCN h) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MauCN.the,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (context, cuon) => ListView(
          key: const Key('cn-van-ban-hop-dong'),
          controller: cuon,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
          children: [
            Text(
              'HỢP ĐỒNG THUÊ PHÒNG',
              textAlign: TextAlign.center,
              style: HD.bodyBold(size: 17, color: HD.ink),
            ),
            const SizedBox(height: 4),
            Text('Số: ${h.so}', textAlign: TextAlign.center, style: HD.body(color: HD.inkMuted)),
            const SizedBox(height: 18),
            _dieu('Bên thuê', h.khach == null ? 'Chưa ghi nhận' : '${h.khach!.ten}${h.khach!.sdt == null ? '' : ' · ${h.khach!.sdt}'}'),
            _dieu('Phòng', h.tenPhong),
            _dieu('Thời hạn', '${ngayCN(h.batDau)} – ${ngayCN(h.ketThuc)}'),
            _dieu('Giá thuê', '${tienCN(h.giaThue)}/tháng'),
            _dieu('Tiền cọc', tienCN(h.tienCoc)),
            _dieu('Chu kỳ thanh toán', h.chuKy + (h.hinhThuc == null ? '' : ' · ${h.hinhThuc}')),
            if (h.daiDien != null) _dieu('Đại diện', '${h.daiDien!.ten} (${h.daiDien!.vai ?? 'Sale'})'),
            if (h.ghiChu != null) _dieu('Ghi chú', h.ghiChu!),
          ],
        ),
      ),
    );
  }

  Widget _dieu(String nhan, String noi) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nhan, style: HD.bodyBold(size: 13.5, color: HD.inkMuted)),
        const SizedBox(height: 3),
        Text(noi, style: HD.body(size: 15, color: HD.ink)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HopDongCN?>(
      future: _f,
      builder: (context, s) {
        final h = s.data;
        final tieuDe = h == null ? 'Hợp đồng' : 'Hợp đồng – ${h.tenPhong}';
        Widget body;
        if (s.connectionState != ConnectionState.done) {
          body = const Center(child: CircularProgressIndicator(color: HD.accent));
        } else if (s.hasError) {
          body = RongCN(loiCN(s.error!), icon: Icons.cloud_off_rounded);
        } else if (h == null) {
          body = const RongCN('Phòng chưa có hợp đồng nào.', icon: Icons.description_outlined);
        } else {
          body = _noiDung(h);
        }
        return ManCN(
          tieuDe: tieuDe,
          body: body,
          day: h == null
              ? null
              : HaiNutCN(
                  trai: NutCN(
                    'Xem hợp đồng',
                    key: const Key('cn-xem-hop-dong'),
                    kieu: KieuNutCN.vien,
                    onPressed: () => _xem(h),
                  ),
                  phai: NutCN(
                    'Gia hạn',
                    key: const Key('cn-gia-han'),
                    dangChay: _dang,
                    onPressed: h.giaHanDuoc ? () => _giaHan(h) : null,
                  ),
                ),
        );
      },
    );
  }

  Widget _noiDung(HopDongCN h) {
    return ListView(
      key: const Key('cn-hop-dong'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        TheCN(
          child: Row(
            children: [
              const OIconCN(Icons.description_outlined, mau: HD.accent, nen: HD.accentTint, co: 50),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NhanCN.trangThai(h.trangThai),
                    const SizedBox(height: 6),
                    Text(h.so, style: HD.bodyBold(size: 18, color: HD.ink)),
                    const SizedBox(height: 3),
                    Text(
                      '${ngayCN(h.batDau)} – ${ngayCN(h.ketThuc)}',
                      style: HD.body(size: 13.5, color: HD.inkMuted),
                    ),
                  ],
                ),
              ),
              if (h.conThang != null)
                Column(
                  children: [
                    Text('${h.conThang}', style: HD.bodyBold(size: 22, color: HD.accent)),
                    Text('tháng còn lại', style: HD.body(size: 11.5, color: HD.inkMuted)),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TheCN(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              DongCN('Ngày lập HĐ', ngayCN(h.ngayLap)),
              Divider(height: 1, color: MauCN.vien),
              DongCN('Ngày dự kiến rời đi', ngayCN(h.duKienRoiDi)),
              Divider(height: 1, color: MauCN.vien),
              DongCN('Chu kỳ thu tiền', h.chuKy),
              Divider(height: 1, color: MauCN.vien),
              DongCN('Giá thuê', '${tienCN(h.giaThue)}/tháng', dam: true, mau: HD.accent),
              Divider(height: 1, color: MauCN.vien),
              DongCN('Cọc đã thu', h.cocDaThu == null ? 'Chưa ghi nhận' : tienCN(h.cocDaThu!), dam: true),
              Divider(height: 1, color: MauCN.vien),
              DongCN(
                'Đại diện/Sale',
                h.daiDien == null ? 'Chưa có' : h.daiDien!.ten,
              ),
              if (h.khach != null) ...[
                Divider(height: 1, color: MauCN.vien),
                DongCN('Người thuê', h.khach!.ten),
              ],
            ],
          ),
        ),
        // Ảnh hợp đồng + minh chứng cọc — chủ nhà hoặc khách tải, cùng thấy.
        if (h.id > 0) ...[
          const SizedBox(height: 12),
          GiayToHopDongSection(contractId: h.id, api: widget.giayToApi),
        ],
      ],
    );
  }
}
