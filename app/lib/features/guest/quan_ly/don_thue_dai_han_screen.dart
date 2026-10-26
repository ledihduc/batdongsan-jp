import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/don_thue_khach_api.dart';
import 'package:house_booking/features/guest/quan_ly/don_thue_chi_tiet_screen.dart';
import 'package:house_booking/features/sale/widgets/sale_chung.dart';

/// Tất cả đơn thuê dài hạn của khách — mỗi thẻ chỉ giữ căn, trạng thái hiện
/// tại và việc cần làm; chi tiết kỹ thuật nằm ở phía vận hành.
/// Chạm → Chi tiết đơn. Route: không có URL (push từ tab Hoạt động).
/// API: GET /api/guest/don-thue?nhom=
class DonThueDaiHanScreen extends StatefulWidget {
  const DonThueDaiHanScreen({super.key, this.api = const DonThueKhachApi()});

  final DonThueKhachApi api;

  @override
  State<DonThueDaiHanScreen> createState() => _DonThueDaiHanScreenState();
}

const _nhomNhan = <String, String>{
  'tat_ca': 'Tất cả',
  'dang_xu_ly': 'Đang xử lý',
  'cho_coc': 'Chờ cọc',
  'da_chot': 'Đã chốt',
  'da_dong': 'Đã đóng',
};

class _DonThueDaiHanScreenState extends State<DonThueDaiHanScreen> {
  String _nhom = 'tat_ca';
  BangDonThue? _bang;
  String? _loi;
  bool _dangTai = true;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final b = await widget.api.danhSach(nhom: _nhom);
      if (!mounted) return;
      setState(() {
        _bang = b;
        _dangTai = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = e is ApiException ? e.message : 'Chưa tải được đơn thuê';
      });
    }
  }

  Future<void> _mo(MucDonThue d) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DonThueChiTietScreen(nguon: d.nguon, id: d.id, api: widget.api),
      ),
    );
    if (mounted) _nap();
  }

  @override
  Widget build(BuildContext context) {
    final b = _bang;
    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      appBar: AppBar(title: const Text('Đơn thuê dài hạn')),
      body: RefreshIndicator(
        color: HD.accent,
        onRefresh: _nap,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final e in _nhomNhan.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SaleChipLoc(
                        key: Key('don-thue-nhom-${e.key}'),
                        nhan: e.value,
                        so: b?.dem[e.key] ?? 0,
                        chon: _nhom == e.key,
                        onTap: () {
                          if (_nhom == e.key) return;
                          setState(() => _nhom = e.key);
                          _nap();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loi != null) SaleBaoLoi(loi: _loi!, onThuLai: _nap),
            if (_dangTai && b == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: HD.accent),
                ),
              ),
            if (b != null && b.don.isEmpty)
              SaleRong(
                icon: Icons.assignment_outlined,
                tieuDe: _nhom == 'tat_ca'
                    ? 'Bạn chưa có đơn thuê nào'
                    : 'Không có đơn ở mục này',
                mo:
                    'Đặt lịch xem một căn nhà — đơn thuê sẽ hiện ở đây và '
                    'đi qua từng bước tới khi chốt thuê.',
              ),
            if (b != null)
              for (final d in b.don) ...[
                _TheDon(d: d, onTap: () => _mo(d)),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _TheDon extends StatelessWidget {
  const _TheDon({required this.d, required this.onTap});

  final MucDonThue d;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mau = d.dong ? HD.inkMuted : saleMauBuoc(d.buoc);
    return Material(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: Key('don-thue-${d.nguon}-${d.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      d.ten,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HD.bodyBold(size: 15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SaleNhan(chu: d.dong ? 'Đã đóng' : d.nhan, mau: mau),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right, color: HD.inkMuted),
                ],
              ),
              if (d.viecTiep.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      d.dong ? Icons.info_outline : Icons.arrow_forward,
                      size: 16,
                      color: mau,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        d.viecTiep,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HD.body(size: 12.5, color: HD.inkSoft),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
