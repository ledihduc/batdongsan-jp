import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/config/feature_flags.dart';
import 'package:house_booking/core/config/legal_links.dart';
import 'package:house_booking/features/guest/profile/blocked_users_screen.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/locale_provider.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/chat_provider.dart';
import 'package:house_booking/providers/notification_provider.dart';
import 'package:house_booking/providers/wishlist_provider.dart';
import 'package:house_booking/features/guest/profile/edit_profile_screen.dart';
import 'package:house_booking/features/guest/profile/change_password_screen.dart';
import 'package:house_booking/features/onboarding/intro_survey_screen.dart';

/// "Cài đặt & quyền riêng tư" — tách khỏi trang Hồ sơ (trước đây là 1 tab thô).
/// Gom cấu hình tài khoản + tuỳ chọn + Đăng xuất (nút đỏ, có xác nhận).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(eyebrow: l.settingsEyebrow, title: l.settingsTitle),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          _title(l.sectionAccount),
          _tile(
            context,
            icon: Icons.person_outline,
            title: l.editProfile,
            subtitle: l.editProfileSub,
            screen: const EditProfileScreen(),
          ),
          _tile(
            context,
            icon: Icons.lock_reset,
            title: l.changePassword,
            screen: const ChangePasswordScreen(),
          ),
          if (FeatureFlags.redesignV2)
            ListTile(
              leading: const Icon(Icons.tune, color: HD.accent),
              title: Text(l.settingsMyPreferences),
              subtitle: Text(l.settingsMyPreferencesSub),
              trailing: const Icon(Icons.chevron_right, color: HD.inkMuted),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => IntroSurveyScreen(
                    editMode: true,
                    onDone: () => Navigator.pop(ctx),
                  ),
                ),
              ),
            ),
          _title(l.sectionPreferences),
          ListTile(
            leading: const Icon(Icons.language, color: HD.accent),
            title: Text(l.language),
            trailing: Text(
              _langName(l, context.watch<LocaleProvider>().locale.languageCode),
              style: const TextStyle(color: HD.inkMuted),
            ),
            onTap: () => _pickLanguage(context, l),
          ),

          // Switch "Thông báo" onChanged rỗng + Dark mode "coming soon" ĐÃ ẨN:
          // nút không làm gì là placeholder gây Apple 2.1 từ chối. Bật lại khi
          // nối cấu hình push / có theme tối thật.
          _title(l.sectionLegal),
          ListTile(
            leading: const Icon(Icons.block, color: HD.accent),
            title: Text(l.blockedUsersTitle),
            subtitle: Text(l.blockedUsersSub),
            trailing: const Icon(Icons.chevron_right, color: HD.inkMuted),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: HD.accent),
            title: Text(l.privacyPolicy),
            trailing: const Icon(
              Icons.open_in_new,
              size: 18,
              color: HD.inkMuted,
            ),
            onTap: () => _openUrl(LegalLinks.privacy),
          ),
          // JP market only: 個人情報の取扱い page (APPI consent + DSR).
          if (FeatureFlags.isJapan)
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined,
                  color: HD.accent),
              title: Text(l.appi_privacy_settings_title),
              trailing: const Icon(
                Icons.chevron_right,
                size: 20,
                color: HD.inkMuted,
              ),
              onTap: () => context.push('/settings/privacy'),
            ),
          ListTile(
            leading: const Icon(Icons.description_outlined, color: HD.accent),
            title: Text(l.termsOfUse),
            trailing: const Icon(
              Icons.open_in_new,
              size: 18,
              color: HD.inkMuted,
            ),
            onTap: () => _openUrl(LegalLinks.terms),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.logout),
              label: Text(
                l.logout,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => logoutFlow(context),
            ),
          ),
          const SizedBox(height: 8),
          // Xoá tài khoản — BẮT BUỘC theo Apple 5.1.1(v) + Google Play. Đặt cuối,
          // kiểu chữ nhạt, có xác nhận mật khẩu để tránh xoá nhầm.
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: HD.inkMuted),
              icon: const Icon(Icons.delete_forever, size: 18),
              label: Text(l.daTitle),
              onPressed: () => xoaTaiKhoanFlow(context, l),
            ),
          ),
        ],
      ),
    );
  }

  /// Hộp thoại xác nhận xoá tài khoản: nhập mật khẩu → gọi AuthProvider.
  /// Thành công thì phiên bị dọn (logout) và về màn gốc.
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _langName(AppLocalizations l, String code) => switch (code) {
    'ja' => '日本語',
    'en' => l.english,
    'zh' => l.chinese,
    _ => l.vietnamese,
  };

  /// Bottom sheet chọn ngôn ngữ → LocaleProvider (lưu + rebuild toàn app).
  void _pickLanguage(BuildContext context, AppLocalizations l) {
    final provider = context.read<LocaleProvider>();
    final current = provider.locale.languageCode;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HD.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [Text(l.chooseLanguage, style: HD.eyebrow())],
              ),
            ),
            for (final e in const [
              ('ja', '日本語'),
              ('vi', 'Tiếng Việt'),
              ('en', 'English'),
              ('zh', '中文'),
            ])
              ListTile(
                leading: Icon(
                  current == e.$1 ? Icons.check : null,
                  color: HD.accent,
                ),
                title: Text(e.$2),
                onTap: () {
                  provider.setLocale(e.$1);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
    child: Text(t, style: HD.eyebrow()),
  );

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget screen,
  }) => ListTile(
    leading: Icon(icon, color: HD.accent),
    title: Text(title),
    subtitle: subtitle != null ? Text(subtitle) : null,
    trailing: const Icon(Icons.chevron_right, color: HD.inkMuted),
    onTap: () =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
  );
}

/// Luồng đăng xuất dùng chung (icon AppBar Hồ sơ + nút trong Cài đặt): xác nhận
/// → clear phiên + provider → điều hướng DỨT KHOÁT về /login (tín hiệu rõ ràng,
/// không để browse-first giữ user trong app khiến tưởng logout không chạy).
Future<void> logoutFlow(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    // PHẢI pop bằng CONTEXT CỦA HỘP THOẠI (dialogCtx), không phải context ngoài:
    // showDialog push lên Navigator GỐC, còn context ngoài (màn Hồ sơ) nằm dưới
    // Navigator LỒNG theo tab (_TabNavigator của GuestShell). Pop bằng context
    // ngoài nhắm nhầm navigator → hộp thoại không đóng, await treo, logout không
    // chạy ("bấm không ra gì", cả ở ẩn danh). Navigator.of(dialogCtx) trỏ đúng
    // navigator gốc nơi hộp thoại được push.
    builder: (dialogCtx) => AlertDialog(
      title: Text(l.logout),
      content: Text(l.settingsLogoutConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, false),
          child: Text(l.cancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.pop(dialogCtx, true),
          child: Text(l.logout),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final auth = Provider.of<AuthProvider>(context, listen: false);
  final wishlist = Provider.of<WishlistProvider>(context, listen: false);
  final notifications = Provider.of<NotificationProvider>(
    context,
    listen: false,
  );
  final chat = Provider.of<ChatProvider>(context, listen: false);
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  await auth.logout();
  // Điều hướng DỨT KHOÁT về /login TRƯỚC khi dọn provider: guestBrowse=true nên
  // thiếu điều hướng thì _RootGate render lại GuestShell-khách → "trông như chưa
  // đăng xuất". Nếu một clear() ném lỗi cũng không được nuốt mất bước điều hướng.
  router.go('/login');
  wishlist.clear();
  notifications.clear();
  chat.clear();
  messenger.showSnackBar(SnackBar(content: Text(l.settingsLoggedOut)));
}

/// Yêu cầu xoá tài khoản — BẮT BUỘC theo Apple 5.1.1(v) + Google Play.
///
/// Đặt ở cấp cao nhất (như [logoutFlow]) vì nay có HAI màn cài đặt gọi tới:
/// bản chung và bản của người bán.
Future<void> xoaTaiKhoanFlow(BuildContext context, AppLocalizations l) async {
  final controller = TextEditingController();
  final auth = context.read<AuthProvider>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Text(l.daDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.daDialogBody),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l.daPasswordHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: Text(l.cancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () {
            if (controller.text.trim().isEmpty) {
              ScaffoldMessenger.of(
                dialogCtx,
              ).showSnackBar(SnackBar(content: Text(l.daPasswordRequired)));
              return;
            }
            Navigator.of(dialogCtx).pop(true);
          },
          child: Text(l.daConfirm),
        ),
      ],
    ),
  );
  if (ok != true) return;
  final success = await auth.deleteAccount(controller.text.trim());
  if (!context.mounted) return;
  if (success) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.daSuccess)));
    context.go('/');
  } else {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(auth.errorMessage ?? l.daFailed)));
  }
}
