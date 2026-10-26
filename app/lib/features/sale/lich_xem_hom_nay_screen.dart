import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/features/sale/sau_buoi_xem_screen.dart';

/// MÀN 4 của SALE — "Lịch xem hôm nay" (mockup SALE, 20/09/2026).
///
/// Dòng thời gian các buổi xem trong ngày (`work-queue?view=sale&date=`), ba
/// thẻ lọc Tất cả · Sắp diễn ra · Đã xong, và trạng thái ba bên cho từng buổi.
///
/// KHÔNG có nút "Check-in" như bản vẽ: server chưa có chỗ ghi ai đã tới (không
/// có endpoint check-in, không có cột giờ đến). Vẽ nút đó ra thì sale bấm xong
/// chẳng ghi được gì, còn khách và chủ nhà vẫn hiện "chưa đến" mãi mãi. Thay
/// vào đó hiện TRẠNG THÁI XÁC NHẬN có thật của ba bên, và nút mở màn ghi kết
/// quả sau buổi xem.
class LichXemHomNayScreen extends StatefulWidget {
  const LichXemHomNayScreen({
    super.key,
    this.api = const RentalJourneyApi(),
    this.bayGio,
  });

  final RentalJourneyApi api;
  final DateTime? bayGio;

  @override
  State<LichXemHomNayScreen> createState() => _LichXemHomNayScreenState();
}

class _LichXemHomNayScreenState extends State<LichXemHomNayScreen> {
  late DateTime _ngay;
  List<ViewingAppointmentModel> _ds = const [];
  int _tab = 0; // 0 tất cả · 1 sắp diễn ra · 2 đã xong
  bool _dangTai = true;
  String? _loi;

  DateTime get _bayGio => widget.bayGio ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _ngay = DateTime(_bayGio.year, _bayGio.month, _bayGio.day);
    _nap();
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final ds = await widget.api.workQueue(view: 'sale', date: _iso(_ngay));
      if (!mounted) return;
      setState(() {
        _ds = ds;
        _dangTai = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được lịch xem. Kéo xuống để thử lại.';
      });
    }
  }

  /// `locked` = đã chốt thuê sau buổi xem, `awaiting_guest` = chờ khách trả
  /// lời — cả hai đều là buổi xem ĐÃ diễn ra, không còn "sắp diễn ra".
  bool _daXong(ViewingAppointmentModel a) =>
      a.status == 'completed' ||
      a.status == 'cancelled' ||
      a.status == 'rejected' ||
      a.status == 'locked' ||
      a.status == 'awaiting_guest';

  static bool _daChot(ViewingAppointmentModel a) =>
      const {'completed', 'locked', 'cancelled', 'rejected'}.contains(a.status);

  bool _sapDienRa(ViewingAppointmentModel a) {
    if (_daXong(a)) return false;
    final gio = int.tryParse(a.bookingTime.split(':').first) ?? 0;
    return DateTime(_ngay.year, _ngay.month, _ngay.day, gio).isAfter(_bayGio);
  }

  List<ViewingAppointmentModel> get _loc => switch (_tab) {
    1 => [
      for (final a in _ds)
        if (_sapDienRa(a)) a,
    ],
    2 => [
      for (final a in _ds)
        if (_daXong(a)) a,
    ],
    _ => _ds,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HD.paper,
    appBar: AppBar(
      backgroundColor: HD.paperRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: const BackButton(color: HD.ink),
      title: Text('Lịch xem hôm nay', style: HD.bodyBold(size: 16)),
    ),
    body: Column(
      children: [
        _thanhNgay(),
        _thanhTab(),
        Expanded(
          child: _dangTai
              ? const Center(child: CircularProgressIndicator(color: HD.accent))
              : RefreshIndicator(
                  color: HD.accent,
                  onRefresh: _nap,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      HD.s16,
                      HD.s12,
                      HD.s16,
                      HD.s24,
                    ),
                    children: [
                      if (_loc.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: HD.s24),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.event_busy_outlined,
                                size: 34,
                                color: HD.inkMuted,
                              ),
                              const SizedBox(height: HD.s8),
                              Text(
                                'Không có lịch xem nào',
                                style: HD.bodyBold(size: 14),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final a in _loc) _dong(a),
                      if (_loi != null) ...[
                        const SizedBox(height: HD.s12),
                        Text(
                          _loi!,
                          style: HD.body(size: 12.5, color: HD.negative),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    ),
  );

  Widget _thanhNgay() => Container(
    color: HD.paperRaised,
    padding: const EdgeInsets.fromLTRB(HD.s8, 0, HD.s8, HD.s8),
    child: Row(
      children: [
        IconButton(
          key: const Key('sale-ngay-truoc'),
          onPressed: () {
            setState(() => _ngay = _ngay.subtract(const Duration(days: 1)));
            _nap();
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            _ngayDep(_ngay),
            textAlign: TextAlign.center,
            style: HD.bodyBold(size: 14),
          ),
        ),
        IconButton(
          key: const Key('sale-ngay-sau'),
          onPressed: () {
            setState(() => _ngay = _ngay.add(const Duration(days: 1)));
            _nap();
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );

  Widget _thanhTab() {
    final ten = [
      'Tất cả (${_ds.length})',
      'Sắp diễn ra (${_ds.where(_sapDienRa).length})',
      'Đã xong (${_ds.where(_daXong).length})',
    ];
    return Container(
      color: HD.paperRaised,
      padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, HD.s12),
      child: Row(
        children: [
          for (var i = 0; i < ten.length; i++) ...[
            if (i > 0) const SizedBox(width: HD.s8),
            InkWell(
              key: Key('sale-tab-$i'),
              onTap: () => setState(() => _tab = i),
              borderRadius: BorderRadius.circular(HD.rPill),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: HD.s12,
                  vertical: HD.s8,
                ),
                decoration: BoxDecoration(
                  color: i == _tab ? HD.accentTint : HD.paperSunken,
                  borderRadius: BorderRadius.circular(HD.rPill),
                ),
                child: Text(
                  ten[i],
                  style: HD.bodyBold(
                    size: 12,
                    color: i == _tab ? HD.accent : HD.inkSoft,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dong(ViewingAppointmentModel a) {
    final (nhan, mau) = _daXong(a)
        ? (_nhanTrangThai(a.status), HD.inkMuted)
        : _sapDienRa(a)
        ? ('Sắp diễn ra', HD.svcBlue)
        : ('Đang diễn ra', HD.accent);
    return Padding(
      padding: const EdgeInsets.only(bottom: HD.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Text(
              a.bookingTime.split('-').first,
              style: HD.bodyBold(size: 13),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(HD.s12),
              decoration: BoxDecoration(
                color: HD.paperRaised,
                borderRadius: BorderRadius.circular(HD.r12),
                border: Border.all(color: HD.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: mau.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(HD.rPill),
                    ),
                    child: Text(nhan, style: HD.bodyBold(size: 11, color: mau)),
                  ),
                  const SizedBox(height: HD.s8),
                  Text(
                    a.houseTitle ?? 'Tin đã gỡ',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HD.bodyBold(size: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 13,
                        color: HD.inkMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          a.guestName ?? 'Khách',
                          style: HD.body(size: 12.5, color: HD.inkSoft),
                        ),
                      ),
                    ],
                  ),
                  if ((a.houseAddress ?? '').isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: HD.inkMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            a.houseAddress!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HD.body(size: 12, color: HD.inkMuted),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: HD.s8),
                  _trangThaiBaBen(a),
                  const SizedBox(height: HD.s8),
                  // Lịch đã chốt thuê / đã huỷ thì không còn kết quả nào để
                  // ghi; để nút ở đó là mời sale bấm vào ngõ cụt.
                  if (!_daChot(a))
                    SizedBox(
                      height: 38,
                      width: double.infinity,
                      child: OutlinedButton(
                        key: Key('sale-ket-qua-${a.id}'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: HD.accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(HD.r8),
                          ),
                        ),
                        onPressed: () => Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    SauBuoiXemScreen(appointmentId: a.id!),
                              ),
                            )
                            .then((_) => _nap()),
                        child: Text(
                          'Ghi kết quả sau buổi xem',
                          style: HD.bodyBold(size: 13, color: HD.accent),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ba bên đã xác nhận tới đâu — chỉ in thứ server biết chắc.
  Widget _trangThaiBaBen(ViewingAppointmentModel a) {
    final daDuyet = a.status == 'approved' || a.status == 'completed';
    return Container(
      padding: const EdgeInsets.all(HD.s8),
      decoration: BoxDecoration(
        color: HD.paperSunken,
        borderRadius: BorderRadius.circular(HD.r8),
      ),
      child: Row(
        children: [
          _ben('Khách', true),
          _ben('Sale', daDuyet),
          _ben('Chủ nhà', daDuyet),
        ],
      ),
    );
  }

  Widget _ben(String ten, bool xong) => Expanded(
    child: Column(
      children: [
        Icon(
          xong ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: xong ? HD.positive : HD.inkMuted,
        ),
        const SizedBox(height: 2),
        Text(ten, style: HD.body(size: 11, color: HD.inkSoft)),
        Text(
          xong ? 'Đã xác nhận' : 'Chờ',
          style: HD.body(size: 10, color: HD.inkMuted),
        ),
      ],
    ),
  );

  static String _nhanTrangThai(String s) => switch (s) {
    'completed' => 'Đã xong',
    'cancelled' => 'Đã huỷ',
    'rejected' => 'Đã từ chối',
    'locked' => 'Đã chốt thuê',
    'awaiting_guest' => 'Chờ khách trả lời',
    'doi_gio' => 'Chờ khách chọn giờ',
    _ => s,
  };

  static String _ngayDep(DateTime d) {
    final thu = d.weekday == DateTime.sunday
        ? 'Chủ nhật'
        : 'Thứ ${d.weekday + 1}';
    return '$thu, ${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
