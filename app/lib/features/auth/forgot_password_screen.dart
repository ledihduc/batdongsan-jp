import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _api = const ApiClient();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      AppFeedback.error(context, l.forgotValidateEmail);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await _api.post(
        '/api/auth/forgot-password',
        body: {'email': email},
      );
      if (!mounted) return;
      // KHÔNG đọc `temp_password`. Bản trước của màn này lấy trường đó rồi HIỆN
      // MẬT KHẨU TẠM ra màn hình kèm nút copy — đúng nửa client của lỗ hổng đã
      // vá 27/07: endpoint cũ nhận một email bất kỳ, đổi luôn mật khẩu của chủ
      // tài khoản rồi trả chính mật khẩu đó về, nên ai biết email là chiếm được
      // tài khoản. Backend nay không bao giờ gửi trường này nữa; giữ chỗ đọc nó
      // ở đây chỉ để lại một khẩu súng đã lên đạn, chờ ai đó "hoàn thiện" nốt
      // phía server là lỗ hổng mở lại nguyên vẹn.
      //
      // Khi dựng lại cho tử tế: gửi TOKEN có hạn + dùng-một-lần qua email,
      // KHÔNG đổi mật khẩu cho tới khi người dùng bấm link. Mật khẩu không bao
      // giờ được đi qua màn hình này.
      final message = res['message'] as String? ?? l.forgotDialogBody;
      await showDialog<void>(
        context: context,
        barrierColor: HD.ink.withValues(alpha: 0.32),
        builder: (ctx) => DsDialog(
          eyebrow: l.forgotDialogEyebrow,
          title: l.forgotDialogTitle,
          body: Text(message, style: HD.body()),
          actions: [
            DsButton(
              label: l.forgotGotIt,
              variant: DsButtonVariant.primary,
              size: DsButtonSize.compact,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) AppFeedback.error(context, e.message);
    } catch (e) {
      if (mounted) AppFeedback.error(context, l.forgotError('$e'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(eyebrow: l.forgotAppBarEyebrow, title: l.forgotTitle),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HD.s24,
                vertical: HD.s24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: HD.s8),
                  Text(l.forgotIntro, style: HD.body()),
                  const SizedBox(height: HD.s24),
                  DsTextField(
                    controller: _emailCtrl,
                    label: l.loginEmail,
                    hint: l.forgotEmailHint,
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: HD.s24),
                  DsButton(
                    label: l.forgotSubmit,
                    variant: DsButtonVariant.primary,
                    size: DsButtonSize.large,
                    expand: true,
                    isLoading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
