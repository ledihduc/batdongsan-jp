import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/quan_ly_api.dart';
import 'package:house_booking/features/guest/quan_ly/widgets/lich_sap_toi.dart';

/// Toàn bộ mốc sắp tới, nhóm theo NGÀY — mở từ "Xem tất cả" và thẻ "Sắp tới"
/// của trang Quản lý. Route: không (push trong tab). API: không (nhận sẵn danh
/// sách mốc trang Quản lý đã tải — mở ra là thấy ngay, không chờ lần hai).
class LichSapToiScreen extends StatelessWidget {
  const LichSapToiScreen({
    super.key,
    required this.lich,
    required this.goc,
    required this.onChon,
    this.bayGio,
  });

  final List<SuKienQuanLy> lich;
  final GocQuanLy goc;
  final ValueChanged<SuKienQuanLy> onChon;

  /// Chỉ để test ghim "hôm nay".
  final DateTime? bayGio;

  String _nhanNgay(DateTime ngay, DateTime homNay) {
    final dm =
        '${ngay.day.toString().padLeft(2, '0')}/${ngay.month.toString().padLeft(2, '0')}';
    final cach = ngay.difference(homNay).inDays;
    if (cach == 0) return 'Hôm nay · $dm';
    if (cach == 1) return 'Ngày mai · $dm';
    return '${thuVN(ngay)} · $dm';
  }

  @override
  Widget build(BuildContext context) {
    final n = bayGio ?? DateTime.now();
    final homNay = DateTime(n.year, n.month, n.day);
    final nhom = <DateTime, List<SuKienQuanLy>>{};
    for (final e in lich) {
      final t = e.batDau;
      if (t == null) continue;
      nhom.putIfAbsent(DateTime(t.year, t.month, t.day), () => []).add(e);
    }
    final ngay = nhom.keys.toList()..sort();

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.paper,
        surfaceTintColor: HD.paper,
        title: Text('Lịch sắp tới · ${goc.nhan}', style: HD.bodyBold(size: 17)),
      ),
      body: lich.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(HD.s32),
                child: Text(
                  'Chưa có lịch nào sắp tới.',
                  style: HD.body(size: 14, color: HD.inkMuted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s32),
              children: [
                for (final d in ngay) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(HD.s4, HD.s12, 0, HD.s8),
                    child: Text(
                      _nhanNgay(d, homNay),
                      style: HD.bodyBold(size: 14).copyWith(color: HD.inkSoft),
                    ),
                  ),
                  for (final e in nhom[d]!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: HD.s8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: HD.paperRaised,
                          borderRadius: BorderRadius.circular(HD.r12),
                        ),
                        child: DongSuKien(e: e, onTap: () => onChon(e)),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
