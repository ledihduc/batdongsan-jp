import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/features/host/journey/lich_xem_da_xac_nhan_chu_nha_screen.dart';

/// MÀN 4 của CHỦ NHÀ — "Lịch xem hôm nay" (mockup CHỦ NHÀ, 20/09/2026).
///
/// Dòng thời gian buổi xem trong ngày + mục "Lịch sắp tới" của những ngày sau.
/// Nguồn: `work-queue?view=owner` (không ngày = mọi lịch của mình).
class LichXemHomNayChuNhaScreen extends StatefulWidget {
  const LichXemHomNayChuNhaScreen({
    super.key,
    this.api = const RentalJourneyApi(),
    this.bayGio,
  });

  final RentalJourneyApi api;
  final DateTime? bayGio;

  @override
  State<LichXemHomNayChuNhaScreen> createState() =>
      _LichXemHomNayChuNhaScreenState();
}

class _LichXemHomNayChuNhaScreenState extends State<LichXemHomNayChuNhaScreen> {
  late DateTime _ngay;
  List<ViewingAppointmentModel> _ds = const [];
  bool _dangTai = true;
  String? _loi;

  DateTime get _bayGio => widget.bayGio ?? DateTime.now();

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _ngay = DateTime(_bayGio.year, _bayGio.month, _bayGio.day);
    _nap();
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final ds = await widget.api.workQueue(view: 'owner');
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

  List<ViewingAppointmentModel> get _trongNgay => [
    for (final a in _ds)
      if (a.bookingDate == _iso(_ngay)) a,
  ];

  /// Buổi xem đã qua khâu diễn ra: xong, đã chốt thuê, đang chờ khách trả
  /// lời, hoặc đã huỷ/từ chối. Đếm mỗi `completed` là gọi lịch đã chốt thuê
  /// sáng nay là "sắp diễn ra".
  static bool _daXong(ViewingAppointmentModel a) => const {
    'completed',
    'locked',
    'awaiting_guest',
    'cancelled',
    'rejected',
  }.contains(a.status);

  /// Buổi xem đã có kết luận cuối — không còn gì để ghi thêm.
  static bool _daChot(ViewingAppointmentModel a) =>
      const {'completed', 'locked', 'cancelled', 'rejected'}.contains(a.status);

  List<ViewingAppointmentModel> get _sapToi => [
    for (final a in _ds)
      if (a.bookingDate.compareTo(_iso(_ngay)) > 0 && a.status != 'cancelled')
        a,
  ];

  @override
  Widget build(BuildContext context) {
    final xong = _trongNgay.where(_daXong).length;
    final sap = _trongNgay.length - xong;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.paperRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: HD.ink),
        title: Text('Lịch xem hôm nay', style: HD.bodyBold(size: 16)),
      ),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : RefreshIndicator(
              color: HD.accent,
              onRefresh: _nap,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, HD.s24),
                children: [
                  _thanhNgay(),
                  Text(
                    'Tổng ${_trongNgay.length} lịch xem · $sap sắp diễn ra · '
                    '$xong đã hoàn thành',
                    style: HD.body(size: 12, color: HD.inkMuted),
                  ),
                  const SizedBox(height: HD.s12),
                  if (_trongNgay.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: HD.s24),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.event_busy_outlined,
                            size: 34,
                            color: HD.inkMuted,
                          ),
                          const SizedBox(height: HD.s8),
                          Text(
                            'Ngày này không có lịch xem',
                            style: HD.bodyBold(size: 14),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final a in _trongNgay) _dong(a),
                  if (_sapToi.isNotEmpty) ...[
                    const SizedBox(height: HD.s16),
                    Text('Lịch sắp tới', style: HD.bodyBold(size: 15)),
                    const SizedBox(height: HD.s8),
                    for (final a in _sapToi.take(5)) _dongSapToi(a),
                  ],
                  if (_loi != null) ...[
                    const SizedBox(height: HD.s12),
                    Text(_loi!, style: HD.body(size: 12.5, color: HD.negative)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _thanhNgay() => Row(
    children: [
      IconButton(
        key: const Key('chu-ngay-truoc'),
        onPressed: () =>
            setState(() => _ngay = _ngay.subtract(const Duration(days: 1))),
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
        key: const Key('chu-ngay-sau'),
        onPressed: () =>
            setState(() => _ngay = _ngay.add(const Duration(days: 1))),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );

  Widget _dong(ViewingAppointmentModel a) {
    final (nhan, mau) = switch (a.status) {
      'completed' => ('Đã hoàn thành', HD.positive),
      'approved' => ('Sắp diễn ra', HD.svcBlue),
      'pending' => ('Chờ bạn xác nhận', HD.warning),
      'doi_gio' => ('Chờ khách chọn giờ', HD.svcOrange),
      // Thiếu ba nhãn dưới thì màn in thẳng mã trạng thái ra cho chủ nhà đọc
      // ("locked"), và lịch đã chốt thuê vẫn bị đếm là "sắp diễn ra".
      'locked' => ('Đã chốt thuê', HD.positive),
      'awaiting_guest' => ('Chờ khách trả lời', HD.svcPurple),
      'cancelled' => ('Đã huỷ', HD.inkMuted),
      'rejected' => ('Đã từ chối', HD.inkMuted),
      _ => (a.status, HD.inkMuted),
    };
    final daChot = _daChot(a);
    return Padding(
      padding: const EdgeInsets.only(bottom: HD.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.bookingTime.split('-').first,
                  style: HD.bodyBold(size: 13),
                ),
                Text(
                  a.bookingTime.split('-').length > 1
                      ? a.bookingTime.split('-').last
                      : '',
                  style: HD.body(size: 11.5, color: HD.inkMuted),
                ),
              ],
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
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: HD.paperSunken,
                        child: const Icon(
                          Icons.person,
                          size: 15,
                          color: HD.inkMuted,
                        ),
                      ),
                      const SizedBox(width: HD.s8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.guestName ?? 'Khách',
                              style: HD.bodyBold(size: 13.5),
                            ),
                            Text(
                              a.houseTitle ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HD.body(size: 12, color: HD.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: HD.s8),
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
                  if (!daChot)
                    SizedBox(
                      height: 36,
                      width: double.infinity,
                      child: OutlinedButton(
                        key: Key('chu-ket-qua-${a.id}'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: HD.accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(HD.r8),
                          ),
                        ),
                        onPressed: () => Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => LichXemDaXacNhanChuNhaScreen(
                                  appointmentId: a.id!,
                                ),
                              ),
                            )
                            .then((_) => _nap()),
                        child: Text(
                          'Xem chi tiết lịch',
                          style: HD.bodyBold(size: 12.5, color: HD.accent),
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

  Widget _dongSapToi(ViewingAppointmentModel a) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            '${_ngayNgan(a.bookingDate)} · ${a.bookingTime.split('-').first}',
            style: HD.bodyBold(size: 12),
          ),
        ),
        Expanded(
          child: Text(
            '${a.guestName ?? 'Khách'} · ${a.houseTitle ?? ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HD.body(size: 12.5, color: HD.inkSoft),
          ),
        ),
        if (a.status == 'approved')
          const Icon(Icons.check_circle, size: 15, color: HD.positive),
      ],
    ),
  );

  static String _ngayNgan(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  static String _ngayDep(DateTime d) {
    final thu = d.weekday == DateTime.sunday
        ? 'Chủ nhật'
        : 'Thứ ${d.weekday + 1}';
    return '$thu, ${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
