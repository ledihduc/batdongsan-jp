import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/config/brand.dart';
import 'package:house_booking/core/config/feature_flags.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/login_account_type.dart';
import 'package:house_booking/features/auth/widgets/login_account_type_field.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/features/auth/forgot_password_screen.dart';
import 'package:house_booking/core/utils/dinh_danh.dart';
import 'package:house_booking/features/auth/register_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';

/// Account selection and password login. Route: /login. Provider: AuthProvider.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.coLoiThoat = true});

  /// Có vẽ nút thoát ở góc trái trên hay không.
  ///
  /// Mặc định CÓ: `/login` được push từ bottom-sheet, hoặc redirect từ `/host`,
  /// hoặc mở thẳng bằng link — cả ba trường hợp khách đổi ý đều phải ra được.
  /// Chỉ `_RootGate` truyền `false`: khi tắt `FeatureFlags.guestBrowse` thì
  /// màn này CHÍNH LÀ `/`, không có chỗ nào để thoát về.
  final bool coLoiThoat;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountFieldKey = GlobalKey();

  /// Một ô cho CẢ email lẫn số điện thoại — xem `_dinhDanhValidator`.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  LoginAccountType? _accountType;
  bool _accountTypeMismatch = false;

  // Bật lại khi tích hợp OAuth thật (kèm Sign in with Apple trên iOS — Apple 4.8).
  static const bool _socialLoginEnabled = false;

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (auth.isLoading) return;
    if (!_formKey.currentState!.validate()) {
      if (_accountType == null) _showAccountField();
      return;
    }
    // Capture the router before notifying auth listeners: the root login gate
    // can unmount this form as soon as the user becomes authenticated.
    final router = GoRouter.of(context);
    FocusScope.of(context).unfocus();
    setState(() => _accountTypeMismatch = false);
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
      accountType: _accountType,
    );
    if (success) {
      _goTo(router, auth.loginLocation);
    } else if (mounted) {
      if (auth.accountTypeMismatch) {
        setState(() => _accountTypeMismatch = true);
        _showAccountField();
        return;
      }
      AppFeedback.error(
        context,
        auth.errorMessage ?? AppLocalizations.of(context).loginFailed,
      );
    }
  }

  void _showAccountField() {
    final fieldContext = _accountFieldKey.currentContext;
    if (fieldContext != null) {
      Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Lối ra cho khách đổi ý. Pop nếu có màn phía dưới; không có thì `go('/')`.
  ///
  /// Dùng `Navigator.canPop` chứ không phải `context.canPop()` của GoRouter:
  /// màn này còn được mở bằng `Navigator.push` ở vài chỗ, GoRouter không thấy
  /// những route đó nên sẽ báo không pop được rồi `go('/')` — bỏ lại một màn
  /// mồ côi trong stack.
  void _thoat() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      context.go('/');
    }
  }

  void _goTo(GoRouter router, String location) {
    // GoRouter cannot remove a login route opened with Navigator.push when
    // the target URL is already current. Close that route before navigating.
    // Auth listeners may already have replaced it by the time login returns.
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    }
    router.go(location);
  }

  void _oauthMaintenance(String provider) {
    AppFeedback.info(
      context,
      AppLocalizations.of(context).loginOauthMaintenance(provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final l = AppLocalizations.of(context);

    return HDGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      HD.s24,
                      widget.coLoiThoat ? 64 : HD.s32,
                      HD.s24,
                      HD.s32,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Masthead(),
                          const SizedBox(height: HD.s24),
                          DsFormSection(
                            title: l.loginButton,
                            padding: EdgeInsets.zero,
                            children: [
                              LoginAccountTypeField(
                                key: _accountFieldKey,
                                enabled: !isLoading,
                                serverError: _accountTypeMismatch
                                    ? l.loginAccountTypeMismatch
                                    : null,
                                onChanged: (type) => setState(() {
                                  _accountType = type;
                                  _accountTypeMismatch = false;
                                }),
                              ),
                              DsTextField(
                                controller: _emailController,
                                enabled: !isLoading,
                                label: l.loginIdentifier,
                                hint: l.identifierHint,
                                prefixIcon: Icons.mail_outline,
                                // `emailAddress` khoá bàn phím vào chữ + '@'.
                                // Một ô nhận cả số thì phải mở bàn phím
                                // đầy đủ, không thì người gõ số phải
                                // chuyển bàn phím tay ngay ở bước đầu tiên.
                                keyboardType: TextInputType.text,
                                textInputAction: TextInputAction.next,
                                validator: (v) => _dinhDanhValidator(v, l),
                              ),
                              DsTextField(
                                controller: _passwordController,
                                enabled: !isLoading,
                                label: l.loginPassword,
                                hint: l.passwordHint,
                                prefixIcon: Icons.lock_outline,
                                suffixIcon: _isPasswordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                onSuffixTap: isLoading
                                    ? null
                                    : () => setState(
                                        () => _isPasswordVisible =
                                            !_isPasswordVisible,
                                      ),
                                obscureText: !_isPasswordVisible,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                validator: (v) => _passwordValidator(v, l),
                              ),
                            ],
                          ),
                          const SizedBox(height: HD.s4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: DsButton(
                              label: l.loginForgot,
                              variant: DsButtonVariant.ghost,
                              size: DsButtonSize.compact,
                              onPressed: isLoading
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ForgotPasswordScreen(),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: HD.s16),
                          DsButton(
                            key: const ValueKey('login-submit'),
                            label: l.loginButton,
                            variant: DsButtonVariant.primary,
                            size: DsButtonSize.large,
                            expand: true,
                            isLoading: isLoading,
                            onPressed: isLoading ? null : _submit,
                          ),
                          if (FeatureFlags.guestBrowse &&
                              widget.coLoiThoat) ...[
                            const SizedBox(height: HD.s12),
                            DsButton(
                              key: const ValueKey('login-guest-browse'),
                              label: l.loginGuestBrowse,
                              variant: DsButtonVariant.secondary,
                              icon: Icons.person_outline,
                              expand: true,
                              onPressed: isLoading
                                  ? null
                                  : () => _goTo(GoRouter.of(context), '/'),
                            ),
                          ],
                          // Đăng nhập mạng xã hội CHƯA hoạt động (Google/Facebook OAuth
                          // chưa tích hợp). Ẩn để tránh nút "bảo trì" gây Apple từ chối
                          // (Guideline 2.1). Bật lại khi OAuth thật xong — và trên iOS
                          // BẮT BUỘC kèm Sign in with Apple (Guideline 4.8).
                          if (_socialLoginEnabled) ...[
                            const SizedBox(height: HD.s32),
                            _OrDivider(),
                            const SizedBox(height: HD.s16),
                            DsButton(
                              label: l.loginContinueGoogle,
                              variant: DsButtonVariant.secondary,
                              icon: Icons.g_mobiledata,
                              expand: true,
                              onPressed: () => _oauthMaintenance('Google'),
                            ),
                            const SizedBox(height: HD.s8),
                            DsButton(
                              label: l.loginContinueFacebook,
                              variant: DsButtonVariant.secondary,
                              icon: Icons.facebook,
                              expand: true,
                              onPressed: () => _oauthMaintenance('Facebook'),
                            ),
                          ],
                          const SizedBox(height: HD.s32),
                          _SignUpPrompt(enabled: !isLoading),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.coLoiThoat)
                Positioned(top: HD.s8, left: HD.s8, child: _nutThoat(l)),
            ],
          ),
        ),
      ),
    );
  }

  /// Nút thoát góc trái trên. Không có nó thì khách bấm nhầm "Đăng nhập" là
  /// kẹt: màn này không có AppBar, và khi tới bằng redirect/deep-link thì
  /// cũng không có gì để bấm back.
  Widget _nutThoat(AppLocalizations l) {
    final quayLaiDuoc = Navigator.of(context).canPop();
    return Material(
      color: HD.paperRaised,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: context.watch<AuthProvider>().isLoading ? null : _thoat,
        child: Tooltip(
          message: quayLaiDuoc ? l.hdBack : l.loginExitHome,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              quayLaiDuoc ? Icons.arrow_back : Icons.home_outlined,
              size: 20,
              color: HD.ink,
            ),
          ),
        ),
      ),
    );
  }

  /// Ô đăng nhập nhận CẢ HAI: email hoặc số điện thoại.
  ///
  /// Chỉ kiểm hình dạng để báo sớm; quyền phán quyết vẫn ở máy chủ (xem
  /// `core/utils/dinh_danh.dart`). Thông báo lỗi nói theo thứ người dùng ĐANG
  /// gõ — gõ số mà bị mắng "email chưa đúng định dạng" thì họ không hiểu.
  String? _dinhDanhValidator(String? value, AppLocalizations l) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return l.valIdentifierRequired;
    if (!DinhDanh.hopLe(v)) {
      return DinhDanh.laEmail(v) ? l.valEmailInvalid : l.valPhoneInvalid;
    }
    return null;
  }

  String? _passwordValidator(String? value, AppLocalizations l) {
    if (value == null || value.isEmpty) return l.valPasswordRequired;
    if (value.length < 6) return l.valPasswordMin;
    return null;
  }
}

class _Masthead extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const BrandLogo.full(size: 64),
        const SizedBox(height: HD.s12),
        Text(AppLocalizations.of(context).loginEyebrow, style: HD.eyebrow()),
        const SizedBox(height: HD.s4),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(text: Brand.logoPart1, style: HD.masthead(size: 38)),
              TextSpan(
                text: Brand.logoPart2,
                style: HD.mastheadItalic(color: HD.accent, size: 38),
              ),
            ],
          ),
        ),
        const SizedBox(height: HD.s4),
        Text(
          AppLocalizations.of(context).loginTagline,
          textAlign: TextAlign.center,
          style: HD.body(size: 13),
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: HDHairline()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: HD.s12),
          child: Text(
            AppLocalizations.of(context).loginOr,
            style: HD.eyebrow(),
          ),
        ),
        const Expanded(child: HDHairline()),
      ],
    );
  }
}

class _SignUpPrompt extends StatelessWidget {
  const _SignUpPrompt({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // `Wrap` chứ không phải `Row`: khung form khoá ở 440px, mà cụm này là
    // "chữ + nút" nên bản dịch dài hơn một chút là tràn ngang. Wrap thì nút
    // rơi xuống dòng dưới thay vì bị cắt.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(AppLocalizations.of(context).loginNoAccount, style: HD.body()),
        DsButton(
          label: AppLocalizations.of(context).loginRegisterNow,
          variant: DsButtonVariant.ghost,
          size: DsButtonSize.compact,
          onPressed: !enabled
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
        ),
      ],
    );
  }
}
