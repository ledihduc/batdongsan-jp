import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/data/models/notification_model.dart';
import 'package:house_booking/data/services/social_api.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/notification_provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/guest/booking/phieu_dat_phong_screen.dart';
import 'package:house_booking/features/guest/booking/phieu_hen_xem_screen.dart';
import 'package:house_booking/features/guest/booking/coc_xac_nhan_thue_screen.dart';
import 'package:house_booking/features/guest/da_dat/da_dat_screen.dart';
import 'package:house_booking/features/host/appointments/host_appointments_screen.dart';
import 'package:house_booking/features/host/journey/xac_nhan_coc_chu_nha_screen.dart';
import 'package:house_booking/features/guest/social/post_comments_screen.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/chi_tiet_ca_thue_screen.dart';
import 'package:house_booking/features/sale/gui_ho_so_chot_thue_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Các loại thông báo social deep-link về bài đăng.
const _kSocialNotifTypes = {
  'social_post_liked',
  'social_post_commented',
  'social_comment_reply',
};

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentUser;
      if (user != null) {
        Provider.of<NotificationProvider>(
          context,
          listen: false,
        ).fetch(user.id!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final np = Provider.of<NotificationProvider>(context);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        eyebrow: l.notifInbox,
        title: l.notifications,
        actions: [
          if (np.unread > 0)
            Padding(
              padding: const EdgeInsets.only(right: HD.s12),
              child: DsButton(
                label: l.notifMarkAllRead,
                variant: DsButtonVariant.ghost,
                size: DsButtonSize.compact,
                onPressed: () => np.markAllRead(),
              ),
            ),
        ],
      ),
      body: np.loading
          ? const Center(child: CircularProgressIndicator())
          : np.items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_off_outlined,
                      size: 64,
                      color: HD.inkMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l.notifEmpty,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: HD.ink,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () =>
                  user == null ? Future.value() : np.fetch(user.id!),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: np.items.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 72),
                itemBuilder: (_, i) => _tile(np.items[i], np),
              ),
            ),
    );
  }

  Widget _tile(NotificationModel n, NotificationProvider np) {
    final meta = _meta(n.type);
    return ListTile(
      tileColor: n.read ? Colors.white : HD.accentSoft,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: meta.color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(meta.icon, color: meta.color, size: 22),
      ),
      title: Text(
        n.title,
        style: TextStyle(
          fontWeight: n.read ? FontWeight.w600 : FontWeight.bold,
          fontSize: 14,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(n.body, style: const TextStyle(fontSize: 12, color: HD.inkSoft)),
          const SizedBox(height: 4),
          Text(
            _relativeTime(n.createdAt),
            style: const TextStyle(fontSize: 11, color: HD.inkMuted),
          ),
        ],
      ),
      trailing: n.read
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: HD.accent,
                shape: BoxShape.circle,
              ),
            ),
      onTap: () {
        np.markRead(n.id);
        if (n.relatedId != null &&
            (n.type == 'booking_approved' ||
                n.type == 'booking_locked' ||
                n.type == 'booking_lost' ||
                n.type == 'booking_new' ||
                n.type == 'booking_rejected')) {
          context.push('/house/${n.relatedId}');
        } else if (n.relatedId != null && n.type == 'short_stay_van_hanh') {
          // Chủ phòng / sale: mở thẳng màn quầy của đơn — duyệt, từ chối,
          // nhận phòng đều làm được ngay ở đó.
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChiTietCaThueScreen(reservationId: n.relatedId!),
            ),
          );
        } else if (n.relatedId != null &&
            n.type == 'viewing_appointment_doi_gio') {
          // Khách: bên bán bận — mở thẳng phiếu để chọn lại giờ. `relatedId`
          // của loại này là id LỊCH, không phải id tin.
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PhieuHenXemScreen(appointmentId: n.relatedId!),
            ),
          );
        } else if (n.type == 'viewing_appointment_requested' ||
            n.type == 'viewing_appointment_cancelled') {
          // Sale / chủ nhà: có người hẹn xem (hoặc khách vừa chọn giờ mới).
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HostAppointmentsScreen()),
          );
        } else if (n.type == 'viewing_appointment_approved' ||
            n.type == 'viewing_appointment_rejected') {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const DaDatScreen()));
        } else if (n.type == 'short_stay') {
          // Khách: mở thẳng PHIẾU đơn của mình (mã, QR, gọi sale, huỷ).
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => n.relatedId == null
                  ? const DaDatScreen()
                  : PhieuDatPhongScreen(reservationId: n.relatedId!),
            ),
          );
        } else if (n.relatedId != null &&
            const {
              'rental_contract_ready',
              'rental_payment_proof',
              'rental_completed',
            }.contains(n.type)) {
          _moHoSoThue(n.relatedId!);
        } else if (n.relatedId != null && _kSocialNotifTypes.contains(n.type)) {
          _openPost(context, n.relatedId!);
        }
      },
    );
  }

  /// Một thông báo cọc/hợp đồng phải mở đúng màn mà vai trò hiện tại có thể
  /// xử lý ngay, thay vì chỉ đánh dấu đã đọc rồi đứng yên ở hộp thư.
  void _moHoSoThue(int journeyId) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final laSale = user?.accountType == 'sale';
    final laChuNha =
        !laSale && (user?.accountType == 'owner' || user?.role == 'host');
    final Widget man = laSale
        ? GuiHoSoChotThueScreen(journeyId: journeyId)
        : laChuNha
        ? XacNhanCocChuNhaScreen(journeyId: journeyId)
        : CocXacNhanThueScreen(journeyId: journeyId);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));
  }

  /// Deep-link về bài đăng: tải bài rồi mở màn bình luận. Bài đã xoá → báo nhẹ.
  Future<void> _openPost(BuildContext context, int postId) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final post = await SocialApi().fetchPost(postId);
      await navigator.push(
        MaterialPageRoute(builder: (_) => PostCommentsScreen(post: post)),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.notifContentGone)));
    }
  }

  _NotifMeta _meta(String type) {
    switch (type) {
      case 'booking_locked':
        return _NotifMeta(Icons.task_alt, HD.positive);
      case 'booking_lost':
        return _NotifMeta(Icons.block, Colors.grey);
      case 'booking_approved':
        return _NotifMeta(Icons.check_circle_outline, HD.accent);
      case 'booking_rejected':
        return _NotifMeta(Icons.cancel_outlined, Colors.red);
      case 'booking_new':
        return _NotifMeta(Icons.notifications_active, HD.warning);
      case 'short_stay_van_hanh':
        return _NotifMeta(Icons.hotel_class_outlined, HD.warning);
      case 'short_stay':
        return _NotifMeta(Icons.bed_outlined, HD.accent);
      case 'viewing_appointment_doi_gio':
        return _NotifMeta(Icons.event_repeat, HD.svcAmber);
      case 'viewing_appointment_requested':
        return _NotifMeta(Icons.event_note_outlined, HD.warning);
      case 'viewing_appointment_cancelled':
        return _NotifMeta(Icons.event_busy_outlined, HD.inkMuted);
      case 'viewing_appointment_approved':
        return _NotifMeta(Icons.event_available, HD.positive);
      case 'viewing_appointment_rejected':
        return _NotifMeta(Icons.event_busy, Colors.red);
      case 'rental_contract_ready':
        return _NotifMeta(Icons.description_outlined, HD.svcOrange);
      case 'rental_payment_proof':
        return _NotifMeta(Icons.account_balance_wallet_outlined, HD.positive);
      case 'rental_completed':
        return _NotifMeta(Icons.home_work_outlined, HD.positive);
      case 'social_post_liked':
        return _NotifMeta(Icons.favorite, Colors.redAccent);
      case 'social_post_commented':
        return _NotifMeta(Icons.mode_comment_outlined, HD.accent);
      case 'social_comment_reply':
        return _NotifMeta(Icons.reply, HD.accent);
      default:
        return _NotifMeta(Icons.info_outline, HD.inkMuted);
    }
  }

  String _relativeTime(DateTime t) {
    final l = AppLocalizations.of(context);
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return l.notifJustNow;
    if (diff.inMinutes < 60) return l.notifMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l.notifHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l.notifDaysAgo(diff.inDays);
    return '${t.day}/${t.month}/${t.year}';
  }
}

class _NotifMeta {
  final IconData icon;
  final Color color;
  _NotifMeta(this.icon, this.color);
}
