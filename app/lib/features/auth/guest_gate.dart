import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/guest/leads/leave_contact_sheet.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/auth_provider.dart';

/// Tiện ích cho chế độ **browse-first** (khách xem app không cần đăng nhập):
/// - [requireAuth]: gọi ở mọi HÀNH ĐỘNG cá nhân (lưu/liên hệ/đăng/chat/đặt lịch/
///   cộng đồng). Nếu chưa đăng nhập → hiện bottom-sheet mời đăng nhập, trả false.
/// - [GuestTabPlaceholder]: trạng thái thay cho tab cá nhân/yêu thích khi là khách.
class GuestGate {
  const GuestGate._();

  /// True nếu đã đăng nhập. Nếu chưa → hiện bottom-sheet mời đăng nhập và trả
  /// false (caller nên return sớm, không thực hiện hành động).
  static bool requireAuth(BuildContext context,
      {String? message, String leadSource = 'guest_gate'}) {
    final authed =
        Provider.of<AuthProvider>(context, listen: false).isAuthenticated;
    if (authed) return true;
    promptLogin(context, message: message, leadSource: leadSource);
    return false;
  }

  static Future<void> promptLogin(BuildContext context,
      {String? message, String leadSource = 'guest_gate'}) {
    final l = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: HD.paperRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 28 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: HD.accentTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.lock_open_outlined, color: HD.accent),
            ),
            const SizedBox(height: 14),
            Text(l.guestGateTitle,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold, color: HD.ink)),
            const SizedBox(height: 6),
            Text(
              message ?? l.guestGateBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: HD.inkSoft, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: HD.accent,
                    minimumSize: const Size.fromHeight(48)),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/login');
                },
                child: Text(l.guestGateLoginRegister),
              ),
            ),
            const SizedBox(height: 8),
            // Lối ÍT MA SÁT: chưa muốn đăng nhập thì để lại SĐT, được gọi lại.
            // Giữ khách trong phễu thay vì mất hẳn ở tường login.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: HD.accent,
                    side: const BorderSide(color: HD.accent),
                    minimumSize: const Size.fromHeight(46)),
                onPressed: () {
                  Navigator.pop(ctx);
                  showLeaveContactSheet(context, source: leadSource);
                },
                child: Text(l.guestGateLeaveContact),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.guestGateLater),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Trạng thái thay thế cho các tab cần đăng nhập (Yêu thích / Cá nhân) khi khách
/// chưa đăng nhập — thay vì crash hoặc màn trắng.
class GuestTabPlaceholder extends StatelessWidget {
  const GuestTabPlaceholder({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(eyebrow: l.guestGateAccount, title: title),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: HD.accentTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: HD.accent, size: 34),
              ),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: HD.inkSoft, fontSize: 14, height: 1.4)),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: HD.accent,
                    minimumSize: const Size(200, 48)),
                onPressed: () => context.push('/login'),
                child: Text(l.guestGateLoginRegister),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
