import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/config/brand.dart';
import 'package:house_booking/core/config/feature_flags.dart';
import 'package:house_booking/core/config/legal_links.dart';
import 'package:house_booking/features/consent/consent_banner_sheet.dart';
import 'package:house_booking/core/utils/dinh_danh.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/auth/hoan_thien_ho_so_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/house_provider.dart';
import 'package:house_booking/providers/viewing_appointment_provider.dart';
import 'package:house_booking/providers/wishlist_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showPassword = false;
  bool _showConfirm = false;
  bool _agreeTerms = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeTerms) {
      AppFeedback.warning(
        context,
        AppLocalizations.of(context).registerNeedAgree,
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      phone: _phoneCtrl.text.trim(),
      role: 'guest',
    );

    if (!mounted) return;
    if (success) {
      final user = auth.currentUser!;
      context.read<HouseProvider>().fetchInitialData();
      context.read<ViewingAppointmentProvider>().fetchAppointments(
        user.id!,
        user.role,
      );
      context.read<WishlistProvider>().fetch(user.id!);

      // JP builds: show APPI consent banner as final registration step.
      // VN builds: skip — gated by FeatureFlags.isJapan inside the helper.
      if (FeatureFlags.isJapan && mounted) {
        await showConsentBannerSheet(context);
      }

      if (!mounted) return;
      // Hoàn thiện thông tin chung trước khi vào app. Tài khoản mới bắt đầu
      // ở chế độ Khách và có thể chuyển sang Sale hoặc Chủ nhà bất cứ lúc nào.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const HoanThienHoSoScreen(batBuoc: true),
        ),
      );
    } else {
      AppFeedback.error(
        context,
        auth.errorMessage ?? AppLocalizations.of(context).registerFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(eyebrow: l.registerEyebrow, title: l.registerTitle),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: HD.s24,
                vertical: HD.s24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: BrandLogo.full(size: 64),
                    ),
                    const SizedBox(height: HD.s12),
                    Text(l.registerWelcome, style: HD.eyebrow()),
                    const SizedBox(height: HD.s4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: Brand.logoPart1,
                            style: HD.masthead(size: 32),
                          ),
                          TextSpan(
                            text: Brand.logoPart2,
                            style: HD.mastheadItalic(
                              color: HD.accent,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: HD.s8),
                    Text(l.registerSubtitle, style: HD.body()),
                    const SizedBox(height: HD.s24),
                    DsTextField(
                      controller: _nameCtrl,
                      label: l.registerName,
                      prefixIcon: Icons.person_outline,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l.valRequired : null,
                    ),
                    const SizedBox(height: HD.s16),
                    // Email HOẶC số điện thoại — cần ít nhất một, không cần
                    // cả hai. Bắt buộc email là rào chắn ngay cửa vào: nhiều
                    // người bán chỉ dùng Zalo, không có email bao giờ.
                    DsTextField(
                      controller: _emailCtrl,
                      label: l.registerEmailOptional,
                      hint: l.emailHint,
                      prefixIcon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final e = (v ?? '').trim();
                        if (e.isEmpty) {
                          return _phoneCtrl.text.trim().isEmpty
                              ? l.registerNeedEmailOrPhone
                              : null;
                        }
                        return DinhDanh.hopLe(e) && DinhDanh.laEmail(e)
                            ? null
                            : l.valEmailInvalid;
                      },
                    ),
                    const SizedBox(height: HD.s16),
                    DsTextField(
                      controller: _phoneCtrl,
                      label: l.registerPhoneOptional,
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final sdt = (v ?? '').trim();
                        if (sdt.isEmpty) {
                          return _emailCtrl.text.trim().isEmpty
                              ? l.registerNeedEmailOrPhone
                              : null;
                        }
                        // Số sai dạng phải chặn NGAY. Gửi lên rồi backend bỏ
                        // qua thì người dùng tưởng đã đăng ký bằng số đó và
                        // lần sau không đăng nhập được.
                        return DinhDanh.sdtHopLe(sdt) ? null : l.valPhoneInvalid;
                      },
                    ),
                    // Nói TRƯỚC khi họ bấm đăng ký, không phải lúc quên mật
                    // khẩu mới biết. Liên kết đặt lại chỉ gửi qua email.
                    if (_emailCtrl.text.trim().isEmpty) ...[
                      const SizedBox(height: HD.s8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 15,
                            color: HD.inkMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l.registerNoEmailWarning,
                              style: HD.caption(),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: HD.s16),
                    DsTextField(
                      controller: _passwordCtrl,
                      label: l.loginPassword,
                      hint: l.passwordHint,
                      prefixIcon: Icons.lock_outline,
                      obscureText: !_showPassword,
                      suffixIcon: _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      onSuffixTap: () =>
                          setState(() => _showPassword = !_showPassword),
                      validator: (v) {
                        if (v == null || v.isEmpty) return l.valRequired;
                        if (v.length < 6) return l.valPasswordMin;
                        return null;
                      },
                    ),
                    const SizedBox(height: HD.s16),
                    DsTextField(
                      controller: _confirmCtrl,
                      label: l.registerConfirmPassword,
                      prefixIcon: Icons.check_circle_outline,
                      obscureText: !_showConfirm,
                      suffixIcon: _showConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      onSuffixTap: () =>
                          setState(() => _showConfirm = !_showConfirm),
                      validator: (v) {
                        if (v == null || v.isEmpty) return l.valRequired;
                        if (v != _passwordCtrl.text) {
                          return l.valPasswordMismatch;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: HD.s20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _agreeTerms,
                            onChanged: (v) =>
                                setState(() => _agreeTerms = v ?? false),
                          ),
                        ),
                        const SizedBox(width: HD.s12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.registerAgreeTerms,
                                  style: HD.body(size: 13),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 12,
                                  children: [
                                    InkWell(
                                      onTap: () => _openUrl(LegalLinks.terms),
                                      child: Text(
                                        l.termsOfUse,
                                        style: HD
                                            .body(size: 13)
                                            .copyWith(color: HD.accent),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _openUrl(LegalLinks.privacy),
                                      child: Text(
                                        l.privacyPolicy,
                                        style: HD
                                            .body(size: 13)
                                            .copyWith(color: HD.accent),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: HD.s20),
                    DsButton(
                      label: l.registerTitle,
                      variant: DsButtonVariant.primary,
                      size: DsButtonSize.large,
                      expand: true,
                      isLoading: isLoading,
                      onPressed: isLoading ? null : _submit,
                    ),
                    const SizedBox(height: HD.s16),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l.registerHaveAccount, style: HD.body()),
                          DsButton(
                            label: l.loginButton,
                            variant: DsButtonVariant.ghost,
                            size: DsButtonSize.compact,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
