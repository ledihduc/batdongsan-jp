import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/features/shared/rental_journey_compact_widgets.dart';
import 'package:house_booking/providers/chat_provider.dart';

/// MÀN 6 của CHỦ NHÀ — "Xác nhận cọc" (mockup CHỦ NHÀ, 20/09/2026).
///
/// Chủ nhà xem minh chứng khách đã chuyển 50% cọc cho mình rồi bấm "Đã nhận
/// cọc" (`POST /rental-journeys/{id}/payments/OWNER_DEPOSIT/acknowledge`).
///
/// Từ 23/09/2026 màn này còn là chỗ CHỐT THUÊ: đủ hợp đồng + hai minh chứng
/// cọc thì chủ nhà bấm "Nhận khách vào ở" (`POST /rental-journeys/{id}/confirm`)
/// mà không phải chờ khách mở app — ai bấm trước cũng xong. Bấm xong là hợp
/// đồng hiệu lực và phòng sang "đang thuê" thật, không dừng ở hợp đồng nháp.
///
/// Các bước dưới cùng là TRẠNG THÁI THẬT của hồ sơ. Không vẽ bước đã xong khi
/// server chưa ghi nhận.
class XacNhanCocChuNhaScreen extends StatefulWidget {
  const XacNhanCocChuNhaScreen({
    super.key,
    required this.journeyId,
    this.api = const RentalJourneyApi(),
  });

  final int journeyId;
  final RentalJourneyApi api;

  @override
  State<XacNhanCocChuNhaScreen> createState() => _XacNhanCocChuNhaScreenState();
}

class _XacNhanCocChuNhaScreenState extends State<XacNhanCocChuNhaScreen> {
  RentalJourney? _hs;
  bool _dangTai = true;
  bool _dangNap = false;
  bool _dangGui = false;
  String? _loi;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  bool _daNoiRealtime = false;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_daNoiRealtime) return;
    _daNoiRealtime = true;
    try {
      _statusSub = context.read<ChatProvider>().statusEvents.listen((event) {
        final id = (event['entity_id'] as num?)?.toInt();
        if (event['entity'] == 'rental_journey' && id == widget.journeyId) {
          _nap();
        }
      });
    } catch (_) {
      // Widget tests may mount this screen without ChatProvider.
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _nap() async {
    if (_dangNap) return;
    _dangNap = true;
    try {
      final hs = await widget.api.detail(widget.journeyId);
      if (!mounted) return;
      setState(() {
        _hs = hs;
        _dangTai = false;
        _loi = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được hồ sơ cọc. Kéo xuống để thử lại.';
      });
    } finally {
      _dangNap = false;
    }
  }

  JourneyPayment? get _cocChuNha {
    for (final p in _hs?.payments ?? const <JourneyPayment>[]) {
      if (p.kind == 'OWNER_DEPOSIT') return p;
    }
    return null;
  }

  Future<void> _daNhan() async {
    if (_dangGui) return;
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      final hs = await widget.api.acknowledgeOwnerDeposit(widget.journeyId);
      if (!mounted) return;
      setState(() {
        _hs = hs;
        _dangGui = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xác nhận nhận cọc.')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = e is ApiException ? e.message : 'Chưa xác nhận được.';
      });
    }
  }

  Future<void> _nhanKhach() async {
    if (_dangGui) return;
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      final hs = await widget.api.confirm(widget.journeyId);
      if (!mounted) return;
      setState(() {
        _hs = hs;
        _dangGui = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hs.daVaoO
                ? 'Đã nhận khách vào ở — phòng chuyển sang "đang thuê".'
                : 'Đã chốt thuê.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = e is ApiException ? e.message : 'Chưa chốt được, thử lại nhé.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hs = _hs;
    final coc = _cocChuNha;
    final nua = ((hs?.totalDeposit ?? 0) / 2).round();
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.paperRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: HD.ink),
        title: Text('Cọc & nhận khách', style: HD.bodyBold(size: 16)),
      ),
      body: _dangTai
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
                  if (hs != null) ...[
                    RentalJourneyCompactHeader(
                      journey: hs,
                      subtitle:
                          '${hs.customer.name} · ${hs.sale?.name ?? 'Chưa có sale'}',
                    ),
                    const SizedBox(height: HD.s12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: HD.s12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: HD.positiveTint,
                        borderRadius: BorderRadius.circular(HD.r12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: HD.positive,
                          ),
                          const SizedBox(width: HD.s8),
                          const Expanded(child: Text('Cọc chủ nhà · 50%')),
                          Text(
                            nua > 0 ? PriceFormat.full(nua.toDouble()) : '—',
                            style: HD.bodyBold(size: 13, color: HD.positive),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: HD.s12),
                    RentalEvidenceCard(journey: hs, keyPrefix: 'chu'),
                    const SizedBox(height: HD.s12),
                    _khoiXacNhan(coc),
                    const SizedBox(height: HD.s12),
                    _khoiNhanKhach(hs),
                    if (hs.contactAccess?.available == true) ...[
                      const SizedBox(height: HD.s12),
                      _lienHeKhachGon(hs),
                    ],
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

  Widget _lienHeKhachGon(RentalJourney hs) {
    final contacts = hs.contactAccess?.contacts ?? const <JourneyContact>[];
    if (contacts.isEmpty) return const SizedBox.shrink();
    final contact = contacts.first;
    return Container(
      padding: const EdgeInsets.all(HD.s12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_outlined, size: 19, color: HD.svcBlue),
          const SizedBox(width: HD.s8),
          Expanded(
            child: Text(
              '${contact.name}${contact.phone.isEmpty ? '' : ' · ${contact.phone}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HD.bodyBold(size: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lienHeKhach(RentalJourney hs) {
    final access = hs.contactAccess;
    final unlocked = access?.available == true && access!.contacts.isNotEmpty;
    final message = switch (access?.reason) {
      'SALE_REQUIRED' => 'Cần giao dịch qua Sale để mở thông tin liên hệ.',
      'CONTRACT_REQUIRED' => 'Chờ Sale hoàn tất và gửi hợp đồng.',
      'CONTRACT_NOT_FINALIZED' =>
        'Thông tin liên hệ mở sau khi khách xác nhận hoàn tất hồ sơ.',
      _ => 'Thông tin liên hệ của khách đang được bảo vệ.',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HD.s12),
      decoration: BoxDecoration(
        color: unlocked ? HD.positiveTint : HD.paperSunken,
        borderRadius: BorderRadius.circular(HD.r8),
        border: Border.all(
          color: unlocked ? HD.positive.withValues(alpha: .28) : HD.hairline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            unlocked ? Icons.verified_user : Icons.lock_outline,
            size: 19,
            color: unlocked ? HD.positive : HD.inkMuted,
          ),
          const SizedBox(width: HD.s8),
          Expanded(
            child: unlocked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Liên hệ Khách thuê đã mở',
                        style: HD.bodyBold(size: 12.5),
                      ),
                      for (final contact in access.contacts) ...[
                        Text(
                          contact.name,
                          style: HD.body(size: 12, color: HD.inkSoft),
                        ),
                        if (contact.phone.isNotEmpty)
                          Text(
                            contact.phone,
                            style: HD.body(size: 12, color: HD.inkSoft),
                          ),
                      ],
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Liên hệ Khách thuê đang được bảo vệ',
                        style: HD.bodyBold(size: 12.5),
                      ),
                      Text(
                        message,
                        style: HD.body(size: 11.5, color: HD.inkMuted),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dongTien(String nhan, String chu, {String? phu}) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(nhan, style: HD.body(size: 12.5, color: HD.inkMuted)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(chu, style: HD.bodyBold(size: 14, color: HD.accent)),
            if (phu != null)
              Text(phu, style: HD.body(size: 11, color: HD.inkMuted)),
          ],
        ),
      ],
    ),
  );

  Widget _khoiXacNhan(JourneyPayment? coc) {
    final coQuyen =
        _hs?.availableActions.contains(
          RentalJourneyAction.acknowledgeOwnerDeposit,
        ) ??
        false;
    if (coc?.acknowledged ?? false) {
      return Container(
        padding: const EdgeInsets.all(HD.s12),
        decoration: BoxDecoration(
          color: HD.positiveTint,
          borderRadius: BorderRadius.circular(HD.r12),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 18, color: HD.positive),
            const SizedBox(width: HD.s8),
            Expanded(
              child: Text(
                'Đã nhận cọc chủ nhà',
                style: HD.bodyBold(size: 12.5, color: HD.positive),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            key: const Key('chu-da-nhan-coc'),
            style: FilledButton.styleFrom(
              backgroundColor: HD.positive,
              disabledBackgroundColor: HD.positive.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(HD.r12),
              ),
            ),
            onPressed: !coQuyen || _dangGui ? null : _daNhan,
            icon: const Icon(Icons.check_circle, size: 18, color: Colors.white),
            label: Text(
              coQuyen ? 'Xác nhận đã nhận cọc' : 'Chờ ảnh cọc',
              style: HD.bodyBold(size: 14.5, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  /// "Nhận khách vào ở" — bước cuối cùng của hồ sơ, và là bước trước đây
  /// KHÔNG AI làm được từ luồng chốt thuê: hợp đồng sinh ra ở trạng thái nháp,
  /// còn nút kích hoạt thì nằm tận màn quản lý hợp đồng.
  Widget _khoiNhanKhach(RentalJourney hs) {
    final hd = hs.hopDongDaKy;
    if (hd != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: HD.s16),
        child: Container(
          padding: const EdgeInsets.all(HD.s12),
          decoration: BoxDecoration(
            color: HD.positiveTint,
            borderRadius: BorderRadius.circular(HD.r12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.how_to_reg, size: 18, color: HD.positive),
              const SizedBox(width: HD.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hd.dangO
                          ? 'Khách đã vào ở — phòng ${hd.phong} đang thuê'
                          : 'Đã chốt thuê, chờ kích hoạt hợp đồng',
                      style: HD.bodyBold(size: 13),
                    ),
                    Text(
                      'Hợp đồng #${hd.id} · ${PriceFormat.full(hd.giaThue)}/tháng',
                      style: HD.body(size: 11.5, color: HD.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!hs.can(RentalJourneyAction.confirmRental)) {
      return const SizedBox.shrink();
    }
    // Thuê trước, bổ sung giấy tờ sau (14/10/2026): nói rõ còn thiếu gì, nhưng
    // không chặn — tải bổ sung ở Hợp đồng của phòng (chủ nhà hoặc khách).
    final thieu = <String>[
      if (hs.contractUrls.isEmpty) 'ảnh hợp đồng',
      if (hs.payments.isEmpty || hs.payments.any((p) => p.amount > 0 && !p.hasProof))
        'minh chứng cọc',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: HD.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (thieu.isNotEmpty) ...[
            Text(
              'Còn thiếu ${thieu.join(' · ')} — vẫn nhận khách được, '
              'bổ sung sau ở mục Hợp đồng của phòng.',
              key: const Key('chu-chot-con-thieu'),
              style: HD.body(size: 12.5, color: HD.warning),
            ),
            const SizedBox(height: HD.s8),
          ],
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              key: const Key('chu-nhan-khach-vao-o'),
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HD.r12),
                ),
              ),
              onPressed: _dangGui ? null : _nhanKhach,
              icon: const Icon(Icons.how_to_reg, size: 18, color: Colors.white),
              label: Text(
                'Nhận khách vào ở',
                style: HD.bodyBold(size: 14.5, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buoc(
    String nhan, {
    required bool xong,
    String? phu,
    bool cuoi = false,
  }) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(
              xong ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: xong ? HD.positive : HD.inkMuted,
            ),
            if (!cuoi)
              Expanded(
                child: Container(
                  width: 2,
                  color: (xong ? HD.positive : HD.hairline).withValues(
                    alpha: 0.5,
                  ),
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
                    size: 13.5,
                    color: xong ? HD.ink : HD.inkSoft,
                  ),
                ),
                if (phu != null)
                  Text(phu, style: HD.body(size: 12, color: HD.inkMuted)),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  static String _ngayDep(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/'
      '${d.year} · ${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}
