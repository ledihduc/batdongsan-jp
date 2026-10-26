import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/repositories/api_viewing_appointment_repository.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/data/services/management_read_model_api.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/data/services/viewing_v2_api.dart';
import 'package:house_booking/features/guest/booking/xac_nhan_muon_thue_screen.dart';
import 'package:house_booking/features/shared/viewing_detail_widgets.dart';

/// MÀN 5 — "Kết quả sau khi xem phòng" (mockup KHÁCH THUÊ, 20/09/2026).
///
/// Một câu hỏi, hai lối đi:
///   * "Tôi muốn thuê"      → mở hồ sơ thuê (`INTERESTED`) → [CocXacNhanThueScreen]
///   * "Không phù hợp / Huỷ" → `NOT_INTERESTED` kèm lý do (chọn chip, không bắt gõ)
///
/// API: `POST /api/rental-journeys/from-appointment/{id}/viewing-result`.
/// Lý do là tuỳ chọn — bắt buộc nêu lý do mới cho huỷ là ép người ta bịa.
class KetQuaSauXemScreen extends StatefulWidget {
  const KetQuaSauXemScreen({
    super.key,
    required this.appointmentId,
    this.api = const RentalJourneyApi(),
    this.phieu,
    this.lichRepo,
    this.managementApi,
    this.viewingV2Api = const ViewingV2Api(),
  });

  final int appointmentId;
  final RentalJourneyApi api;
  final PhieuHen? phieu;
  final ApiViewingAppointmentRepository? lichRepo;
  final ManagementReadModelApi? managementApi;
  final ViewingV2Api viewingV2Api;

  @override
  State<KetQuaSauXemScreen> createState() => _KetQuaSauXemScreenState();
}

/// Sáu nhóm lý do chuẩn. Backend lưu nguyên nhãn để Chủ nhà/Sale có thể lọc
/// báo cáo thay vì phải tổng hợp nhiều câu chữ gần nghĩa.
const _lyDo = <String>[
  'Không phù hợp nhu cầu',
  'Giá không phù hợp',
  'Khách đổi ý',
  'Chủ nhà không đồng ý',
  'Không chốt được điều khoản',
  'Khác',
];

class _KetQuaSauXemScreenState extends State<KetQuaSauXemScreen> {
  final Set<String> _chon = {};
  bool _dangGui = false;
  String? _loi;
  String? _camNhan;

  void _chonCamNhan(String value) {
    if (widget.phieu == null) {
      _gui(muonThue: value == 'muon_thue');
      return;
    }
    setState(() => _camNhan = value);
  }

  Future<void> _guiKetQua() async {
    if (_camNhan == 'can_nhac') {
      if (_dangGui) return;
      setState(() => _dangGui = true);
      try {
        ManagementCapabilities? caps;
        try {
          caps = await widget.managementApi?.capabilities();
        } catch (_) {}
        if (caps?.viewingV2Enabled == true &&
            caps?.viewingV2WritesEnabled == true) {
          await widget.viewingV2Api.submitResult(
            widget.appointmentId,
            status: 'CONSIDERING',
          );
        } else {
          await (widget.lichRepo ?? ApiViewingAppointmentRepository())
              .updateAppointmentStatus(widget.appointmentId, 'awaiting_guest');
        }
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu. Vua Nhà sẽ nhắc bạn phản hồi sau.'),
          ),
        );
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _dangGui = false;
          _loi = 'Chưa lưu được trạng thái cân nhắc. Vui lòng thử lại.';
        });
      }
      return;
    }
    if (_camNhan != null) await _gui(muonThue: _camNhan == 'muon_thue');
  }

  Future<void> _gui({required bool muonThue}) async {
    if (_dangGui) return;
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      ManagementCapabilities? caps;
      try {
        caps = await widget.managementApi?.capabilities();
      } catch (_) {}
      RentalJourney? hs;
      if (caps?.viewingV2Enabled == true &&
          caps?.viewingV2WritesEnabled == true) {
        final result = await widget.viewingV2Api.submitResult(
          widget.appointmentId,
          status: muonThue ? 'INTERESTED' : 'DECLINED',
          reasonCode: muonThue ? null : _reasonCode(_chon),
          reasonNote: _chon.isEmpty ? null : _chon.join(', '),
        );
        if (muonThue && result.rentalJourneyId != null) {
          hs = await widget.api.detail(result.rentalJourneyId!);
        }
      } else {
        hs = await widget.api.submitViewingResult(
          widget.appointmentId,
          interested: muonThue,
          reason: _chon.isEmpty ? null : _chon.join(', '),
        );
      }
      if (!mounted) return;
      if (muonThue) {
        if (hs == null) throw StateError('Chưa tạo được hồ sơ thuê');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                XacNhanMuonThueScreen(journey: hs!, phieu: widget.phieu),
          ),
        );
        return;
      }
      Navigator.of(context).pop(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã ghi nhận. Cảm ơn phản hồi của bạn!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = 'Chưa gửi được kết quả. Thử lại giúp em.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HD.paper,
    appBar: AppBar(
      backgroundColor: HD.accent,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: const BackButton(color: Colors.white),
      title: Text(
        'Kết quả xem phòng',
        style: HD.bodyBold(size: 17, color: Colors.white),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s24),
      children: [
        if (widget.phieu != null) ...[
          ViewingPropertyCard(phieu: widget.phieu!),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
        ],
        Text('Cảm ơn bạn đã xem phòng!', style: HD.bodyBold(size: 16)),
        const SizedBox(height: HD.s4),
        Text(
          'Căn phòng này có phù hợp với nhu cầu của bạn không?',
          style: HD.body(size: 13, color: HD.inkSoft),
        ),
        const SizedBox(height: HD.s16),
        Row(
          children: [
            Expanded(
              child: _oCamNhan(
                key: const Key('ket-qua-khong-phu-hop'),
                value: 'khong_phu_hop',
                icon: Icons.sentiment_dissatisfied_outlined,
                title: 'Không phù hợp',
                subtitle: 'Không đúng nhu cầu',
              ),
            ),
            const SizedBox(width: HD.s8),
            Expanded(
              child: _oCamNhan(
                value: 'can_nhac',
                icon: Icons.sentiment_neutral_outlined,
                title: 'Đang cân nhắc',
                subtitle: 'Cần thêm thời gian',
              ),
            ),
            const SizedBox(width: HD.s8),
            Expanded(
              child: _oCamNhan(
                key: const Key('ket-qua-muon-thue'),
                value: 'muon_thue',
                icon: Icons.favorite,
                title: 'Muốn thuê',
                subtitle: 'Rất phù hợp',
              ),
            ),
          ],
        ),
        const SizedBox(height: HD.s16),
        Container(
          padding: const EdgeInsets.all(HD.s12),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F7FF),
            borderRadius: BorderRadius.circular(HD.r8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info, color: HD.svcBlue),
              const SizedBox(width: HD.s8),
              Expanded(
                child: Text(
                  'Thông tin sai, hẹn đến muộn hoặc bị tự ý chốt phòng?',
                  style: HD.bodyBold(size: 12.5, color: HD.svcBlue),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: HD.s16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Bạn có gặp vấn đề gì không?', style: HD.bodyBold(size: 14)),
            const SizedBox(width: 4),
            Text('(tuỳ chọn)', style: HD.body(size: 12, color: HD.inkMuted)),
          ],
        ),
        const SizedBox(height: HD.s12),
        Wrap(
          spacing: HD.s8,
          runSpacing: HD.s8,
          children: [
            for (final l in _lyDo)
              _ChipLyDo(
                nhan: l,
                chon: _chon.contains(l),
                onTap: () => setState(
                  () => _chon.contains(l) ? _chon.remove(l) : _chon.add(l),
                ),
              ),
          ],
        ),
        const SizedBox(height: HD.s20),
        Container(
          padding: const EdgeInsets.all(HD.s12),
          decoration: BoxDecoration(
            color: HD.accentTint,
            borderRadius: BorderRadius.circular(HD.r12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite, size: 14, color: HD.accent),
                  const SizedBox(width: 4),
                  Text(
                    'Cảm ơn phản hồi của bạn!',
                    style: HD.bodyBold(size: 12.5, color: HD.accent),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Chúng tôi sẽ tiếp tục gợi ý những căn phù hợp hơn trong thời '
                'gian tới.',
                style: HD.body(size: 12.5, color: HD.inkSoft),
              ),
            ],
          ),
        ),
        if (_loi != null) ...[
          const SizedBox(height: HD.s12),
          Text(_loi!, style: HD.body(size: 12.5, color: HD.negative)),
        ],
      ],
    ),
    bottomNavigationBar: widget.phieu == null
        ? null
        : SafeArea(
            minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
            child: FilledButton.icon(
              key: const Key('gui-ket-qua-xem'),
              style: viewingPrimaryButton(),
              onPressed: _camNhan == null || _dangGui ? null : _guiKetQua,
              icon: const Icon(Icons.event_available, size: 18),
              label: Text(_dangGui ? 'Đang gửi' : 'Gửi kết quả'),
            ),
          ),
  );

  Widget _oCamNhan({
    Key? key,
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _camNhan == value;
    return InkWell(
      key: key,
      onTap: _dangGui ? null : () => _chonCamNhan(value),
      borderRadius: BorderRadius.circular(HD.r8),
      child: Container(
        height: 108,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? HD.accentTint : Colors.white,
          borderRadius: BorderRadius.circular(HD.r8),
          border: Border.all(color: selected ? HD.accent : HD.hairline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: selected ? HD.accent : HD.inkMuted),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: HD.bodyBold(size: 11.5),
            ),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: HD.body(size: 9.5, color: HD.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

String _reasonCode(Set<String> reasons) {
  if (reasons.contains('Không phù hợp nhu cầu')) return 'NEED_MISMATCH';
  if (reasons.contains('Giá không phù hợp')) return 'PRICE_MISMATCH';
  if (reasons.contains('Khách đổi ý')) return 'CUSTOMER_CHANGED_MIND';
  if (reasons.contains('Chủ nhà không đồng ý')) return 'OWNER_DECLINED';
  if (reasons.contains('Không chốt được điều khoản')) return 'TERMS_NOT_AGREED';
  return 'OTHER';
}

class _ChipLyDo extends StatelessWidget {
  const _ChipLyDo({
    required this.nhan,
    required this.chon,
    required this.onTap,
  });

  final String nhan;
  final bool chon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('ly-do-$nhan'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(HD.rPill),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: HD.s8),
      decoration: BoxDecoration(
        color: chon ? HD.accentTint : HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.rPill),
        border: Border.all(color: chon ? HD.accent : HD.hairline),
      ),
      child: Text(
        nhan,
        style: HD.body(size: 12.5, color: chon ? HD.accent : HD.inkSoft),
      ),
    ),
  );
}
