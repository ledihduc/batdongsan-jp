/// Xác nhận action ghi do AI đề xuất (link MCP). Route: /ai-confirm/:token (cả bản jp và vn, D19).
/// Provider: AuthProvider (chỉ đọc trạng thái đăng nhập). API: GET /api/ai/actions/{token}, POST …/confirm.
///
/// Mở màn chỉ GET; ghi chỉ khi bấm nút. Đăng nhập xong app không quay lại đây (F26) ⇒ hướng dẫn mở lại link.
/// Plan 20261027-1102 Phase 11 (AC14).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/repositories/ai/api_ai_action_repository.dart';
import 'package:house_booking/domain/repositories/ai/i_ai_action_repository.dart';
import 'package:house_booking/features/ai_chat/ai_action_confirm_controller.dart';
import 'package:house_booking/features/ai_chat/widgets/ai_action_messages.dart';
import 'package:house_booking/features/ai_chat/widgets/ai_action_summary_card.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class AiActionConfirmScreen extends StatefulWidget {
  const AiActionConfirmScreen({super.key, required this.token, this.repository, this.isLoggedIn});

  final String token;
  final IAiActionRepository? repository;

  /// `null` ⇒ đọc `AuthProvider.isAuthenticated` (tham số để test không cần provider).
  final bool? isLoggedIn;

  @override
  State<AiActionConfirmScreen> createState() => _AiActionConfirmScreenState();
}

class _AiActionConfirmScreenState extends State<AiActionConfirmScreen> {
  AiActionConfirmController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode;
    final loggedIn = _loggedIn();
    final c = _c;
    if (c == null) {
      _c = AiActionConfirmController(
        widget.repository ?? const ApiAiActionRepository(),
        token: widget.token,
        isLoggedIn: loggedIn,
        lang: lang,
      )..load();
      return;
    }
    // Phiên / ngôn ngữ khôi phục sau frame đầu (mở link = tải lại trang) ⇒ cập nhật, không đọc 1 lần rồi giữ (QA C1, M1).
    c.setLoggedIn(loggedIn);
    c.setLang(lang);
  }

  /// `null` = phiên đăng nhập đang khôi phục. Lắng nghe [AuthProvider] để màn đổi khi khôi phục xong.
  bool? _loggedIn() {
    if (widget.isLoggedIn != null) return widget.isLoggedIn;
    final auth = Provider.of<AuthProvider>(context);
    return auth.isBootstrapping ? null : auth.isAuthenticated;
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  void _leave() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      GoRouter.maybeOf(context)?.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.aiConfirmTitle)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _c!,
          builder: (context, _) {
            final c = _c!;
            if (c.status == AiConfirmStatus.loading) return const Center(child: CircularProgressIndicator());
            final p = c.preview;
            return ListView(
              padding: const EdgeInsets.all(HD.s16),
              children: [
                if (p != null) ...[
                  AiActionSummaryCard(title: p.title, listing: p.listing, params: p.params, expiresAt: p.expiresAt),
                  const SizedBox(height: HD.s12),
                ],
                ..._footer(l, c),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _footer(AppLocalizations l, AiActionConfirmController c) {
    const gap = SizedBox(height: HD.s12);
    Widget note(String text, Color color) => Text(text, style: TextStyle(color: color));
    switch (c.status) {
      case AiConfirmStatus.ready:
      case AiConfirmStatus.submitting:
        final busy = c.status == AiConfirmStatus.submitting;
        return [
          note(l.aiConfirmWarning, HD.negative),
          gap,
          DsButton(label: l.aiConfirmButton, isLoading: busy, expand: true, onPressed: busy ? null : c.confirm),
          gap,
          DsButton(label: l.aiConfirmCancel, variant: DsButtonVariant.ghost, expand: true, onPressed: busy ? null : _leave),
        ];
      case AiConfirmStatus.needLogin:
        return [
          note(l.aiConfirmLoginRequired, HD.ink),
          note(l.aiConfirmReopenAfterLogin, HD.inkMuted),
          gap,
          DsButton(label: l.aiConfirmLoginButton, expand: true, onPressed: () => GoRouter.maybeOf(context)?.push('/login')),
        ];
      case AiConfirmStatus.done:
        return [note(aiConfirmDoneText(l, c.result?.action ?? c.preview?.action ?? ''), HD.positive)];
      case AiConfirmStatus.error:
        return [
          note(aiConfirmErrorText(l, c.errorKind), HD.negative),
          if (c.errorKind == AiConfirmErrorKind.network) ...[
            gap,
            DsButton(label: l.aiChatRetry, variant: DsButtonVariant.secondary, expand: true, onPressed: c.retry),
          ],
        ];
      case AiConfirmStatus.loading:
        return const [];
    }
  }
}
