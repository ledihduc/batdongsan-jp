// ignore_for_file: unused_element

import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/repositories/api_viewing_appointment_repository.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/features/sale/gui_ho_so_chot_thue_screen.dart';
import 'package:house_booking/features/shared/viewing_detail_widgets.dart';

/// MÀN 5 của SALE — "Sau buổi xem" (mockup SALE, 20/09/2026).
///
/// SALE KHÔNG TỰ CHỐT. Server chỉ cho KHÁCH ghi "muốn thuê / không phù hợp"
/// (`/rental-journeys/from-appointment/{id}/viewing-result` đòi đúng tài khoản
/// khách), nên ở đây sale:
///   * đánh dấu buổi xem ĐÃ DIỄN RA (`PATCH /status` → completed) — việc sale
///     có quyền làm và là điều kiện để khách gửi kết quả;
///   * ghi nhận kết quả quan sát được, gửi kèm khi tố cáo;
///   * tố cáo khách (`POST /rental-journeys/{id}/reports`) khi đã có hồ sơ thuê.
///
/// Hồ sơ thuê chỉ tồn tại sau khi khách bấm "Tôi muốn thuê", nên nút gửi hồ sơ
/// chốt thuê chỉ bật khi thật sự có hồ sơ — không vẽ nút chết.
class SauBuoiXemScreen extends StatefulWidget {
  const SauBuoiXemScreen({
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
  State<SauBuoiXemScreen> createState() => _SauBuoiXemScreenState();
}

/// Năm kết quả trong mockup, đúng thứ tự.
const _ketQua = <String>[
  'Khách quan tâm',
  'Khách không đến (no show)',
  'Khách đến muộn',
  'Khách huỷ lịch',
  'Khách không quan tâm',
];

/// Kết quả → mã tố cáo của server (`ReportJourneyIn.reason_code`).
const _maToCao = <String, String>{
  'Khách không đến (no show)': 'CUSTOMER_NO_SHOW',
  'Khách đến muộn': 'CUSTOMER_LATE',
};

class _SauBuoiXemScreenState extends State<SauBuoiXemScreen> {
  final _ghiChu = TextEditingController();
  PhieuHen? _p;
  RentalJourney? _hoSo;
  String? _chon;
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
        final ds = await widget.journeyApi.list(view: 'sale');
        for (final x in ds) {
          if (x.appointmentId == widget.appointmentId) hs = x;
        }
      } catch (_) {
        hs = null;
      }
      if (!mounted) return;
      setState(() {
        _p = p;
        _hoSo = hs;
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
    if (_chon == null || _dangGui) return;
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      // 1) Buổi xem đã diễn ra → chuyển trạng thái, để khách gửi được kết quả.
      if (_p?.trangThai != 'completed') {
        await (widget.lichRepo ?? ApiViewingAppointmentRepository())
            .updateAppointmentStatus(widget.appointmentId, 'completed');
      }
      // 2) Kết quả xấu + đã có hồ sơ thuê → gửi luôn báo cáo có bằng chứng.
      final ma = _maToCao[_chon!];
      final hs = _hoSo;
      if (ma != null && hs != null) {
        await widget.journeyApi.report(
          hs.id,
          reportedUserId: hs.customer.id,
          reasonCode: ma,
          detail: _ghiChu.text.trim().isEmpty
              ? _chon!
              : '${_chon!} — ${_ghiChu.text.trim()}',
        );
      }
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _xong = ma != null && hs != null
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
                  _trangThaiHoSo(_hoSo!)
                else ...[
                  Row(
                    children: [
                      Text(
                        'Ghi nhận sau buổi xem',
                        style: HD.bodyBold(size: 14),
                      ),
                      Text(
                        ' *',
                        style: HD.bodyBold(size: 14, color: HD.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: HD.s8),
                  for (final k in _ketQua) _oKetQua(k),
                  const SizedBox(height: HD.s12),
                  _hopKhongTuChot(),
                  const SizedBox(height: HD.s16),
                  Text('Ghi chú (tuỳ chọn)', style: HD.bodyBold(size: 14)),
                  const SizedBox(height: HD.s8),
                  TextField(
                    key: const Key('sale-ghi-chu'),
                    controller: _ghiChu,
                    maxLines: 4,
                    maxLength: 300,
                    decoration: InputDecoration(
                      hintText: 'Khách rất quan tâm, sẽ cân nhắc và phản hồi…',
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

  Widget _trangThaiHoSo(RentalJourney hs) {
    final muonThue =
        hs.status != RentalJourneyStatus.customerDeclined &&
        hs.status != RentalJourneyStatus.cancelled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Khách đã phản hồi kết quả chưa?', style: HD.bodyBold(size: 14)),
        const SizedBox(height: HD.s8),
        _dongPhanHoi('Khách muốn thuê', muonThue),
        _dongPhanHoi('Khách không thuê', !muonThue),
        _dongPhanHoi('Chưa phản hồi · Gửi nhắc', false),
        const SizedBox(height: HD.s12),
        Text('Tải lên hợp đồng thuê', style: HD.bodyBold(size: 14)),
        const SizedBox(height: HD.s8),
        ViewingSectionCard(
          child: Row(
            children: [
              const Icon(Icons.description_outlined, color: Color(0xFF173B75)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hs.contractUrls.isEmpty
                      ? 'Ảnh/PDF hợp đồng thuê (tối đa 10MB)'
                      : 'Đã tải ${hs.contractUrls.length} tệp hợp đồng',
                  style: HD.body(size: 12.5, color: HD.inkSoft),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: HD.s12),
        const ViewingStatusBox(
          icon: Icons.schedule,
          title: 'Chờ chốt thuê',
          message:
              'Khách hoặc chủ nhà bấm chốt là phòng chuyển sang đang thuê; '
              'hợp đồng và minh chứng cọc bổ sung sau cũng được.',
          color: HD.warning,
        ),
      ],
    );
  }

  Widget _dongPhanHoi(String nhan, bool chon) => Container(
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
        FilledButton.icon(
          key: const Key('sale-mo-ho-so-chot'),
          style: viewingPrimaryButton(),
          onPressed: hs.can(RentalJourneyAction.uploadContract)
              ? () => Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => GuiHoSoChotThueScreen(journeyId: hs.id),
                      ),
                    )
                    .then((_) => _nap())
              : null,
          icon: const Icon(Icons.send),
          label: Text(
            hs.can(RentalJourneyAction.uploadContract)
                ? 'Gửi hợp đồng cho khách'
                : 'Đã gửi hợp đồng · chờ khách',
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 14, color: HD.inkMuted),
            const SizedBox(width: 5),
            Text(
              'Sale không thể tự chốt thuê.',
              style: HD.body(size: 11.5, color: HD.inkMuted),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _dongInfo(String nhan, String chu) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s4),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(nhan, style: HD.body(size: 12.5, color: HD.inkMuted)),
        ),
        Expanded(child: Text(chu, style: HD.bodyBold(size: 13))),
      ],
    ),
  );

  Widget _oKetQua(String k) {
    final chon = _chon == k;
    final toCao = _maToCao.containsKey(k);
    return Padding(
      padding: const EdgeInsets.only(bottom: HD.s8),
      child: InkWell(
        key: Key('sale-kq-$k'),
        onTap: () => setState(() => _chon = k),
        borderRadius: BorderRadius.circular(HD.r12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HD.s12,
            vertical: HD.s12,
          ),
          decoration: BoxDecoration(
            color: chon
                ? (toCao ? HD.negativeTint : HD.positiveTint)
                : HD.paperRaised,
            borderRadius: BorderRadius.circular(HD.r12),
            border: Border.all(
              color: chon ? (toCao ? HD.negative : HD.positive) : HD.hairline,
            ),
          ),
          child: Row(
            children: [
              Icon(
                chon ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 19,
                color: chon ? (toCao ? HD.negative : HD.positive) : HD.inkMuted,
              ),
              const SizedBox(width: HD.s12),
              Expanded(
                child: Text(k, style: HD.body(size: 13, color: HD.ink)),
              ),
              if (toCao && chon && _hoSo != null)
                Text(
                  'sẽ gửi báo cáo',
                  style: HD.body(size: 11, color: HD.negative),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hopKhongTuChot() => Container(
    padding: const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: HD.svcBlue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(HD.r12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 16, color: HD.svcBlue),
        const SizedBox(width: HD.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Không tự chốt', style: HD.bodyBold(size: 12.5)),
              const SizedBox(height: 2),
              Text(
                'Bạn không thể tự xác nhận khách thuê. Căn cứ là xác nhận từ '
                'khách và hệ thống Vua Nhà.',
                style: HD.body(size: 12.5, color: HD.inkSoft),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _nutHoSo() => SizedBox(
    height: 46,
    child: OutlinedButton.icon(
      key: const Key('sale-mo-ho-so-chot'),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: HD.accent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HD.r12),
        ),
      ),
      onPressed: () => Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => GuiHoSoChotThueScreen(journeyId: _hoSo!.id),
            ),
          )
          .then((_) => _nap()),
      icon: const Icon(Icons.upload_file, size: 17, color: HD.accent),
      label: Text(
        'Gửi hồ sơ chốt thuê',
        style: HD.bodyBold(size: 13.5, color: HD.accent),
      ),
    ),
  );

  Widget _thanhLuu() => SafeArea(
    minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
    child: SizedBox(
      height: 50,
      child: FilledButton(
        key: const Key('sale-luu-ket-qua'),
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
