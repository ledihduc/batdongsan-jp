import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/features/sale/chi_tiet_yeu_cau_khach_screen.dart';
import 'package:house_booking/features/sale/gui_ho_so_chot_thue_screen.dart';
import 'package:house_booking/features/sale/lich_xem_hom_nay_screen.dart';

/// MÀN 1 của SALE — "Việc cần xử lý" (mockup quy trình SALE, 20/09/2026).
///
/// Bốn con số ở đầu và danh sách việc đều lấy từ HÀNG CHỜ THẬT của sale
/// (`GET /api/viewing-appointments/work-queue?view=sale`) + hồ sơ thuê đang
/// tranh chấp (`GET /api/rental-journeys?view=sale&status=DISPUTED`).
///
/// "Quá hạn xác nhận" = lịch còn `pending` mà giờ hẹn đã qua — sale để khách
/// chờ quá lâu; đó là việc nặng nhất trong ngày nên đứng ngay cạnh việc mới.
class ViecCanXuLyScreen extends StatefulWidget {
  const ViecCanXuLyScreen({
    super.key,
    this.api = const RentalJourneyApi(),
    this.tenSale,
    this.bayGio,
  });

  final RentalJourneyApi api;
  final String? tenSale;

  /// Test ghim "bây giờ" để phân loại quá hạn không đổi theo lúc chạy.
  final DateTime? bayGio;

  @override
  State<ViecCanXuLyScreen> createState() => _ViecCanXuLyScreenState();
}

class _ViecCanXuLyScreenState extends State<ViecCanXuLyScreen> {
  List<ViewingAppointmentModel> _hang = const [];
  List<RentalJourney> _hoSo = const [];
  bool _dangTai = true;
  String? _loi;

  DateTime get _bayGio => widget.bayGio ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    setState(() => _loi = null);
    try {
      final hang = await widget.api.workQueue(view: 'sale');
      List<RentalJourney> hs = const [];
      try {
        // Lấy TẤT CẢ hồ sơ của sale trong một lượt: tranh chấp và hồ sơ đang
        // chờ sale gửi hợp đồng đều nằm trong đây.
        hs = await widget.api.list(view: 'sale');
      } catch (_) {
        hs = const [];
      }
      if (!mounted) return;
      setState(() {
        _hang = hang;
        _hoSo = hs;
        _dangTai = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được việc cần xử lý. Kéo xuống để thử lại.';
      });
    }
  }

  bool _quaHan(ViewingAppointmentModel a) {
    if (a.status != 'pending') return false;
    final d = DateTime.tryParse(a.bookingDate);
    return d != null &&
        d.isBefore(DateTime(_bayGio.year, _bayGio.month, _bayGio.day));
  }

  bool _homNay(ViewingAppointmentModel a) =>
      a.bookingDate == _isoNgay(_bayGio) && a.status == 'approved';

  static String _isoNgay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<ViewingAppointmentModel> get _moi => [
    for (final a in _hang)
      if (a.status == 'pending' && !_quaHan(a)) a,
  ];

  List<ViewingAppointmentModel> get _tre => [
    for (final a in _hang)
      if (_quaHan(a)) a,
  ];

  List<ViewingAppointmentModel> get _homNayDs => [
    for (final a in _hang)
      if (_homNay(a)) a,
  ];

  /// Sale đã đề xuất giờ khác — bóng đang ở chân KHÁCH, nhưng vẫn là việc dở
  /// của sale: khách im lặng thì phải gọi. Không xếp vào "Yêu cầu mới" để con
  /// số đầu màn không thổi phồng việc chưa ai chạm tới.
  List<ViewingAppointmentModel> get _choKhach => [
    for (final a in _hang)
      if (a.status == 'doi_gio') a,
  ];

  List<RentalJourney> get _tranhChap => [
    for (final h in _hoSo)
      if (h.status == RentalJourneyStatus.disputed) h,
  ];

  /// Hồ sơ khách đã chọn thuê, đang chờ SALE gửi hợp đồng + số tiền cọc.
  ///
  /// Trước đây màn "Gửi hồ sơ chốt thuê" chỉ mở được từ dòng lịch trong ngày
  /// diễn ra buổi xem — hôm sau là sale hết đường vào, hồ sơ nằm đó không ai
  /// đụng. Server đã nói rõ ai được làm gì (`available_actions`), app chỉ việc
  /// đọc.
  List<RentalJourney> get _choHopDong => [
    for (final h in _hoSo)
      if (h.can(RentalJourneyAction.uploadContract)) h,
  ];

  /// Nhãn + màu của một dòng việc, suy từ trạng thái thật của lịch hẹn.
  (String, Color) _nhanViec(ViewingAppointmentModel a) {
    if (a.status == 'doi_gio') return ('Chờ khách', HD.svcPurple);
    if (_quaHan(a)) return ('Quá hạn', HD.svcOrange);
    return ('Mới', HD.svcBlue);
  }

  @override
  Widget build(BuildContext context) {
    final viec = [..._tre, ..._moi, ..._choKhach];
    return Scaffold(
      backgroundColor: HD.paper,
      body: SafeArea(
        child: _dangTai
            ? const Center(child: CircularProgressIndicator(color: HD.accent))
            : RefreshIndicator(
                color: HD.accent,
                onRefresh: _nap,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    HD.s16,
                    HD.s8,
                    HD.s16,
                    HD.s24,
                  ),
                  children: [
                    _dongDau(),
                    const SizedBox(height: HD.s16),
                    _theHomNay(),
                    const SizedBox(height: HD.s12),
                    Row(
                      children: [
                        Expanded(
                          child: _oDem(
                            khoa: 'yeu-cau-moi',
                            icon: Icons.person_add_alt,
                            mau: HD.svcBlue,
                            so: _moi.length,
                            nhan: 'Yêu cầu mới',
                          ),
                        ),
                        const SizedBox(width: HD.s12),
                        Expanded(
                          child: _oDem(
                            khoa: 'qua-han',
                            icon: Icons.hourglass_bottom,
                            mau: HD.svcOrange,
                            so: _tre.length,
                            nhan: 'Quá hạn xác nhận',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: HD.s12),
                    Row(
                      children: [
                        Expanded(
                          child: _oDem(
                            khoa: 'tranh-chap',
                            icon: Icons.gavel,
                            mau: HD.accent,
                            so: _tranhChap.length,
                            nhan: 'Tranh chấp',
                          ),
                        ),
                        const SizedBox(width: HD.s12),
                        Expanded(
                          child: _oDem(
                            khoa: 'lich-hom-nay',
                            icon: Icons.event_note,
                            mau: HD.positive,
                            so: _homNayDs.length,
                            nhan: 'Lịch xem hôm nay',
                            onTap: _moLichHomNay,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: HD.s20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Việc cần xử lý',
                            style: HD.bodyBold(size: 16),
                          ),
                        ),
                        if (viec.isNotEmpty)
                          TextButton(
                            key: const Key('sale-xem-tat-ca'),
                            onPressed: _moLichHomNay,
                            child: Text(
                              'Xem tất cả',
                              style: HD.bodyBold(size: 12.5, color: HD.accent),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: HD.s8),
                    if (viec.isEmpty)
                      _rong()
                    else
                      for (final a in viec.take(10)) _dongViec(a),
                    if (_choHopDong.isNotEmpty) ...[
                      const SizedBox(height: HD.s20),
                      Text('Hồ sơ chốt thuê', style: HD.bodyBold(size: 16)),
                      const SizedBox(height: HD.s4),
                      Text(
                        'Khách đã đồng ý thuê — gửi hợp đồng và số tiền cọc '
                        'để hai bên chuyển khoản.',
                        style: HD.body(size: 12.5, color: HD.inkMuted),
                      ),
                      const SizedBox(height: HD.s8),
                      for (final h in _choHopDong) _dongHoSo(h),
                    ],
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
    );
  }

  void _moLichHomNay() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          LichXemHomNayScreen(api: widget.api, bayGio: widget.bayGio),
    ),
  );

  Widget _dongDau() => Row(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: HD.accent,
          borderRadius: BorderRadius.circular(HD.r8),
        ),
        child: const Icon(Icons.home_rounded, size: 20, color: Colors.white),
      ),
      const SizedBox(width: HD.s8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vua Nhà', style: HD.bodyBold(size: 15)),
            Text(
              'Xin chào, ${widget.tenSale ?? 'bạn'}',
              style: HD.body(size: 12, color: HD.inkMuted),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: HD.accentTint,
          borderRadius: BorderRadius.circular(HD.rPill),
        ),
        child: Text('SALE', style: HD.bodyBold(size: 10.5, color: HD.accent)),
      ),
    ],
  );

  Widget _theHomNay() => Container(
    padding: const EdgeInsets.all(HD.s16),
    decoration: BoxDecoration(
      color: HD.accent,
      borderRadius: BorderRadius.circular(HD.r12 + 4),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hôm nay',
                style: HD.bodyBold(size: 18, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'Cùng tìm đúng người, đúng ngôi nhà',
                style: HD.body(size: 12.5, color: Colors.white),
              ),
            ],
          ),
        ),
        const Icon(Icons.house_rounded, size: 40, color: Colors.white),
      ],
    ),
  );

  Widget _oDem({
    required String khoa,
    required IconData icon,
    required Color mau,
    required int so,
    required String nhan,
    VoidCallback? onTap,
  }) => InkWell(
    key: Key('sale-dem-$khoa'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(HD.r12),
    child: Container(
      padding: const EdgeInsets.all(HD.s12),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(HD.r12),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: mau.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(HD.r8),
            ),
            child: Icon(icon, size: 17, color: mau),
          ),
          const SizedBox(width: HD.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$so', style: HD.bodyBold(size: 18, color: mau)),
                Text(
                  nhan,
                  maxLines: 2,
                  style: HD.body(size: 11.5, color: HD.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _dongViec(ViewingAppointmentModel a) {
    final (nhan, mau) = _nhanViec(a);
    return Padding(
      padding: const EdgeInsets.only(bottom: HD.s8),
      child: InkWell(
        key: Key('sale-viec-${a.id}'),
        onTap: () => Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => ChiTietYeuCauKhachScreen(appointmentId: a.id!),
              ),
            )
            .then((_) => _nap()),
        borderRadius: BorderRadius.circular(HD.r12),
        child: Container(
          padding: const EdgeInsets.all(HD.s12),
          decoration: BoxDecoration(
            color: HD.paperRaised,
            borderRadius: BorderRadius.circular(HD.r12),
            border: Border.all(color: HD.hairline),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: mau.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(HD.r8),
                ),
                child: Text(nhan, style: HD.bodyBold(size: 11, color: mau)),
              ),
              const SizedBox(width: HD.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'KH-${a.id}',
                            style: HD.bodyBold(size: 13),
                          ),
                        ),
                        Text(
                          _truoc(a.createdAt),
                          style: HD.body(size: 11, color: HD.inkMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.guestName ?? 'Khách',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(size: 12.5, color: HD.inkSoft),
                    ),
                    Text(
                      a.houseTitle ?? 'Tin đã gỡ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(size: 12, color: HD.inkMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: HD.inkMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dongHoSo(RentalJourney h) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: InkWell(
      key: Key('sale-ho-so-${h.id}'),
      onTap: () => Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => GuiHoSoChotThueScreen(journeyId: h.id),
            ),
          )
          .then((_) => _nap()),
      borderRadius: BorderRadius.circular(HD.r12),
      child: Container(
        padding: const EdgeInsets.all(HD.s12),
        decoration: BoxDecoration(
          color: HD.accentTint,
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: HD.accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, size: 20, color: HD.accent),
            const SizedBox(width: HD.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.customer.name, style: HD.bodyBold(size: 13)),
                  Text(
                    h.subject.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 12, color: HD.inkSoft),
                  ),
                ],
              ),
            ),
            Text(
              'Gửi hợp đồng',
              style: HD.bodyBold(size: 12, color: HD.accent),
            ),
            const Icon(Icons.chevron_right, size: 18, color: HD.accent),
          ],
        ),
      ),
    ),
  );

  Widget _rong() => Container(
    padding: const EdgeInsets.all(HD.s20),
    alignment: Alignment.center,
    child: Column(
      children: [
        const Icon(Icons.inbox_outlined, size: 34, color: HD.inkMuted),
        const SizedBox(height: HD.s8),
        Text('Không có việc nào đang chờ', style: HD.bodyBold(size: 14)),
        const SizedBox(height: 2),
        Text(
          'Yêu cầu xem nhà mới sẽ hiện ở đây.',
          style: HD.body(size: 12.5, color: HD.inkMuted),
        ),
      ],
    ),
  );

  String _truoc(DateTime luc) {
    final p = _bayGio.difference(luc);
    if (p.inMinutes < 60) return '${p.inMinutes} phút trước';
    if (p.inHours < 24) return '${p.inHours} giờ trước';
    return '${p.inDays} ngày trước';
  }
}
