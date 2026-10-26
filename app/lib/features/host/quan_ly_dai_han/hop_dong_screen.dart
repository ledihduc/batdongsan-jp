import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/quan_ly_dai_han_api.dart';
import 'package:house_booking/features/host/quan_ly_dai_han/widgets/quan_ly_chung.dart';

/// MÀN 2/4 "Quản lý cho thuê dài hạn" — **Hợp đồng** (mockup 23/09/2026).
///
/// Theo dõi hồ sơ và kỳ hạn thuê: mỗi thẻ là một hợp đồng với giá thuê, tiền
/// cọc và thanh tiến độ "đã qua mấy tháng / còn mấy tháng".
///
/// Route: push từ lưới "Quản lý" của màn toà. API:
/// `GET /api/host/buildings/{id}/hop-dong?tab=`.
///
/// Bốn tab đúng bốn tình trạng server phân: hiệu lực · sắp hết hạn · **chờ gia
/// hạn** (giấy hết mà người vẫn ở — trạng thái thật hay bị bỏ quên) · đã kết thúc.
class HopDongToaScreen extends StatefulWidget {
  const HopDongToaScreen({
    super.key,
    required this.buildingId,
    required this.buildingName,
    this.api = const QuanLyDaiHanApi(),
  });

  final int buildingId;
  final String buildingName;
  final QuanLyDaiHanApi api;

  @override
  State<HopDongToaScreen> createState() => _HopDongToaScreenState();
}

const _tabs = <({String ma, String nhan})>[
  (ma: 'hieu_luc', nhan: 'Hiệu lực'),
  (ma: 'sap_het_han', nhan: 'Sắp hết hạn'),
  (ma: 'cho_gia_han', nhan: 'Chờ gia hạn'),
  (ma: 'da_ket_thuc', nhan: 'Đã kết thúc'),
];

class _HopDongToaScreenState extends State<HopDongToaScreen> {
  HopDongToa? _du;
  String _tab = 'hieu_luc';
  bool _dangTai = true;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    setState(() => _loi = null);
    try {
      final d = await widget.api.hopDong(widget.buildingId, tab: _tab);
      if (!mounted) return;
      setState(() {
        _du = d;
        _dangTai = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được hợp đồng. Kéo xuống để thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _du;
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
                          khoa: 'hd-hieu-luc',
                          icon: Icons.people_alt_rounded,
                          mau: QL.xanh,
                          so: '${d?.hieuLuc ?? 0}',
                          nhan: 'HĐ hiệu lực',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: QlOSo(
                          khoa: 'hd-sap-het',
                          icon: Icons.description_outlined,
                          mau: HD.accent,
                          so: '${d?.sapHetHan ?? 0}',
                          nhan: 'HĐ sắp hết hạn',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loi != null)
                    QlBaoLoi(chu: _loi!)
                  else if ((d?.danhSach ?? const []).isEmpty)
                    QlRong(
                      icon: Icons.description_outlined,
                      tieuDe: 'Không có hợp đồng nào',
                      phu: _phuRong(),
                    )
                  else
                    for (final h in d!.danhSach) _the(h),
                ],
              ),
            ),
    );
  }

  String _phuRong() => switch (_tab) {
    'sap_het_han' => 'Chưa hợp đồng nào tới hạn trong 30 ngày.',
    'cho_gia_han' => 'Không có hợp đồng nào hết hạn mà khách vẫn đang ở.',
    'da_ket_thuc' => 'Chưa có hợp đồng nào kết thúc.',
    _ => 'Tạo hợp đồng cho phòng đang có khách để theo dõi kỳ hạn.',
  };

  Widget _the(HopDongMuc h) {
    final (mau, nhanMau) = switch (h.nhom) {
      'sap_het_han' => (QL.cam, QL.cam),
      'cho_gia_han' => (HD.accent, HD.accent),
      'da_ket_thuc' => (HD.inkMuted, HD.inkMuted),
      _ => (QL.xanh, QL.xanh),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        key: Key('hop-dong-${h.id}'),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: QL.the,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                QlAnhKhach(ten: h.khach, canh: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              h.phong,
                              style: HD.bodyBold(size: 14),
                            ),
                          ),
                          QlChipNhan(chu: h.nhan, mau: nhanMau),
                        ],
                      ),
                      const SizedBox(height: 3),
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
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.event_outlined,
                            size: 12,
                            color: HD.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${qlNgay(h.tu)} - ${qlNgay(h.den)}',
                            style: HD.body(size: 11.5, color: HD.inkMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _oTien('Giá thuê', '${qlTien(h.giaThue, day: true)}/tháng'),
                ),
                Expanded(
                  child: _oTien('Tiền cọc', qlTien(h.tienCoc, day: true)),
                ),
              ],
            ),
            if (h.tongThang > 0) ...[
              const SizedBox(height: 10),
              QlThanhTienDo(phanTram: h.phanTram, mau: mau),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Đã qua ${h.daQuaThang} tháng',
                      style: HD.body(size: 11, color: HD.inkMuted),
                    ),
                  ),
                  Text(
                    h.nhom == 'da_ket_thuc'
                        ? 'Đã kết thúc'
                        : 'Còn ${h.conThang} tháng',
                    style: HD.body(size: 11, color: HD.inkMuted),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _oTien(String nhan, String gia) => Row(
    children: [
      Text('$nhan  ', style: HD.body(size: 11.5, color: HD.inkMuted)),
      Expanded(
        child: Text(
          gia,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HD.bodyBold(size: 12),
        ),
      ),
    ],
  );
}
