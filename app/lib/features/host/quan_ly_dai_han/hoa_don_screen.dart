import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/quan_ly_dai_han_api.dart';
import 'package:house_booking/features/host/quan_ly_dai_han/widgets/quan_ly_chung.dart';

/// MÀN 3/4 "Quản lý cho thuê dài hạn" — **Hóa đơn** (mockup 23/09/2026).
///
/// Thu tiền hàng tháng: mỗi thẻ là một hoá đơn kỳ này với bốn khoản (tiền
/// phòng · điện · nước · dịch vụ), tổng cộng và hạn thanh toán.
///
/// Route: push từ lưới "Quản lý" của màn toà. API:
/// `GET /api/host/buildings/{id}/hoa-don?thang=&tab=` và
/// `POST /api/host/buildings/{id}/hoa-don/tao-thang`.
///
/// Tab "Chưa tạo" KHÔNG đọc hoá đơn nháp mà đọc HỢP ĐỒNG chưa có hoá đơn kỳ
/// này — thứ chủ nhà thật sự cần biết là phòng nào chưa được lập.
class HoaDonToaScreen extends StatefulWidget {
  const HoaDonToaScreen({
    super.key,
    required this.buildingId,
    required this.buildingName,
    this.api = const QuanLyDaiHanApi(),
    this.thang,
  });

  final int buildingId;
  final String buildingName;
  final QuanLyDaiHanApi api;

  /// `YYYY-MM`; bỏ trống = tháng này (test ghim để số không đổi theo ngày chạy).
  final String? thang;

  @override
  State<HoaDonToaScreen> createState() => _HoaDonToaScreenState();
}

const _tabs = <({String ma, String nhan})>[
  (ma: 'chua_tao', nhan: 'Chưa tạo'),
  (ma: 'chua_thu', nhan: 'Chưa thu'),
  (ma: 'da_thu', nhan: 'Đã thu'),
  (ma: 'qua_han', nhan: 'Quá hạn'),
];

class _HoaDonToaScreenState extends State<HoaDonToaScreen> {
  HoaDonToa? _du;
  String _tab = 'chua_thu';
  bool _dangTai = true;
  bool _dangTao = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    setState(() => _loi = null);
    try {
      final d = await widget.api.hoaDon(
        widget.buildingId,
        thang: widget.thang,
        tab: _tab,
      );
      if (!mounted) return;
      setState(() {
        _du = d;
        _dangTai = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được hóa đơn. Kéo xuống để thử lại.';
      });
    }
  }

  Future<void> _taoThangNay() async {
    if (_dangTao) return;
    setState(() => _dangTao = true);
    try {
      final kq = await widget.api.taoHoaDonThang(
        widget.buildingId,
        thang: widget.thang,
      );
      if (!mounted) return;
      final hong = kq.khongLapDuoc;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hong.isEmpty
                ? 'Đã lập ${kq.vuaLap} hóa đơn cho ${qlThang(kq.thang).toLowerCase()}.'
                : 'Đã lập ${kq.vuaLap} hóa đơn. '
                      '${hong.length} phòng chưa lập được: '
                      '${hong.map((e) => e.phong).join(', ')}.',
          ),
        ),
      );
      await _nap();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa lập được hóa đơn. Thử lại giúp em.')),
      );
    } finally {
      if (mounted) setState(() => _dangTao = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _du;
    final conPhaiTao = (d?.chuaTao ?? const []).isNotEmpty;
    return Scaffold(
      backgroundColor: QL.nen,
      appBar: qlAppBar(context, widget.buildingName),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : RefreshIndicator(
              color: HD.accent,
              onRefresh: _nap,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  QlHangChip(
                    muc: [for (final t in _tabs) (ma: t.ma, nhan: t.nhan)],
                    dangChon: _tab,
                    onChon: (ma) {
                      setState(() => _tab = ma);
                      _nap();
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: QlOSo(
                          khoa: 'hd-chua-thu',
                          icon: Icons.receipt_long_rounded,
                          mau: HD.accent,
                          so: '${d?.chuaThu ?? 0}',
                          nhan: 'chưa thu',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: QlOSo(
                          khoa: 'hd-qua-han',
                          icon: Icons.error_outline,
                          mau: QL.cam,
                          so: '${d?.quaHan ?? 0}',
                          nhan: 'quá hạn',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: QlOSo(
                          khoa: 'hd-tong-can-thu',
                          icon: Icons.bar_chart_rounded,
                          mau: QL.xanh,
                          so: qlTien(d?.tongCanThu ?? 0),
                          nhan: 'Tổng cần thu',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loi != null)
                    QlBaoLoi(chu: _loi!)
                  else if (_tab == 'chua_tao')
                    ..._khoiChuaTao(d)
                  else if ((d?.danhSach ?? const []).isEmpty)
                    QlRong(
                      icon: Icons.receipt_long_outlined,
                      tieuDe: conPhaiTao && _tab == 'chua_thu'
                          ? 'Chưa lập hóa đơn kỳ này'
                          : 'Không có hóa đơn nào',
                      phu: conPhaiTao && _tab == 'chua_thu'
                          ? '${d!.chuaTao.length} phòng đang chờ lập hóa đơn.'
                          : _phuRong(),
                    )
                  else
                    for (final h in d!.danhSach) _the(h),
                ],
              ),
            ),
      bottomNavigationBar: _dangTai || !conPhaiTao
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: SizedBox(
                height: 50,
                child: FilledButton.icon(
                  key: const Key('hd-tao-thang-nay'),
                  style: FilledButton.styleFrom(
                    backgroundColor: HD.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _dangTao ? null : _taoThangNay,
                  icon: _dangTao
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add, size: 20, color: Colors.white),
                  label: Text(
                    'Tạo hóa đơn ${qlThang(d?.thang ?? '').toLowerCase()}',
                    style: HD.bodyBold(size: 14.5, color: Colors.white),
                  ),
                ),
              ),
            ),
    );
  }

  String _phuRong() => switch (_tab) {
    'da_thu' => 'Chưa hóa đơn nào được thanh toán trong kỳ này.',
    'qua_han' => 'Không có hóa đơn nào quá hạn — mọi khoản còn trong hạn.',
    _ => 'Mọi hóa đơn kỳ này đã thu xong.',
  };

  List<Widget> _khoiChuaTao(HoaDonToa? d) {
    final ds = d?.chuaTao ?? const <HoaDonChuaTao>[];
    if (ds.isEmpty) {
      return [
        const QlRong(
          icon: Icons.task_alt,
          tieuDe: 'Đã lập đủ hóa đơn',
          phu: 'Mọi hợp đồng đang hiệu lực đều có hóa đơn kỳ này.',
        ),
      ];
    }
    return [
      for (final c in ds)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            key: Key('hd-chua-tao-${c.contractId}'),
            padding: const EdgeInsets.all(12),
            decoration: QL.the,
            child: Row(
              children: [
                QlAnhKhach(ten: c.khach, canh: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.phong, style: HD.bodyBold(size: 13.5)),
                      const SizedBox(height: 2),
                      Text(
                        c.khach,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HD.body(size: 11.5, color: HD.inkMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${qlTien(c.giaThue, day: true)}/tháng',
                      style: HD.bodyBold(size: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.ngayThanhToan == null
                          ? 'Chưa đặt ngày thu'
                          : 'Thu ngày ${c.ngayThanhToan}',
                      style: HD.body(size: 10.5, color: HD.inkMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _the(HoaDonMuc h) {
    final (nhan, mau) = h.daTra
        ? (h.nhan, QL.xanh)
        : h.treHan
        ? (h.nhan, HD.accent)
        : h.daGui
        ? (h.nhan, QL.cam)
        : ('Chưa gửi khách', HD.inkMuted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        key: Key('hoa-don-${h.id}'),
        padding: const EdgeInsets.all(12),
        decoration: QL.the,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                QlAnhKhach(ten: h.khach, canh: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.phong, style: HD.bodyBold(size: 14)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 12,
                            color: HD.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              h.khach,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HD.body(size: 11.5, color: HD.inkSoft),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                QlChipNhan(chu: nhan, mau: mau),
              ],
            ),
            const SizedBox(height: 8),
            Text(h.ky, style: HD.bodyBold(size: 12, color: HD.inkSoft)),
            const SizedBox(height: 8),
            Row(
              children: [
                _khoan('Tiền phòng', h.tienPhong),
                _khoan('Điện', h.dien),
                _khoan('Nước', h.nuoc),
                _khoan('Dịch vụ', h.dichVu),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: QL.vien),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tổng cộng', style: HD.bodyBold(size: 12.5)),
                      const SizedBox(height: 4),
                      Text(
                        h.daTra
                            ? 'Đã thanh toán'
                            : 'Hạn thanh toán',
                        style: HD.body(size: 11, color: HD.inkMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      qlTien(h.tong, day: true),
                      style: HD.bodyBold(size: 15, color: HD.accent),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      qlNgay(h.han ?? ''),
                      style: HD.body(size: 11, color: HD.inkMuted),
                    ),
                  ],
                ),
              ],
            ),
            if (!h.daTra && h.daThu > 0) ...[
              const SizedBox(height: 6),
              Text(
                'Đã thu ${qlTien(h.daThu, day: true)} · còn '
                '${qlTien(h.conLai, day: true)}',
                style: HD.body(size: 11, color: QL.cam),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _khoan(String nhan, double tien) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nhan,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HD.body(size: 10, color: HD.inkMuted),
        ),
        const SizedBox(height: 2),
        Text(
          tien == 0 ? '—' : qlTien(tien, day: true),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HD.bodyBold(size: 11),
        ),
      ],
    ),
  );
}
