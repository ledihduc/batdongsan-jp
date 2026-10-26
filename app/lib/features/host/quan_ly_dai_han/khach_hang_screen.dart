import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/quan_ly_dai_han_api.dart';
import 'package:house_booking/features/host/quan_ly_dai_han/widgets/quan_ly_chung.dart';

/// MÀN 1/4 "Quản lý cho thuê dài hạn" — **Khách hàng** (mockup 23/09/2026).
///
/// Danh sách khách ĐANG THUÊ của một toà: ai ở phòng nào, ở bao lâu rồi, sắp
/// hết hợp đồng chưa, còn nợ bao nhiêu.
///
/// Route: push từ lưới "Quản lý" của màn toà. API:
/// `GET /api/host/buildings/{id}/khach-hang?tim=&loc=`.
///
/// Mọi con số do SERVER đếm (`services/quan_ly_dai_han.py`) — màn này không tự
/// suy "sắp hết HĐ", nếu không nó lệch với màn Hợp đồng.
class KhachHangToaScreen extends StatefulWidget {
  const KhachHangToaScreen({
    super.key,
    required this.buildingId,
    required this.buildingName,
    this.api = const QuanLyDaiHanApi(),
  });

  final int buildingId;
  final String buildingName;
  final QuanLyDaiHanApi api;

  @override
  State<KhachHangToaScreen> createState() => _KhachHangToaScreenState();
}

const _boLoc = <({String ma, String nhan})>[
  (ma: 'tat_ca', nhan: 'Tất cả'),
  (ma: 'dang_o', nhan: 'Đang ở'),
  (ma: 'sap_het_hd', nhan: 'Sắp hết HĐ'),
  (ma: 'co_cong_no', nhan: 'Có công nợ'),
];

class _KhachHangToaScreenState extends State<KhachHangToaScreen> {
  final _tim = TextEditingController();
  KhachHangToa? _du;
  String _loc = 'tat_ca';
  bool _dangTai = true;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void dispose() {
    _tim.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    setState(() => _loi = null);
    try {
      final d = await widget.api.khachHang(
        widget.buildingId,
        tim: _tim.text.trim(),
        loc: _loc,
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
        _loi = 'Chưa tải được danh sách khách. Kéo xuống để thử lại.';
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
                  _oTim(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: QlOSo(
                          khoa: 'khach-dang-o',
                          icon: Icons.people_alt_rounded,
                          mau: const Color(0xff078a59),
                          so: '${d?.dangO ?? 0}',
                          nhan: 'khách đang ở',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: QlOSo(
                          khoa: 'khach-sap-het-hd',
                          icon: Icons.person_outline,
                          mau: HD.accent,
                          so: '${d?.sapHetHd ?? 0}',
                          nhan: 'sắp hết HĐ',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: QlOSo(
                          khoa: 'khach-cong-no',
                          icon: Icons.account_balance_wallet_outlined,
                          mau: const Color(0xffdf8a00),
                          so: '${d?.coCongNo ?? 0}',
                          nhan: 'có công nợ',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  QlHangChip(
                    muc: [for (final b in _boLoc) (ma: b.ma, nhan: b.nhan)],
                    dangChon: _loc,
                    onChon: (ma) {
                      setState(() => _loc = ma);
                      _nap();
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_loi != null)
                    QlBaoLoi(chu: _loi!)
                  else if ((d?.danhSach ?? const []).isEmpty)
                    const QlRong(
                      icon: Icons.people_outline,
                      tieuDe: 'Chưa có khách nào',
                      phu: 'Khách sẽ hiện ở đây khi hợp đồng được kích hoạt.',
                    )
                  else
                    for (final k in d!.danhSach) _dong(k),
                ],
              ),
            ),
    );
  }

  Widget _oTim() => TextField(
    key: const Key('khach-tim'),
    controller: _tim,
    textInputAction: TextInputAction.search,
    onSubmitted: (_) => _nap(),
    onChanged: (_) => setState(() {}),
    style: HD.body(size: 13),
    decoration: InputDecoration(
      hintText: 'Tìm kiếm khách hàng (tên, SĐT, phòng...)',
      hintStyle: HD.body(size: 13, color: HD.inkMuted),
      prefixIcon: const Icon(Icons.search, size: 19, color: HD.inkMuted),
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 42),
      suffixIcon: _tim.text.isEmpty
          ? null
          : IconButton(
              key: const Key('khach-xoa-tim'),
              icon: const Icon(Icons.close, size: 18, color: HD.inkMuted),
              onPressed: () {
                _tim.clear();
                _nap();
              },
            ),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: QL.vien),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: QL.vien),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HD.accent),
      ),
    ),
  );

  Widget _dong(KhachThueToa k) {
    final (nhan, mau) = k.sapHetHd
        ? ('Sắp hết hạn', const Color(0xffdf8a00))
        : ('Đang ở', const Color(0xff078a59));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        key: Key('khach-${k.contractId}'),
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
        decoration: QL.the,
        child: Row(
          children: [
            QlAnhKhach(ten: k.ten),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          k.ten,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HD.bodyBold(size: 13.5),
                        ),
                      ),
                      QlChipNhan(chu: nhan, mau: mau),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    k.sdt.isEmpty ? k.phong : '${k.phong}  •  ${k.sdt}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 11.5, color: HD.inkMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Đã ở ${k.soThangDaO} tháng',
                    style: HD.body(size: 11.5, color: HD.inkMuted),
                  ),
                  if (k.no != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: HD.accentTint,
                        borderRadius: BorderRadius.circular(HD.rPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 12,
                            color: HD.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Còn nợ ${qlTien(k.no!)}',
                            style: HD.bodyBold(size: 10.5, color: HD.accent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: HD.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}
