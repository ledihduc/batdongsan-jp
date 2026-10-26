import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/features/host/journey/chi_tiet_yeu_cau_xem_screen.dart';
import 'package:house_booking/features/host/journey/lich_xem_hom_nay_chu_nha_screen.dart';
import 'package:house_booking/features/host/journey/xac_nhan_coc_chu_nha_screen.dart';

/// MÀN 1 của CHỦ NHÀ — "Tổng quan chủ nhà" (mockup CHỦ NHÀ, 20/09/2026).
///
/// Ba việc chủ nhà phải làm, xếp đúng thứ tự gấp: yêu cầu xem phòng đang chờ
/// mình xác nhận · lịch xem hôm nay · hồ sơ đang chờ mình xác nhận đã nhận cọc.
///
/// Nguồn: `work-queue?view=owner` và `GET /api/rental-journeys?view=owner`
/// (lọc hồ sơ có hành động `ACKNOWLEDGE_OWNER_DEPOSIT` — server tự quyết ai
/// được làm gì, app chỉ đọc danh sách hành động đó).
class TongQuanXemNhaScreen extends StatefulWidget {
  const TongQuanXemNhaScreen({
    super.key,
    this.api = const RentalJourneyApi(),
    this.tenChuNha,
    this.bayGio,
  });

  final RentalJourneyApi api;
  final String? tenChuNha;
  final DateTime? bayGio;

  @override
  State<TongQuanXemNhaScreen> createState() => _TongQuanXemNhaScreenState();
}

class _TongQuanXemNhaScreenState extends State<TongQuanXemNhaScreen> {
  List<ViewingAppointmentModel> _hang = const [];
  List<RentalJourney> _hoSo = const [];
  bool _dangTai = true;
  String? _loi;

  DateTime get _bayGio => widget.bayGio ?? DateTime.now();

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    setState(() => _loi = null);
    try {
      final hang = await widget.api.workQueue(view: 'owner');
      List<RentalJourney> hs = const [];
      try {
        hs = await widget.api.list(view: 'owner');
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
        _loi = 'Chưa tải được tổng quan. Kéo xuống để thử lại.';
      });
    }
  }

  List<ViewingAppointmentModel> get _cho => [
    for (final a in _hang)
      if (a.status == 'pending') a,
  ];

  List<ViewingAppointmentModel> get _homNay => [
    for (final a in _hang)
      if (a.bookingDate == _iso(_bayGio) && a.status != 'cancelled') a,
  ];

  /// Nhãn trạng thái của một dòng lịch. Trước đây mọi trạng thái KHÁC
  /// `approved` đều hiện "Chờ xác nhận" — lịch đã chốt thuê hay khách đang
  /// chọn lại giờ vẫn bị gọi là chờ chủ nhà, tức là bảo người ta làm lại việc
  /// đã xong.
  static (String, Color) _nhanLich(String s) => switch (s) {
    'approved' => ('Đã xác nhận', HD.positive),
    'completed' => ('Đã xem xong', HD.inkSoft),
    'locked' => ('Đã chốt thuê', HD.positive),
    'awaiting_guest' => ('Chờ khách trả lời', HD.svcPurple),
    'doi_gio' => ('Chờ khách chọn giờ', HD.svcPurple),
    'rejected' => ('Đã từ chối', HD.inkSoft),
    'cancelled' => ('Đã huỷ', HD.inkSoft),
    _ => ('Chờ xác nhận', HD.svcOrange),
  };

  List<RentalJourney> get _choCoc => [
    for (final h in _hoSo)
      if (h.availableActions.contains(
        RentalJourneyAction.acknowledgeOwnerDeposit,
      ))
        h,
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
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
                  Row(
                    children: [
                      Expanded(
                        child: _oDem(
                          khoa: 'yeu-cau-cho',
                          icon: Icons.mark_email_unread_outlined,
                          mau: HD.svcOrange,
                          so: _cho.length,
                          nhan: 'Yêu cầu xem đang chờ',
                        ),
                      ),
                      const SizedBox(width: HD.s12),
                      Expanded(
                        child: _oDem(
                          khoa: 'lich-hom-nay',
                          icon: Icons.event_note,
                          mau: HD.svcBlue,
                          so: _homNay.length,
                          nhan: 'Lịch xem hôm nay',
                          onTap: () => Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => LichXemHomNayChuNhaScreen(
                                    api: widget.api,
                                    bayGio: widget.bayGio,
                                  ),
                                ),
                              )
                              .then((_) => _nap()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: HD.s12),
                  _oDem(
                    khoa: 'cho-coc',
                    icon: Icons.account_balance_wallet_outlined,
                    mau: HD.accent,
                    so: _choCoc.length,
                    nhan: 'Đang chờ bạn xác nhận cọc',
                  ),
                  const SizedBox(height: HD.s20),
                  _tieuDeMuc('Yêu cầu xem phòng', _cho.length),
                  if (_cho.isEmpty)
                    _rong('Không có yêu cầu nào đang chờ bạn.')
                  else
                    for (final a in _cho.take(5)) _dongYeuCau(a),
                  const SizedBox(height: HD.s16),
                  _tieuDeMuc('Lịch xem hôm nay', _homNay.length),
                  if (_homNay.isEmpty)
                    _rong('Hôm nay không có lịch xem nào.')
                  else
                    for (final a in _homNay.take(5)) _dongLich(a),
                  const SizedBox(height: HD.s16),
                  _tieuDeMuc('Xác nhận cọc', _choCoc.length),
                  if (_choCoc.isEmpty)
                    _rong('Chưa có khoản cọc nào chờ bạn xác nhận.')
                  else
                    for (final h in _choCoc) _dongCoc(h),
                  if (_loi != null) ...[
                    const SizedBox(height: HD.s12),
                    Text(_loi!, style: HD.body(size: 12.5, color: HD.negative)),
                  ],
                ],
              ),
            ),
    ),
  );

  Widget _dongDau() => Row(
    children: [
      CircleAvatar(
        radius: 22,
        backgroundColor: HD.accentTint,
        child: Text('CN', style: HD.bodyBold(size: 14, color: HD.accent)),
      ),
      const SizedBox(width: HD.s12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chủ nhà', style: HD.bodyBold(size: 15)),
            Text(
              widget.tenChuNha == null
                  ? 'Chào mừng bạn trở lại!'
                  : 'Chào ${widget.tenChuNha}, chào mừng bạn trở lại!',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HD.body(size: 12, color: HD.inkMuted),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _tieuDeMuc(String ten, int so) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: Text('$ten ($so)', style: HD.bodyBold(size: 15)),
  );

  Widget _oDem({
    required String khoa,
    required IconData icon,
    required Color mau,
    required int so,
    required String nhan,
    VoidCallback? onTap,
  }) => InkWell(
    key: Key('chu-dem-$khoa'),
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
                Text(nhan, style: HD.body(size: 11.5, color: HD.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _dongYeuCau(ViewingAppointmentModel a) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: InkWell(
      key: Key('chu-yeu-cau-${a.id}'),
      onTap: () => Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => ChiTietYeuCauXemScreen(appointmentId: a.id!),
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
            CircleAvatar(
              radius: 18,
              backgroundColor: HD.paperSunken,
              child: const Icon(Icons.person, size: 18, color: HD.inkMuted),
            ),
            const SizedBox(width: HD.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.guestName ?? 'Khách',
                          style: HD.bodyBold(size: 13.5),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: HD.warningTint,
                          borderRadius: BorderRadius.circular(HD.rPill),
                        ),
                        child: Text(
                          'Mới',
                          style: HD.bodyBold(size: 10.5, color: HD.warning),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    a.houseTitle ?? 'Tin đã gỡ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 12, color: HD.inkMuted),
                  ),
                  Text(
                    'Muốn xem: ${_ngayNgan(a.bookingDate)} · ${a.bookingTime}',
                    style: HD.body(size: 12, color: HD.inkSoft),
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

  Widget _dongLich(ViewingAppointmentModel a) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            a.bookingTime.split('-').first,
            style: HD.bodyBold(size: 13),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.guestName ?? 'Khách', style: HD.bodyBold(size: 13)),
              Text(
                a.houseTitle ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.body(size: 12, color: HD.inkMuted),
              ),
            ],
          ),
        ),
        Builder(
          builder: (_) {
            final (nhan, mau) = _nhanLich(a.status);
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: mau.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(HD.rPill),
              ),
              child: Text(nhan, style: HD.bodyBold(size: 11, color: mau)),
            );
          },
        ),
      ],
    ),
  );

  Widget _dongCoc(RentalJourney h) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: InkWell(
      key: Key('chu-coc-${h.id}'),
      onTap: () => Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) =>
                  XacNhanCocChuNhaScreen(journeyId: h.id, api: widget.api),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.customer.name, style: HD.bodyBold(size: 13.5)),
                  Text(
                    h.subject.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              child: Text(
                'Chờ bạn xác nhận',
                style: HD.bodyBold(size: 11, color: HD.accent),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _rong(String chu) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: Text(chu, style: HD.body(size: 12.5, color: HD.inkMuted)),
  );

  static String _ngayNgan(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final thu = d.weekday == DateTime.sunday ? 'CN' : 'T${d.weekday + 1}';
    return '$thu ${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}';
  }
}
