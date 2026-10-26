// ignore_for_file: unused_element

import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/repositories/api_viewing_appointment_repository.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/features/host/journey/xac_nhan_coc_chu_nha_screen.dart';
import 'package:house_booking/features/shared/viewing_detail_widgets.dart';

/// MÀN 5 của CHỦ NHÀ — "Kết quả buổi xem" (mockup CHỦ NHÀ, 20/09/2026).
///
/// Chủ nhà ghi buổi xem đã diễn ra thế nào. Giống bên sale: chủ nhà KHÔNG chốt
/// thay khách — server chỉ nhận "muốn thuê" từ chính tài khoản khách. Ở đây
/// chủ nhà:
///   * đánh dấu buổi xem đã diễn ra (`PATCH /status` → completed);
///   * gửi báo cáo khi khách không đến / sale đến trễ
///     (`POST /rental-journeys/{id}/reports`, cần đã có hồ sơ thuê).
class KetQuaBuoiXemChuNhaScreen extends StatefulWidget {
  const KetQuaBuoiXemChuNhaScreen({
    super.key,
    required this.appointmentId,
    this.api = const LichXemApi(),
    this.journeyApi = const RentalJourneyApi(),
    this.lichRepo,
  });

  final int appointmentId;
  final LichXemApi api;
  final RentalJourneyApi journeyApi;
  final ApiViewingAppointmentRepository? lichRepo;

  @override
  State<KetQuaBuoiXemChuNhaScreen> createState() =>
      _KetQuaBuoiXemChuNhaScreenState();
}

/// Kết quả thực tế sau buổi xem, gồm cả các ngoại lệ thường gặp để lịch không
/// bị treo ở trạng thái "đã xác nhận" vô thời hạn.
const _ketQua = <({String nhan, Color mau, String? ma, bool veSale})>[
  (
    nhan: 'Khách quan tâm, có thể tiến hành cọc',
    mau: HD.positive,
    ma: null,
    veSale: false,
  ),
  (nhan: 'Khách chưa phù hợp', mau: HD.inkSoft, ma: null, veSale: false),
  (
    nhan: 'Khách không đến (no-show)',
    mau: HD.negative,
    ma: 'CUSTOMER_NO_SHOW',
    veSale: false,
  ),
  (
    nhan: 'Chủ nhà không tiếp / không có mặt',
    mau: HD.warning,
    ma: 'OWNER_NO_SHOW',
    veSale: false,
  ),
  (nhan: 'Sale đến trễ', mau: HD.warning, ma: 'SALE_LATE', veSale: true),
  (
    nhan: 'Sale không xử lý kịp',
    mau: HD.warning,
    ma: 'SALE_NO_SHOW',
    veSale: true,
  ),
  (
    nhan: 'Có báo cáo / khiếu nại',
    mau: HD.negative,
    ma: 'VIEWING_COMPLAINT',
    veSale: false,
  ),
  (nhan: 'Khác', mau: HD.inkMuted, ma: null, veSale: false),
];

class _KetQuaBuoiXemChuNhaScreenState extends State<KetQuaBuoiXemChuNhaScreen> {
  final _ghiChu = TextEditingController();
  PhieuHen? _p;
  RentalJourney? _hoSo;
  String? _lyDoKhongThue;
  int? _chon;
  bool _dangTai = true;
  bool _dangGui = false;
  String? _loi;
  String? _xong;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void dispose() {
    _ghiChu.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    try {
      final p = await widget.api.phieu(widget.appointmentId);
      RentalJourney? hs;
      try {
        final ds = await widget.journeyApi.list(view: 'owner');
        for (final x in ds) {
          if (x.appointmentId == widget.appointmentId) hs = x;
        }
      } catch (_) {
        hs = null;
      }
      String? lyDoKhongThue;
      if (hs != null && hs.status == RentalJourneyStatus.customerDeclined) {
        try {
          final events = await widget.journeyApi.events(hs.id);
          for (final event in events.reversed) {
            if (event.viewingReason != null) {
              lyDoKhongThue = event.viewingReason;
              break;
            }
          }
        } catch (_) {
          lyDoKhongThue = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _p = p;
        _hoSo = hs;
        _lyDoKhongThue = lyDoKhongThue;
        _dangTai = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được buổi xem. Kéo xuống để thử lại.';
      });
    }
  }

  Future<void> _luu() async {
    final i = _chon;
    if (i == null || _dangGui) return;
    final kq = _ketQua[i];
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      if (_p?.trangThai != 'completed') {
        await (widget.lichRepo ?? ApiViewingAppointmentRepository())
            .updateAppointmentStatus(widget.appointmentId, 'completed');
      }
      final hs = _hoSo;
      if (kq.ma != null && hs != null) {
        await widget.journeyApi.report(
          hs.id,
          reportedUserId: kq.veSale
              ? (hs.sale?.id ?? hs.customer.id)
              : hs.customer.id,
          reasonCode: kq.ma!,
          detail: _ghiChu.text.trim().isEmpty
              ? kq.nhan
              : '${kq.nhan} — ${_ghiChu.text.trim()}',
        );
      }
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _xong = kq.ma != null && hs != null
            ? 'Đã lưu kết quả và gửi báo cáo cho Vua Nhà.'
            : 'Đã lưu kết quả buổi xem.';
      });
      await _nap();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = e is ApiException ? e.message : 'Chưa lưu được kết quả.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
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
          'Kết quả sau khi xem',
          style: HD.bodyBold(size: 17, color: Colors.white),
        ),
      ),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                HD.s16,
                HD.s12,
                HD.s16,
                HD.s24,
              ),
              children: [
                if (p != null) ...[
                  ViewingPropertyCard(phieu: p),
                  const SizedBox(height: HD.s16),
                ],
                if (_hoSo != null)
                  _ketQuaTuKhach(_hoSo!)
                else ...[
                  Text('Ghi nhận buổi xem', style: HD.bodyBold(size: 14)),
                  const SizedBox(height: HD.s8),
                  for (var i = 0; i < _ketQua.length; i++) _oKetQua(i),
                  const SizedBox(height: HD.s12),
                  Text('Ghi chú chi tiết', style: HD.bodyBold(size: 14)),
                  const SizedBox(height: HD.s8),
                  TextField(
                    key: const Key('chu-ghi-chu-ket-qua'),
                    controller: _ghiChu,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Nhập ghi chú về buổi xem…',
                      hintStyle: HD.body(size: 12.5, color: HD.inkMuted),
                      filled: true,
                      fillColor: HD.paperRaised,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(HD.r12),
                      ),
                    ),
                  ),
                ],
                if (_xong != null) ...[
                  const SizedBox(height: HD.s8),
                  Text(
                    _xong!,
                    style: HD.bodyBold(size: 12.5, color: HD.positive),
                  ),
                ],
                if (_loi != null) ...[
                  const SizedBox(height: HD.s8),
                  Text(_loi!, style: HD.body(size: 12.5, color: HD.negative)),
                ],
              ],
            ),
      bottomNavigationBar: _dangTai
          ? null
          : _hoSo == null
          ? _thanhLuu()
          : _thanhHoSo(_hoSo!),
    );
  }

  Widget _ketQuaTuKhach(RentalJourney hs) {
    final muonThue =
        hs.status != RentalJourneyStatus.customerDeclined &&
        hs.status != RentalJourneyStatus.cancelled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Kết quả của khách hàng', style: HD.bodyBold(size: 14)),
        const SizedBox(height: HD.s8),
        _dongKetQuaKhach('Khách muốn thuê', muonThue),
        _dongKetQuaKhach('Khách không thuê', !muonThue),
        _dongKetQuaKhach('Chưa phản hồi · Gửi nhắc', false),
        if (!muonThue) ...[
          const SizedBox(height: HD.s8),
          ViewingSectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: HD.accent),
                const SizedBox(width: HD.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lý do không thuê', style: HD.bodyBold(size: 12.5)),
                      const SizedBox(height: 2),
                      Text(
                        _lyDoKhongThue ?? 'Khách chưa cung cấp lý do',
                        style: HD.body(size: 12, color: HD.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: HD.s12),
        Text('Tải hợp đồng thuê (nếu có)', style: HD.bodyBold(size: 14)),
        const SizedBox(height: HD.s8),
        ViewingSectionCard(
          child: Row(
            children: [
              const Icon(Icons.description_outlined, color: Color(0xFF173B75)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hs.contractUrls.isEmpty
                      ? 'Hợp đồng chưa được Sale tải lên'
                      : 'Hợp đồng thuê · ${hs.contractUrls.length} tệp',
                  style: HD.body(size: 12.5, color: HD.inkSoft),
                ),
              ),
              const Icon(Icons.chevron_right, color: HD.inkMuted),
            ],
          ),
        ),
        const SizedBox(height: HD.s12),
        Text(
          'Xác nhận đã nhận cọc · 50% chủ nhà',
          style: HD.bodyBold(size: 13.5),
        ),
        const SizedBox(height: HD.s8),
        ViewingStatusBox(
          icon: Icons.schedule,
          title: hs.payment('OWNER_DEPOSIT')?.hasProof == true
              ? 'Khách đã gửi minh chứng cọc'
              : 'Chờ khách gửi minh chứng cọc',
          message:
              'Hồ sơ chỉ hoàn tất khi khách tự xác nhận thuê trên ứng dụng.',
          color: HD.warning,
        ),
      ],
    );
  }

  Widget _dongKetQuaKhach(String nhan, bool chon) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: 9),
    decoration: BoxDecoration(
      color: chon ? HD.positiveTint : Colors.white,
      borderRadius: BorderRadius.circular(HD.r8),
      border: Border.all(color: chon ? HD.positive : HD.hairline),
    ),
    child: Row(
      children: [
        Icon(
          chon ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 19,
          color: chon ? HD.positive : const Color(0xFF173B75),
        ),
        const SizedBox(width: HD.s8),
        Text(nhan, style: HD.body(size: 13, color: HD.ink)),
      ],
    ),
  );

  Widget _thanhHoSo(RentalJourney hs) => SafeArea(
    minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(
          key: const Key('chu-mo-xac-nhan-coc'),
          style: viewingPrimaryButton(),
          onPressed: hs.can(RentalJourneyAction.acknowledgeOwnerDeposit)
              ? () => Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) =>
                            XacNhanCocChuNhaScreen(journeyId: hs.id),
                      ),
                    )
                    .then((_) => _nap())
              : null,
          child: Text(
            hs.can(RentalJourneyAction.acknowledgeOwnerDeposit)
                ? 'Tôi đã nhận cọc'
                : 'Chờ minh chứng cọc từ khách',
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 14, color: HD.inkMuted),
            const SizedBox(width: 5),
            Text(
              'Chủ nhà không thể xác nhận thuê thay khách.',
              style: HD.body(size: 11.5, color: HD.inkMuted),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _dongNguoi(String ten, String vai) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: HD.paperSunken,
          child: const Icon(Icons.person, size: 16, color: HD.inkMuted),
        ),
        const SizedBox(width: HD.s8),
        Expanded(child: Text(ten, style: HD.bodyBold(size: 13))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: HD.paperSunken,
            borderRadius: BorderRadius.circular(HD.rPill),
          ),
          child: Text(vai, style: HD.body(size: 11, color: HD.inkSoft)),
        ),
      ],
    ),
  );

  Widget _oKetQua(int i) {
    final k = _ketQua[i];
    final chon = _chon == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: HD.s8),
      child: InkWell(
        key: Key('chu-kq-$i'),
        onTap: () => setState(() => _chon = i),
        borderRadius: BorderRadius.circular(HD.r12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HD.s12,
            vertical: HD.s12,
          ),
          decoration: BoxDecoration(
            color: chon ? k.mau.withValues(alpha: 0.1) : HD.paperRaised,
            borderRadius: BorderRadius.circular(HD.r12),
            border: Border.all(color: chon ? k.mau : HD.hairline),
          ),
          child: Row(
            children: [
              Icon(
                chon ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 19,
                color: chon ? k.mau : HD.inkMuted,
              ),
              const SizedBox(width: HD.s12),
              Expanded(
                child: Text(k.nhan, style: HD.body(size: 13, color: HD.ink)),
              ),
              if (k.ma != null && chon && _hoSo != null)
                Text('sẽ gửi báo cáo', style: HD.body(size: 11, color: k.mau)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thanhLuu() => SafeArea(
    minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
    child: SizedBox(
      height: 50,
      child: FilledButton(
        key: const Key('chu-luu-ket-qua'),
        style: FilledButton.styleFrom(
          backgroundColor: HD.accent,
          disabledBackgroundColor: HD.accent.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HD.r12),
          ),
        ),
        onPressed: _chon == null || _dangGui ? null : _luu,
        child: _dangGui
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Lưu kết quả',
                style: HD.bodyBold(size: 15, color: Colors.white),
              ),
      ),
    ),
  );
}
