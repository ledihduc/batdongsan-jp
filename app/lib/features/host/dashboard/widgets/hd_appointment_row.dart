import 'package:flutter/material.dart';
import 'package:house_booking/data/models/viewing_appointment_model.dart';
import '../host_dashboard_tokens.dart';
import 'hd_status_pill.dart';

/// Appointment row as a newspaper "today's diary" entry — left margin holds
/// the time block (tabular monospace), right side holds prose + actions.
class HDAppointmentRow extends StatelessWidget {
  const HDAppointmentRow({
    super.key,
    required this.appointment,
    required this.onApprove,
    required this.onReject,
    required this.onLock,
    this.onComplete,
    this.onDoiGio,
    this.canManage = true,
  });

  final ViewingAppointmentModel appointment;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onLock;
  final VoidCallback? onComplete;

  /// "Bận giờ này" — mở sheet đề xuất giờ khác. Null thì không hiện nút.
  final VoidCallback? onDoiGio;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final b = appointment;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: HD.s20, vertical: HD.s16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HD.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TimeBlock(date: b.bookingDate, time: b.bookingTime),
          const SizedBox(width: HD.s16),
          Container(width: 1, color: HD.hairline, height: 64),
          const SizedBox(width: HD.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.houseTitle ?? 'Căn hộ chưa rõ tên',
                        style: HD.bodyBold(size: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: HD.s8),
                    HDStatusPill.appointment(b.status),
                  ],
                ),
                const SizedBox(height: HD.s4),
                Text(
                  'Người gửi · ${b.guestName ?? "khách lạ"}',
                  style: HD.body(size: 12, color: HD.inkMuted),
                ),
                if (b.message.isNotEmpty) ...[
                  const SizedBox(height: HD.s8),
                  _QuoteBlock(message: b.message),
                ],
                if (b.choKhachChonGio) ...[
                  const SizedBox(height: HD.s8),
                  Text(
                    'Đã báo bận${b.lyDoDoi == null || b.lyDoDoi!.isEmpty ? '' : ' (${b.lyDoDoi})'}'
                    ' · đang chờ khách chọn giờ mới',
                    style: HD.body(size: 12, color: HD.svcAmber),
                  ),
                ],
                const SizedBox(height: HD.s12),
                Wrap(
                  spacing: HD.s8,
                  runSpacing: HD.s8,
                  children: [
                    if (canManage)
                      _ActionRow(
                        status: b.status,
                        onApprove: onApprove,
                        onReject: onReject,
                        onLock: onLock,
                        onComplete: onComplete ?? onLock,
                      ),
                    if (canManage && onDoiGio != null && b.doiGioDuoc)
                      _Btn(
                        key: Key('doi-gio-${b.id}'),
                        icon: Icons.event_busy,
                        label: 'BẬN · ĐỔI GIỜ',
                        tone: HD.svcAmber,
                        onTap: onDoiGio!,
                        outlined: true,
                      ),
                  ],
                ),
                if (b.status == 'awaiting_guest') ...[
                  const SizedBox(height: HD.s12),
                  Text(
                    'Đề nghị thuê đã gửi · đang chờ khách xác nhận',
                    style: HD.body(size: 12, color: HD.svcAmber),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.date, required this.time});
  final String date;
  final String time;

  @override
  Widget build(BuildContext context) {
    // Show date as DD.MM, time as HH:MM. Falls back to raw string.
    final dateShort = _formatDate(date);
    return SizedBox(
      width: 56,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chỉ mốc BẮT ĐẦU: '10:00-11:00' không vừa cột 56px, gãy thành
          // "10:00-1 / 1:00". Slot luôn dài 1 giờ nên mốc đầu là đủ.
          Text(
            time.split('-').first.trim(),
            style: HD.tabular(color: HD.accent, size: 16),
          ),
          const SizedBox(height: HD.s4),
          Text(dateShort, style: HD.tabular(color: HD.inkMuted, size: 11)),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    final parts = raw.split(RegExp(r'[-/]'));
    if (parts.length >= 3) {
      // assume YYYY-MM-DD or DD-MM-YYYY
      if (parts.first.length == 4) {
        return '${parts[2]}.${parts[1]}';
      }
      return '${parts[0]}.${parts[1]}';
    }
    return raw;
  }
}

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(HD.s12, HD.s8, HD.s12, HD.s8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: HD.accent, width: 2)),
        color: HD.paperRaised,
      ),
      child: Text(
        '"$message"',
        style: HD.body(size: 12).copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.status,
    required this.onApprove,
    required this.onReject,
    required this.onLock,
    required this.onComplete,
  });

  final String status;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onLock;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    if (status == 'pending') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Btn(
            icon: Icons.check,
            label: 'DUYỆT XEM',
            tone: HD.positive,
            onTap: onApprove,
          ),
          const SizedBox(width: HD.s8),
          _Btn(
            icon: Icons.close,
            label: 'TỪ CHỐI',
            tone: HD.negative,
            onTap: onReject,
            outlined: true,
          ),
        ],
      );
    }
    if (status == 'approved') {
      return _Btn(
        icon: Icons.check_circle_outline,
        label: 'XÁC NHẬN ĐÃ XEM',
        tone: HD.accent,
        onTap: onComplete,
      );
    }
    if (status == 'completed') {
      return _Btn(
        icon: Icons.description_outlined,
        label: 'GỬI ĐỀ NGHỊ THUÊ',
        tone: HD.accent,
        onTap: onLock,
      );
    }
    return const SizedBox.shrink();
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    super.key,
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final Color tone;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final bg = outlined ? Colors.transparent : tone;
    final fg = outlined ? tone : HD.paperRaised;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: tone),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 6),
            Text(label, style: HD.eyebrow(color: fg).copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
