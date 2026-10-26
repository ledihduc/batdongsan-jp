/// APPI consent banner bottom sheet — shown at registration for JP users.
///
/// Displays scrollable policy text + per-purpose checkboxes.
/// The "同意する" button is enabled only when ALL required purposes are checked.
///
/// Route: mounted by RegisterScreen (Navigator.push) when FeatureFlags.isJapan.
/// Provider: none — accepts [IConsentRepository] via constructor injection.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/config/feature_flags.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/repositories/jp/mock_consent_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_consent_repository.dart';
import 'package:house_booking/features/consent/models/consent_purpose.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Shows the APPI consent sheet.
///
/// Returns true if consent was granted, false/null if dismissed.
Future<bool> showConsentBannerSheet(
  BuildContext context, {
  IConsentRepository? repository,
}) async {
  // Only show on JP builds.
  if (!FeatureFlags.isJapan) return true;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => ConsentBannerSheet(repository: repository),
  );
  return result ?? false;
}

/// Bottom sheet widget for APPI consent.
class ConsentBannerSheet extends StatefulWidget {
  const ConsentBannerSheet({super.key, this.repository});

  final IConsentRepository? repository;

  @override
  State<ConsentBannerSheet> createState() => _ConsentBannerSheetState();
}

class _ConsentBannerSheetState extends State<ConsentBannerSheet> {
  late final IConsentRepository _repo;

  // Track per-purpose checkbox state.
  final Map<ConsentPurpose, bool> _checked = {
    for (final p in ConsentPurpose.values)
      p: isConsentPurposeRequired(p), // pre-check required purposes
  };

  bool _submitting = false;
  String? _error;

  static const String _policyVersion = '2026-10';

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MockConsentRepository();
  }

  bool get _canSubmit {
    // All required purposes must be checked.
    for (final p in ConsentPurpose.values) {
      if (isConsentPurposeRequired(p) && !(_checked[p] ?? false)) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final granted = _checked.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();
      await _repo.grantConsents(ConsentGrantRequest(
        purposes: granted,
        policyVersion: _policyVersion,
      ));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: HD.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: HD.hairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              l.appi_consent_title,
              style: HD.masthead(size: 20),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          // Scrollable policy text + checkboxes
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: HD.paperRaised,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: HD.hairline),
                    ),
                    child: Text(
                      l.appi_consent_required_notice,
                      style: HD.body(size: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(l.appi_consent_list_title,
                      style: HD.eyebrow()),
                  const SizedBox(height: 8),
                  ...ConsentPurpose.values.map((purpose) =>
                      _PurposeCheckboxTile(
                        purpose: purpose,
                        checked: _checked[purpose] ?? false,
                        onChanged: isConsentPurposeRequired(purpose)
                            ? null // required = locked
                            : (v) => setState(
                                () => _checked[purpose] = v ?? false),
                        l: l,
                      )),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {}, // URL launcher handled by RegisterScreen
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l.appi_privacy_policy_link,
                      style: HD.body(size: 13)
                          .copyWith(color: HD.accent),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: HD.body(size: 12)
                            .copyWith(color: HD.accent)),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Sticky footer
          Padding(
            padding: EdgeInsets.fromLTRB(
                24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            child: DsButton(
              label: l.appi_i_agree,
              variant: DsButtonVariant.primary,
              size: DsButtonSize.large,
              expand: true,
              isLoading: _submitting,
              onPressed: (_canSubmit && !_submitting) ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// One row in the consent purposes list.
class _PurposeCheckboxTile extends StatelessWidget {
  const _PurposeCheckboxTile({
    required this.purpose,
    required this.checked,
    required this.l,
    this.onChanged,
  });

  final ConsentPurpose purpose;
  final bool checked;
  final ValueChanged<bool?>? onChanged;
  final AppLocalizations l;

  String _label() {
    switch (purpose) {
      case ConsentPurpose.serviceUse:
        return '${l.appi_purpose_service_use} ★';
      case ConsentPurpose.marketing:
        return l.appi_purpose_marketing;
      case ConsentPurpose.analytics:
        return l.appi_purpose_analytics;
      case ConsentPurpose.dataSharingBroker:
        return l.appi_purpose_data_sharing_broker;
      case ConsentPurpose.dataSharingHoshou:
        return l.appi_purpose_data_sharing_hoshou;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRequired = isConsentPurposeRequired(purpose);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: checked,
              onChanged: onChanged,
              fillColor: isRequired
                  ? WidgetStatePropertyAll(HD.accent)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _label(),
                style: HD.body(size: 13).copyWith(
                  color: isRequired ? HD.ink : HD.inkMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
