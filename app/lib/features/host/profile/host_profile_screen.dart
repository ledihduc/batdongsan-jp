import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/providers/host_profile_provider.dart';

/// Host Profile Screen — view and edit profile after onboarding is complete.
class HostProfileScreen extends StatefulWidget {
  const HostProfileScreen({super.key});

  @override
  State<HostProfileScreen> createState() => _HostProfileScreenState();
}

class _HostProfileScreenState extends State<HostProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();

  bool _editing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    final provider = context.read<HostProfileProvider>();
    await provider.fetchProfile();
    if (!mounted) return;
    final p = provider.profile;
    if (p != null) {
      _bankNameCtrl.text = p.bankName ?? '';
      _accountNumberCtrl.text = p.bankAccountNumber ?? '';
      _accountHolderCtrl.text = p.bankAccountHolder ?? '';
      _taxIdCtrl.text = p.taxId ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    final provider = context.read<HostProfileProvider>();
    final ok = await provider.updateProfile(
      bankName: _bankNameCtrl.text.trim().isEmpty
          ? null
          : _bankNameCtrl.text.trim(),
      bankAccountNumber: _accountNumberCtrl.text.trim().isEmpty
          ? null
          : _accountNumberCtrl.text.trim(),
      bankAccountHolder: _accountHolderCtrl.text.trim().isEmpty
          ? null
          : _accountHolderCtrl.text.trim(),
      taxId: _taxIdCtrl.text.trim().isEmpty ? null : _taxIdCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _editing = false);
      AppFeedback.success(context, l.hProfileSavedInfo);
    } else {
      AppFeedback.error(context, provider.error ?? l.hProfileSaveFailed);
    }
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountHolderCtrl.dispose();
    _taxIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.watch<HostProfileProvider>();
    final profile = provider.profile;

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        eyebrow: l.hProfileEyebrow,
        title: l.hProfileTitle,
        actions: [
          if (!_editing && profile != null)
            Padding(
              padding: const EdgeInsets.only(right: HD.s12),
              child: DsButton(
                label: l.hProfileEdit,
                variant: DsButtonVariant.ghost,
                size: DsButtonSize.compact,
                icon: Icons.edit_outlined,
                onPressed: () => setState(() => _editing = true),
              ),
            ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : profile == null
              ? EmptyState(
                  icon: Icons.person_off_outlined,
                  title: l.hProfileEmptyTitle,
                  subtitle: l.hProfileEmptySubtitle,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    HD.s20,
                    HD.s20,
                    HD.s20,
                    HD.s40,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _VerificationBadge(isVerified: profile.verified),
                        const SizedBox(height: HD.s24),
                        _CccdSection(
                          frontUploaded: profile.cccdFrontUploaded,
                          backUploaded: profile.cccdBackUploaded,
                        ),
                        const SizedBox(height: HD.s24),
                        _BankSection(
                          formKey: _formKey,
                          bankNameCtrl: _bankNameCtrl,
                          accountNumberCtrl: _accountNumberCtrl,
                          accountHolderCtrl: _accountHolderCtrl,
                          taxIdCtrl: _taxIdCtrl,
                          editing: _editing,
                        ),
                        if (_editing) ...[
                          const SizedBox(height: HD.s24),
                          DsButton(
                            label: l.hProfileSaveChanges,
                            variant: DsButtonVariant.primary,
                            size: DsButtonSize.large,
                            expand: true,
                            isLoading: provider.isLoading,
                            onPressed: provider.isLoading ? null : _save,
                          ),
                          const SizedBox(height: HD.s8),
                          DsButton(
                            label: l.cancel,
                            variant: DsButtonVariant.ghost,
                            expand: true,
                            onPressed: () {
                              setState(() => _editing = false);
                              _loadProfile();
                            },
                          ),
                        ],
                        if (profile.rating != null) ...[
                          const SizedBox(height: HD.s32),
                          _RatingSection(
                            rating: profile.rating!,
                            avgResponseHours: profile.avgResponseHours,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.isVerified});
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HD.s16,
        vertical: HD.s12,
      ),
      decoration: BoxDecoration(
        color: isVerified ? HD.positiveTint : HD.warningTint,
        borderRadius: BorderRadius.circular(HD.r8),
        border: Border.all(
          color: isVerified ? HD.positive : HD.warning,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isVerified ? Icons.verified_outlined : Icons.pending_outlined,
            size: 20,
            color: isVerified ? HD.positive : HD.warning,
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isVerified ? l.hProfileVerified : l.hProfilePending,
                  style: HD.bodyBold(
                    color: isVerified ? HD.positive : HD.warning,
                    size: 14,
                  ),
                ),
                Text(
                  isVerified
                      ? l.hProfileVerifiedDesc
                      : l.hProfilePendingDesc,
                  style: HD.caption(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CccdSection extends StatelessWidget {
  const _CccdSection({
    required this.frontUploaded,
    required this.backUploaded,
  });

  final bool frontUploaded;
  final bool backUploaded;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.hProfileIdentitySection.toUpperCase(), style: HD.eyebrow()),
        const SizedBox(height: HD.s12),
        DsListGroup(
          children: [
            _CccdRow(label: l.hProfileCccdFront, uploaded: frontUploaded),
            _CccdRow(label: l.hProfileCccdBack, uploaded: backUploaded),
          ],
        ),
      ],
    );
  }
}

class _CccdRow extends StatelessWidget {
  const _CccdRow({required this.label, required this.uploaded});
  final String label;
  final bool uploaded;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DsListTile(
      leading: Icon(
        uploaded ? Icons.check_circle_outline : Icons.radio_button_unchecked,
        size: 20,
        color: uploaded ? HD.positive : HD.inkMuted,
      ),
      title: label,
      trailing: DsStatusPill(
        label: uploaded ? l.hProfileUploaded : l.hProfileNotUploaded,
        tone: uploaded ? DsStatusTone.positive : DsStatusTone.neutral,
      ),
    );
  }
}

class _BankSection extends StatelessWidget {
  const _BankSection({
    required this.formKey,
    required this.bankNameCtrl,
    required this.accountNumberCtrl,
    required this.accountHolderCtrl,
    required this.taxIdCtrl,
    required this.editing,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController bankNameCtrl;
  final TextEditingController accountNumberCtrl;
  final TextEditingController accountHolderCtrl;
  final TextEditingController taxIdCtrl;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.hProfilePaymentSection.toUpperCase(), style: HD.eyebrow()),
        const SizedBox(height: HD.s12),
        DsTextField(
          label: l.hProfileBank,
          controller: bankNameCtrl,
          enabled: editing,
          hint: l.hProfileBankHint,
        ),
        const SizedBox(height: HD.s12),
        DsTextField(
          label: l.hProfileAccountNumber,
          controller: accountNumberCtrl,
          keyboardType: TextInputType.number,
          enabled: editing,
        ),
        const SizedBox(height: HD.s12),
        DsTextField(
          label: l.hProfileAccountHolder,
          controller: accountHolderCtrl,
          enabled: editing,
          hint: l.hProfileAccountHolderHint,
        ),
        const SizedBox(height: HD.s12),
        DsTextField(
          label: l.hProfileTaxId,
          controller: taxIdCtrl,
          keyboardType: TextInputType.number,
          enabled: editing,
        ),
      ],
    );
  }
}

class _RatingSection extends StatelessWidget {
  const _RatingSection({required this.rating, required this.avgResponseHours});
  final double rating;
  final double? avgResponseHours;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.hProfilePerformanceSection.toUpperCase(), style: HD.eyebrow()),
        const SizedBox(height: HD.s12),
        Row(
          children: [
            Expanded(
              child: DsKpiCard(
                label: l.hProfileRating,
                value: rating.toStringAsFixed(1),
                unit: '/ 5',
                icon: Icons.star_outline,
                numeralSize: 36,
              ),
            ),
            if (avgResponseHours != null) ...[
              const SizedBox(width: HD.s12),
              Expanded(
                child: DsKpiCard(
                  label: l.hProfileAvgResponse,
                  value: avgResponseHours!.toStringAsFixed(1),
                  unit: l.hProfileHours,
                  icon: Icons.schedule,
                  numeralSize: 36,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
