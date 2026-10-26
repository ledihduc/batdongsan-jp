import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/utils/vn_date.dart';
import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/features/chat/chat_screen.dart';
import 'package:house_booking/features/guest/booking/phieu_hen_xem_screen.dart';
import 'package:house_booking/features/guest/booking/widgets/appointment_status_chip.dart';
import 'package:house_booking/features/guest/review/write_review_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/viewing_appointment_provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Chi tiết một viewing appointment — mở từ tap card ở BookingHistoryScreen.
///
/// Hiển thị toàn bộ context: schedule, message gốc, host info (khi đã duyệt),
/// timeline tiến trình. Sticky bottom CTA tuỳ status.
class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key, required this.appointment});

  final ViewingAppointmentModel appointment;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  bool _busy = false;

  /// Bản mới nhất trong provider (sau khi khách chọn lại giờ, trạng thái đổi).
  ViewingAppointmentModel? _moiNhat;

  ViewingAppointmentModel get _a => _moiNhat ?? widget.appointment;

  bool get _hostBlockVisible =>
      const {'approved', 'completed', 'locked'}.contains(_a.status);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    try {
      final ds = Provider.of<ViewingAppointmentProvider>(context).appointments;
      for (final x in ds) {
        if (x.id != null && x.id == widget.appointment.id) _moiNhat = x;
      }
    } on ProviderNotFoundException {
      _moiNhat = null;
    }
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(eyebrow: l.bkDetEyebrow, title: l.bkDetTitle),
      body: ListView(
        children: [
          _HeaderCard(appointment: _a),
          if (_a.id != null && _a.choKhachChonGio) _theDoiGio(),
          // Phiếu hẹn (mã + QR + gọi sale + chỉ đường) — màn khách thấy ngay sau
          // khi đặt. Lịch HẸN CHỐT không có phiếu nên không hiện nút.
          if (_a.id != null && _a.loai == 'xem')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: OutlinedButton.icon(
                key: const Key('mo-phieu-hen'),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhieuHenXemScreen(appointmentId: _a.id!),
                    ),
                  );
                  // Trên phiếu khách có thể đã huỷ / chọn lại giờ — quay về
                  // mà vẫn "Chờ duyệt" + nút huỷ là nói sai trạng thái.
                  await _napLai();
                },
                icon: const Icon(Icons.confirmation_number_outlined, size: 18),
                label: const Text('内見票を見る · コード & QR'),
              ),
            ),
          const _SectionDivider(),
          _ScheduleSection(appointment: _a),
          const _SectionDivider(),
          _MessageSection(message: _a.message),
          if (_hostBlockVisible) ...[
            const _SectionDivider(),
            _HostSection(appointment: _a, onCall: _callHost, onChat: _openChat),
          ],
          const _SectionDivider(),
          _TimelineSection(status: _a.status, createdAt: _a.createdAt),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: _StickyActionBar(
          appointment: _a,
          busy: _busy,
          onCancel: _confirmCancel,
          onCall: _callHost,
          onChat: _openChat,
          onReview: _openReview,
          onExplore: _openHouse,
        ),
      ),
    );
  }

  Future<void> _confirmCancel() async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.bkDetCancelAppointment),
        content: Text(l.bkDetCancelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.bkDetClose),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.bkDetCancelBooking),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    final user = context.read<AuthProvider>().currentUser!;
    final ok = await context.read<ViewingAppointmentProvider>().updateStatus(
      _a.id!,
      'cancelled',
      user.id!,
      user.role,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.bkDetCancelFailed)));
    }
  }

  Future<void> _napLai() async {
    if (!mounted) return;
    final me = context.read<AuthProvider>().currentUser;
    if (me?.id == null) return;
    try {
      await context.read<ViewingAppointmentProvider>().fetchAppointments(
        me!.id!,
        'guest',
      );
    } on ProviderNotFoundException {
      // Màn mở trần (test) — không có danh sách để nạp lại.
    }
  }

  /// Bên bán bận → khách mở phiếu chọn lại giờ.
  Widget _theDoiGio() => Container(
    key: const Key('chi-tiet-doi-gio'),
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: HD.warningTint,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.event_repeat, color: HD.svcAmber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '選択した時間が取れなくなりました',
                style: HD.bodyBold(size: 14, color: HD.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          (_a.lyDoDoi ?? '').isEmpty
              ? '別の時間を提案されています — 希望の時間を選ぶとすぐに確定されます。'
              : '「${_a.lyDoDoi}」。別の時間を提案されています — 希望の時間を選ぶとすぐに確定されます。',
          style: HD.body(size: 13, color: HD.inkSoft),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const Key('chon-gio-moi'),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PhieuHenXemScreen(appointmentId: _a.id!),
              ),
            );
            await _napLai();
          },
          style: FilledButton.styleFrom(backgroundColor: HD.accent),
          icon: const Icon(Icons.schedule, size: 18),
          label: const Text('新しい時間を選ぶ'),
        ),
      ],
    ),
  );

  Future<void> _callHost() async {
    final l = AppLocalizations.of(context);
    final phone = _a.hostPhone;
    if (phone == null || phone.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.bkDetPhoneCopied(phone)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openChat() {
    final l = AppLocalizations.of(context);
    final hostId = _a.hostId;
    if (hostId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.bkDetHostNotFound)));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerId: hostId,
          peerName: _a.hostName ?? l.bkDetHost,
          houseId: _a.houseId,
        ),
      ),
    );
  }

  void _openReview() {
    // Đánh giá gắn theo TIN. Lịch neo thẳng vào phòng chưa có tin thì không có
    // đối tượng để đánh giá.
    if (!_a.moDuocTin) return;
    final l = AppLocalizations.of(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WriteReviewScreen(
          houseId: _a.houseId!,
          houseTitle: _a.houseTitle ?? l.bkDetApartment,
        ),
      ),
    );
  }

  void _openHouse() {
    if (!_a.moDuocTin) return;
    context.push('/house/${_a.houseId}');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sections
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.appointment});
  final ViewingAppointmentModel appointment;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: Semantics(
                label: appointment.houseTitle ?? l.bkDetRoomImage,
                child: CachedNetworkImage(
                  imageUrl:
                      appointment.houseImage ??
                      'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800',
                  fit: BoxFit.cover,
                  memCacheWidth: 800,
                  placeholder: (_, __) => Container(color: HD.paperSunken),
                  errorWidget: (_, __, ___) => Container(
                    color: HD.paperSunken,
                    child: const Icon(
                      Icons.home_outlined,
                      size: 48,
                      color: HD.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            appointment.houseTitle ?? l.bkDetApartment,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: HD.ink,
            ),
          ),
          if ((appointment.houseAddress ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 14, color: HD.inkMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    appointment.houseAddress!,
                    style: const TextStyle(color: HD.inkMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          AppointmentStatusChip(
            status: appointment.status,
            size: AppointmentChipSize.large,
          ),
        ],
      ),
    );
  }
}

class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({required this.appointment});
  final ViewingAppointmentModel appointment;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l.bkDetScheduleTitle),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: l.bkDetViewDate,
            value: formatVnDate(appointment.bookingDate),
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.schedule_outlined,
            label: l.bkDetTime,
            value: appointment.bookingTime,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.history_outlined,
            label: l.bkDetSentAt,
            value: formatVnDateTime(appointment.createdAt),
          ),
        ],
      ),
    );
  }
}

class _MessageSection extends StatelessWidget {
  const _MessageSection({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final empty = message.trim().isEmpty;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l.bkDetYourMessage),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HD.paperSunken,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
              ),
            ),
            child: Text(
              empty ? l.bkDetNoMessage : message,
              style: TextStyle(
                fontSize: 13,
                color: empty ? HD.inkMuted : HD.inkSoft,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostSection extends StatelessWidget {
  const _HostSection({
    required this.appointment,
    required this.onCall,
    required this.onChat,
  });

  final ViewingAppointmentModel appointment;
  final VoidCallback onCall;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasPhone = (appointment.hostPhone ?? '').isNotEmpty;
    final canChat = appointment.hostId != null;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l.bkDetHostInfo),
          const SizedBox(height: 12),
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: HD.accentTint,
                child: Icon(Icons.person, color: HD.inkSoft),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.hostName ?? l.bkDetHost,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: HD.ink,
                      ),
                    ),
                    if (hasPhone) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: onCall,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: HD.positive,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              appointment.hostPhone!,
                              style: const TextStyle(
                                color: HD.positive,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (canChat)
                IconButton(
                  icon: const Icon(Icons.chat_outlined),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: onChat,
                  tooltip: l.bkDetMessage,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.status, required this.createdAt});
  final String status;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final steps = _resolveSteps(status, l);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l.bkDetProgress),
          const SizedBox(height: 12),
          for (int i = 0; i < steps.length; i++)
            _TimelineRow(
              label: steps[i].label,
              done: steps[i].done,
              isLast: i == steps.length - 1,
              sublabel: i == 0 ? formatVnDateTime(createdAt) : null,
            ),
        ],
      ),
    );
  }

  List<_StepSpec> _resolveSteps(String status, AppLocalizations l) {
    // Map status flow: pending → approved → completed → locked (happy path).
    // Branch terminal states (rejected/cancelled/lost) chỉ check 2 step đầu rồi
    // đánh dấu step cuối là "kết thúc".
    const order = ['pending', 'approved', 'completed', 'locked'];
    final currentIdx = order.indexOf(status);
    if (currentIdx >= 0) {
      return [
        _StepSpec(l.bkDetStepRequested, currentIdx >= 0),
        _StepSpec(l.bkDetStepApproved, currentIdx >= 1),
        _StepSpec(l.bkDetStepCompleted, currentIdx >= 2),
        _StepSpec(l.bkDetStepBooked, currentIdx >= 3),
      ];
    }
    // Terminal branches.
    final terminalLabel = switch (status) {
      'rejected' => l.bkDetStepRejected,
      'cancelled' => l.bkDetStepCancelled,
      'lost' => l.bkDetStepLost,
      _ => l.bkDetStepEnded,
    };
    return [
      _StepSpec(l.bkDetStepRequested, true),
      _StepSpec(terminalLabel, true),
    ];
  }
}

class _StepSpec {
  const _StepSpec(this.label, this.done);
  final String label;
  final bool done;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.done,
    required this.isLast,
    this.sublabel,
  });

  final String label;
  final bool done;
  final bool isLast;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    final color = done ? HD.positive : HD.hairline;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: done ? color : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: color)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: done ? HD.ink : HD.inkMuted,
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sublabel!,
                      style: const TextStyle(fontSize: 11, color: HD.inkMuted),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky bottom action bar
// ─────────────────────────────────────────────────────────────────────────────

class _StickyActionBar extends StatelessWidget {
  const _StickyActionBar({
    required this.appointment,
    required this.busy,
    required this.onCancel,
    required this.onCall,
    required this.onChat,
    required this.onReview,
    required this.onExplore,
  });

  final ViewingAppointmentModel appointment;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onCall;
  final VoidCallback onChat;
  final VoidCallback onReview;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final children = _buildButtons(context);
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: HD.accentTint)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildButtons(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (busy) {
      return [
        const SizedBox(
          height: 44,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ];
    }
    switch (appointment.status) {
      case 'pending':
      case 'doi_gio':
        return [
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.cancel_outlined, color: HD.accentDeep),
            label: Text(
              l.bkDetCancelAppointment,
              style: const TextStyle(color: HD.accentDeep),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: HD.accentDeep),
            ),
          ),
        ];
      case 'approved':
      case 'locked':
        return [
          if ((appointment.hostPhone ?? '').isNotEmpty)
            OutlinedButton.icon(
              onPressed: onCall,
              icon: const Icon(Icons.phone_outlined),
              label: Text(l.bkDetCall),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          if (appointment.hostId != null)
            ElevatedButton.icon(
              onPressed: onChat,
              icon: const Icon(Icons.chat_outlined),
              label: Text(l.bkDetMessage),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
        ];
      case 'completed':
        if (appointment.hasReviewed) {
          return [
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.star, color: Colors.amber),
              label: Text(l.bkDetReviewed),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ];
        }
        return [
          ElevatedButton.icon(
            onPressed: onReview,
            icon: const Icon(Icons.star_rounded),
            label: Text(l.bkDetWriteReview),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ];
      case 'rejected':
      case 'cancelled':
      case 'lost':
        return [
          OutlinedButton.icon(
            onPressed: onExplore,
            icon: const Icon(Icons.search),
            label: Text(l.bkDetExploreOther),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ];
      default:
        return [];
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared primitives
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: HD.inkMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: HD.inkMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: HD.inkMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: HD.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 6);
  }
}
