// ignore_for_file: unused_element

import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/su_kien_lich_su.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/features/guest/booking/lich_xem_da_xac_nhan_screen.dart';
import 'package:house_booking/features/guest/booking/sale_de_xuat_lich_screen.dart';
import 'package:house_booking/features/shared/viewing_detail_widgets.dart';

/// MÀN 2 — "Chờ sale xác nhận" (mockup quy trình KHÁCH THUÊ, 20/09/2026).
///
/// Tiến trình bốn bước: đã nhận yêu cầu → sale liên hệ chủ nhà → chờ chủ nhà
/// phản hồi → xác nhận lịch xem. Mốc thời gian lấy từ LỊCH SỬ thật của phiếu
/// (`/lich-su`), không bịa giờ.
///
/// Đây là cửa vào chung của hành trình sau khi gửi yêu cầu: phiếu chuyển sang
/// `doi_gio` thì mở [SaleDeXuatLichScreen] (màn 3), `approved` thì mở
/// [LichXemDaXacNhanScreen] (màn 4) — khách không phải tự hiểu trạng thái.
class ChoSaleXacNhanScreen extends StatefulWidget {
  const ChoSaleXacNhanScreen({
    super.key,
    required this.appointmentId,
    this.api = const LichXemApi(),
  });

  final int appointmentId;
  final LichXemApi api;

  @override
  State<ChoSaleXacNhanScreen> createState() => _ChoSaleXacNhanScreenState();
}

class _ChoSaleXacNhanScreenState extends State<ChoSaleXacNhanScreen> {
  PhieuHen? _p;
  List<SuKienLichSu> _lichSu = const [];
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
      final p = await widget.api.phieu(widget.appointmentId);
      List<SuKienLichSu> ls = const [];
      try {
        ls = await widget.api.lichSu(widget.appointmentId);
      } catch (_) {
        ls = const [];
      }
      if (!mounted) return;
      if (p.trangThai == 'doi_gio' || p.trangThai == 'approved') {
        _diTiep(p);
        return;
      }
      setState(() {
        _p = p;
        _lichSu = ls;
        _dangTai = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được yêu cầu. Kéo xuống để thử lại.';
      });
    }
  }

  void _diTiep(PhieuHen p) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => p.trangThai == 'doi_gio'
            ? SaleDeXuatLichScreen(appointmentId: p.id, api: widget.api)
            : LichXemDaXacNhanScreen(appointmentId: p.id, api: widget.api),
      ),
    );
  }

  /// Mốc của một hành động trong lịch sử — `null` nếu chưa xảy ra.
  DateTime? _luc(Iterable<String> hanhDong) {
    for (final s in _lichSu) {
      if (hanhDong.contains(s.hanhDong)) return s.luc;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tao = _luc({'create'});
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.accent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'Chi tiết xếp lịch',
          style: HD.bodyBold(size: 17, color: Colors.white),
        ),
      ),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : RefreshIndicator(
              color: HD.accent,
              onRefresh: _nap,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, HD.s24),
                children: [
                  const ViewingJourneyProgress(
                    labels: ['Gửi yêu cầu', 'Xếp lịch', 'Đi xem', 'Chốt thuê'],
                    icons: [
                      Icons.check,
                      Icons.event_available,
                      Icons.directions_walk,
                      Icons.handshake,
                    ],
                    current: 1,
                  ),
                  const SizedBox(height: HD.s16),
                  Text('Khung giờ bạn đã chọn', style: HD.bodyBold(size: 14)),
                  const SizedBox(height: HD.s8),
                  for (final slot in _khungDaChon()) _oKhung(slot),
                  const SizedBox(height: HD.s16),
                  Text('Trạng thái xử lý', style: HD.bodyBold(size: 14)),
                  const SizedBox(height: HD.s8),
                  _BuocTienTrinh(
                    nhan: 'Đã nhận yêu cầu của bạn',
                    luc: tao,
                    trang: _Trang.xong,
                  ),
                  _BuocTienTrinh(
                    nhan: 'Sale đang liên hệ chủ nhà',
                    luc: _luc({'status_change', 'sua'}) ?? tao,
                    trang: _Trang.dangLam,
                    phu: 'Đang kiểm tra lịch của chủ nhà…',
                  ),
                  const _BuocTienTrinh(
                    nhan: 'Chờ chủ nhà phản hồi',
                    trang: _Trang.chua,
                  ),
                  const _BuocTienTrinh(
                    nhan: 'Xác nhận lịch xem',
                    trang: _Trang.chua,
                    cuoi: true,
                  ),
                  const SizedBox(height: HD.s24),
                  _hopThongBao(),
                  if (_loi != null) ...[
                    const SizedBox(height: HD.s12),
                    Text(_loi!, style: HD.body(size: 12.5, color: HD.negative)),
                  ],
                ],
              ),
            ),
    );
  }

  List<String> _khungDaChon() {
    final p = _p;
    if (p == null) return const [];
    final marker = 'Các khung em có thể xem:';
    final raw = p.loiNhan.contains(marker)
        ? p.loiNhan.split(marker).last.trim()
        : '';
    final values = raw
        .split('·')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(3)
        .toList();
    return values.isEmpty
        ? ['${viewingPrettyDate(p.ngay)} · ${p.gio.replaceAll('-', ' - ')}']
        : values;
  }

  Widget _oKhung(String value) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: HD.s8),
    padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: 10),
    decoration: BoxDecoration(
      color: HD.accentTint,
      borderRadius: BorderRadius.circular(HD.r8),
    ),
    child: Row(
      children: [
        const Icon(Icons.calendar_month, size: 19, color: HD.accent),
        const SizedBox(width: HD.s8),
        Expanded(child: Text(value, style: HD.bodyBold(size: 12.5))),
      ],
    ),
  );

  Widget _tranhMinhHoa() => Container(
    height: 180,
    decoration: BoxDecoration(
      color: HD.accentTint,
      borderRadius: BorderRadius.circular(HD.r12 + 4),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          right: 28,
          child: Icon(
            Icons.home_rounded,
            size: 64,
            color: HD.accent.withValues(alpha: 0.35),
          ),
        ),
        const Positioned(
          left: 36,
          child: Icon(Icons.support_agent, size: 72, color: HD.accent),
        ),
        Positioned(
          top: 30,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(HD.r12),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 18,
              color: HD.accent,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _hopThongBao() => Container(
    padding: const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: HD.warningTint,
      borderRadius: BorderRadius.circular(HD.r12),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.notifications_active_outlined,
          size: 18,
          color: HD.warning,
        ),
        const SizedBox(width: HD.s8),
        Expanded(
          child: Text(
            'Bạn sẽ nhận được thông báo ngay khi có cập nhật mới.',
            style: HD.body(size: 12.5, color: HD.inkSoft),
          ),
        ),
      ],
    ),
  );
}

enum _Trang { xong, dangLam, chua }

/// Một bước trên tiến trình dọc: chấm trạng thái + đường nối + nhãn.
class _BuocTienTrinh extends StatelessWidget {
  const _BuocTienTrinh({
    required this.nhan,
    required this.trang,
    this.luc,
    this.phu,
    this.cuoi = false,
  });

  final String nhan;
  final _Trang trang;
  final DateTime? luc;
  final String? phu;
  final bool cuoi;

  @override
  Widget build(BuildContext context) {
    final mau = trang == _Trang.chua ? HD.hairline : HD.accent;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _cham(mau),
              if (!cuoi)
                Expanded(
                  child: Container(
                    width: 2,
                    color: mau.withValues(alpha: 0.45),
                  ),
                ),
            ],
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: cuoi ? 0 : HD.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nhan,
                    style: HD.bodyBold(
                      size: 14,
                      color: trang == _Trang.chua ? HD.inkMuted : HD.ink,
                    ),
                  ),
                  if (luc != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _gio(luc!),
                      style: HD.body(size: 12, color: HD.inkMuted),
                    ),
                  ],
                  if (phu != null) ...[
                    const SizedBox(height: HD.s8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: HD.s12,
                        vertical: HD.s8,
                      ),
                      decoration: BoxDecoration(
                        color: HD.accentTint,
                        borderRadius: BorderRadius.circular(HD.r8),
                      ),
                      child: Text(
                        phu!,
                        style: HD.body(size: 12, color: HD.accent),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cham(Color mau) {
    if (trang == _Trang.xong) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: mau, shape: BoxShape.circle),
        child: const Icon(Icons.check, size: 14, color: Colors.white),
      );
    }
    if (trang == _Trang.dangLam) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: mau, width: 3),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: mau, shape: BoxShape.circle),
          ),
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: HD.hairline, width: 2),
      ),
    );
  }

  static String _gio(DateTime d) {
    final now = DateTime.now();
    final hm =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final cungNgay =
        d.year == now.year && d.month == now.month && d.day == now.day;
    return cungNgay
        ? 'Hôm nay, $hm'
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}, $hm';
  }
}
