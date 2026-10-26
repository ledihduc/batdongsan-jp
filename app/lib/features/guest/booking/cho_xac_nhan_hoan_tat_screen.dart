import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/features/shared/viewing_detail_widgets.dart';

/// Theo dõi hồ sơ sau khi khách gửi đủ cọc và xác nhận thuê.
class ChoXacNhanHoanTatScreen extends StatefulWidget {
  const ChoXacNhanHoanTatScreen({
    super.key,
    required this.journeyId,
    this.api = const RentalJourneyApi(),
    this.initial,
  });

  final int journeyId;
  final RentalJourneyApi api;
  final RentalJourney? initial;

  @override
  State<ChoXacNhanHoanTatScreen> createState() =>
      _ChoXacNhanHoanTatScreenState();
}

class _ChoXacNhanHoanTatScreenState extends State<ChoXacNhanHoanTatScreen> {
  RentalJourney? _hs;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hs = widget.initial;
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await widget.api.detail(widget.journeyId);
      if (!mounted) return;
      setState(() {
        _hs = value;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Chưa cập nhật được hồ sơ. Kéo xuống để thử lại.';
      });
    }
  }

  Future<void> _report() async {
    final hs = _hs;
    if (hs == null ||
        _sending ||
        !hs.can(RentalJourneyAction.reportParticipant)) {
      return;
    }
    final controller = TextEditingController();
    final detail = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Báo cáo vấn đề'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Mô tả vấn đề bạn đang gặp…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Gửi báo cáo'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (detail == null || detail.length < 3 || !mounted) return;
    setState(() => _sending = true);
    try {
      await widget.api.report(
        hs.id,
        reportedUserId: hs.sale?.id ?? hs.owner.id,
        reasonCode: 'OTHER',
        detail: detail,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi báo cáo cho Vua Nhà.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hs = _hs;
    final complete = hs?.status == RentalJourneyStatus.completed;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: ViewingDetailAppBar(
        title: complete ? 'Đã chốt thuê' : 'Chờ xác nhận hoàn tất',
      ),
      body: _loading && hs == null
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : RefreshIndicator(
              onRefresh: _load,
              color: HD.accent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  HD.s16,
                  HD.s12,
                  HD.s16,
                  HD.s24,
                ),
                children: [
                  if (hs != null) ...[
                    _property(hs),
                    const SizedBox(height: HD.s12),
                    ViewingStatusBox(
                      icon: complete ? Icons.check_circle : Icons.schedule,
                      title: complete ? 'Hồ sơ đã hoàn tất' : 'Chưa hoàn tất',
                      message: hs.daVaoO
                          ? 'Hợp đồng đã hiệu lực, phòng '
                                '${hs.hopDongDaKy!.phong} chuyển sang đang thuê.'
                          : complete
                          ? 'Các bên đã xác nhận và hồ sơ thuê đã hoàn tất.'
                          : 'Đang trong quá trình xác minh và xác nhận từ các bên.',
                      color: complete ? HD.positive : HD.warning,
                    ),
                    const SizedBox(height: HD.s16),
                    Row(
                      children: [
                        Text('Hồ sơ của bạn', style: HD.bodyBold(size: 14)),
                        const Spacer(),
                        Text(
                          '${hs.contractUrls.length + hs.payments.length} tài liệu',
                          style: HD.body(size: 11.5, color: HD.accent),
                        ),
                      ],
                    ),
                    const SizedBox(height: HD.s8),
                    _documents(hs),
                    const SizedBox(height: HD.s16),
                    Text('Trạng thái xác nhận', style: HD.bodyBold(size: 14)),
                    const SizedBox(height: HD.s8),
                    _status(
                      'Khách đã xác nhận',
                      true,
                      'Yêu cầu thuê và chuyển cọc đã được gửi',
                    ),
                    _status(
                      'Chủ nhà đã xác nhận',
                      hs.payment('OWNER_DEPOSIT')?.acknowledged == true ||
                          complete,
                      hs.payment('OWNER_DEPOSIT')?.acknowledged == true
                          ? 'Chủ nhà đã xác nhận nhận cọc'
                          : 'Chủ nhà đang xem xét hồ sơ',
                    ),
                    // Không còn bước "sale kiểm tra": chốt thuê là khách HOẶC
                    // chủ nhà bấm, xong là phòng đổi trạng thái ngay. Vẽ một
                    // bước không tồn tại là để người ta ngồi chờ vô ích.
                    _status(
                      'Phòng chuyển sang đang thuê',
                      hs.daVaoO,
                      hs.daVaoO
                          ? 'Hợp đồng #${hs.hopDongDaKy!.id} đã hiệu lực'
                          : 'Sau khi chốt, phòng vào mục Đang ở của bạn',
                    ),
                    const SizedBox(height: HD.s8),
                    Container(
                      padding: const EdgeInsets.all(HD.s12),
                      decoration: BoxDecoration(
                        color: HD.warningTint,
                        borderRadius: BorderRadius.circular(HD.r8),
                      ),
                      child: Text(
                        hs.daVaoO
                            ? 'Phòng ${hs.hopDongDaKy!.phong} đã chuyển sang '
                                  'Đang thuê'
                                  '${hs.hopDongDaKy!.tu == null ? '' : ' từ ${hs.hopDongDaKy!.tu}'}.'
                            : 'Phòng chuyển sang Đang thuê ngay khi bạn hoặc chủ nhà bấm chốt thuê.',
                        style: HD.body(size: 12, color: HD.inkSoft),
                      ),
                    ),
                    const SizedBox(height: HD.s16),
                    _contactSection(hs),
                  ],
                  if (_error != null)
                    Text(_error!, style: HD.body(color: HD.negative)),
                ],
              ),
            ),
      bottomNavigationBar: hs == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: viewingOutlineButton(),
                      onPressed: _sending ? null : _report,
                      icon: const Icon(Icons.warning_amber, size: 18),
                      label: const Text('Báo cáo vấn đề'),
                    ),
                  ),
                  const SizedBox(width: HD.s8),
                  Expanded(
                    child: FilledButton.icon(
                      style: viewingPrimaryButton(),
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Cập nhật hồ sơ'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _property(RentalJourney hs) {
    final image = hs.subject.image;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(HD.r8),
          child: SizedBox(
            width: 94,
            height: 82,
            child: image == null || image.isEmpty
                ? const ColoredBox(
                    color: HD.paperSunken,
                    child: Icon(Icons.apartment),
                  )
                : CachedNetworkImage(
                    imageUrl: image.startsWith('http')
                        ? image
                        : '${ApiConfig.baseUrl}$image',
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        const SizedBox(width: HD.s12),
        Expanded(child: Text(hs.subject.title, style: HD.bodyBold(size: 15))),
      ],
    );
  }

  Widget _documents(RentalJourney hs) {
    final docs = <({IconData icon, String label})>[
      if (hs.contractUrls.isNotEmpty)
        (icon: Icons.description, label: 'Hợp đồng thuê'),
      if (hs.payment('APP_DEPOSIT')?.hasProof == true)
        (icon: Icons.receipt_long, label: 'CK cọc Vua Nhà'),
      if (hs.payment('OWNER_DEPOSIT')?.hasProof == true)
        (icon: Icons.receipt, label: 'CK cọc chủ nhà'),
    ];
    if (docs.isEmpty) {
      return Text(
        'Chưa có tài liệu được tải lên.',
        style: HD.body(size: 12.5, color: HD.inkMuted),
      );
    }
    return Row(
      children: [
        for (var i = 0; i < docs.length; i++) ...[
          if (i > 0) const SizedBox(width: HD.s8),
          Expanded(
            child: ViewingSectionCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Column(
                children: [
                  Icon(docs[i].icon, color: const Color(0xFF173B75)),
                  const SizedBox(height: 6),
                  Text(
                    docs[i].label,
                    textAlign: TextAlign.center,
                    style: HD.bodyBold(size: 10.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _contactSection(RentalJourney hs) {
    final access = hs.contactAccess;
    final unlocked = access?.available == true && access!.contacts.isNotEmpty;
    final message = switch (access?.reason) {
      'SALE_REQUIRED' =>
        'Thông tin liên hệ chỉ mở cho giao dịch có Sale phụ trách.',
      'CONTRACT_REQUIRED' =>
        'Thông tin liên hệ mở sau khi Sale gửi đủ hợp đồng.',
      'CONTRACT_NOT_FINALIZED' =>
        'Thông tin liên hệ sẽ mở sau khi các bên hoàn tất xác nhận hợp đồng và cọc.',
      _ => 'Thông tin liên hệ được bảo vệ theo tiến độ hồ sơ thuê.',
    };
    return ViewingSectionCard(
      padding: const EdgeInsets.all(HD.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                unlocked ? Icons.verified_user : Icons.lock_outline,
                color: unlocked ? HD.positive : HD.accent,
                size: 19,
              ),
              const SizedBox(width: HD.s8),
              Text('Liên hệ Chủ nhà', style: HD.bodyBold(size: 13.5)),
              const Spacer(),
              Text(
                unlocked ? 'Đã mở' : 'Được bảo vệ',
                style: HD.bodyBold(
                  size: 10.5,
                  color: unlocked ? HD.positive : HD.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: HD.s8),
          if (!unlocked)
            Text(message, style: HD.body(size: 12, color: HD.inkMuted))
          else
            for (final contact in access.contacts) ...[
              Text(contact.name, style: HD.bodyBold(size: 13)),
              if (contact.phone.isNotEmpty)
                Text(
                  contact.phone,
                  style: HD.body(size: 12, color: HD.inkSoft),
                ),
              if (contact.email.isNotEmpty)
                Text(
                  contact.email,
                  style: HD.body(size: 12, color: HD.inkMuted),
                ),
            ],
        ],
      ),
    );
  }

  Widget _status(String title, bool done, String subtitle) => Container(
    margin: const EdgeInsets.only(bottom: HD.s8),
    padding: const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(HD.r8),
      border: Border.all(color: HD.hairline),
    ),
    child: Row(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.schedule,
          color: done ? HD.positive : const Color(0xFF173B75),
        ),
        const SizedBox(width: HD.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: HD.bodyBold(size: 12.5)),
              Text(subtitle, style: HD.body(size: 11, color: HD.inkMuted)),
            ],
          ),
        ),
        Text(
          done ? 'Đã xác nhận' : 'Đang chờ',
          style: HD.bodyBold(
            size: 10.5,
            color: done ? HD.positive : HD.warning,
          ),
        ),
      ],
    ),
  );
}
