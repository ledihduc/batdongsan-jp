import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/login_account_type.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Required login context. Selecting an option does not grant account permissions.
class LoginAccountTypeField extends StatelessWidget {
  const LoginAccountTypeField({
    super.key,
    required this.onChanged,
    this.enabled = true,
    this.serverError,
  });

  final ValueChanged<LoginAccountType> onChanged;
  final bool enabled;
  final String? serverError;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FormField<LoginAccountType>(
      validator: (value) => value == null ? l.loginAccountTypeRequired : null,
      builder: (field) {
        final selected = field.value;
        final error = serverError ?? field.errorText;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              enabled: enabled,
              label: l.loginAccountType,
              value: selected?.label(l) ?? l.loginAccountTypeHint,
              child: Material(
                color: selected == null ? HD.paperRaised : HD.accentTint,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HD.r12),
                  side: BorderSide(
                    color: error != null
                        ? HD.negative
                        : selected != null
                        ? HD.accent
                        : HD.hairlineStrong,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('login-account-picker'),
                  onTap: !enabled
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
                          final result =
                              await showDsBottomSheet<LoginAccountType>(
                                context: context,
                                builder: (sheetContext) => DsBottomSheet(
                                  title: l.loginAccountType,
                                  trailing: IconButton(
                                    key: const ValueKey(
                                      'login-account-picker-close',
                                    ),
                                    tooltip: l.loginAccountPickerClose,
                                    onPressed: () =>
                                        Navigator.of(sheetContext).pop(),
                                    icon: const Icon(
                                      Icons.close,
                                      color: HD.inkMuted,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        l.loginAccountPickerHelp,
                                        style: HD.body(),
                                      ),
                                      const SizedBox(height: HD.s16),
                                      for (final type
                                          in LoginAccountType.values) ...[
                                        _AccountOption(
                                          type: type,
                                          selected: type == selected,
                                          onTap: () => Navigator.of(
                                            sheetContext,
                                          ).pop(type),
                                        ),
                                        const SizedBox(height: HD.s8),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                          if (!field.mounted || result == null) return;
                          field.didChange(result);
                          field.validate();
                          onChanged(result);
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(HD.s16),
                    child: Row(
                      children: [
                        _AccountIcon(
                          icon:
                              selected?.icon ?? Icons.manage_accounts_outlined,
                        ),
                        const SizedBox(width: HD.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  text: '${l.loginAccountType} ',
                                  children: [
                                    TextSpan(
                                      text: '*',
                                      style: HD.bodyBold(color: HD.negative),
                                    ),
                                  ],
                                ),
                                style: HD.bodyBold(),
                              ),
                              const SizedBox(height: HD.s4),
                              Text(
                                selected?.label(l) ?? l.loginAccountTypeHint,
                                style: HD.body(
                                  color: selected == null
                                      ? HD.inkMuted
                                      : HD.accentDeep,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: HD.s8),
                        const Icon(
                          Icons.chevron_right,
                          color: HD.inkMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: HD.s8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(error, style: HD.caption(color: HD.negative)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AccountOption extends StatelessWidget {
  const _AccountOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final LoginAccountType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? HD.accentTint : HD.paperRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HD.r12),
          side: BorderSide(color: selected ? HD.accent : HD.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('login-role-${type.name}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(HD.s16),
            child: Row(
              children: [
                _AccountIcon(icon: type.icon),
                const SizedBox(width: HD.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type.label(l), style: HD.bodyBold()),
                      const SizedBox(height: HD.s4),
                      Text(type.description(l), style: HD.caption()),
                    ],
                  ),
                ),
                const SizedBox(width: HD.s8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? HD.accent : HD.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountIcon extends StatelessWidget {
  const _AccountIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: HD.accentSoft,
      borderRadius: BorderRadius.circular(HD.r8),
    ),
    child: Icon(icon, color: HD.accent, size: 24),
  );
}

extension on LoginAccountType {
  String label(AppLocalizations l) => switch (this) {
    LoginAccountType.customer => l.loginRoleCustomer,
    LoginAccountType.sale => l.loginRoleSale,
    LoginAccountType.owner => l.loginRoleOwner,
    LoginAccountType.admin => l.loginRoleAdmin,
  };

  String description(AppLocalizations l) => switch (this) {
    LoginAccountType.customer => l.loginRoleCustomerDescription,
    LoginAccountType.sale => l.loginRoleSaleDescription,
    LoginAccountType.owner => l.loginRoleOwnerDescription,
    LoginAccountType.admin => l.loginRoleAdminDescription,
  };

  IconData get icon => switch (this) {
    LoginAccountType.customer => Icons.person_search_outlined,
    LoginAccountType.sale => Icons.business_center_outlined,
    LoginAccountType.owner => Icons.home_work_outlined,
    LoginAccountType.admin => Icons.admin_panel_settings_outlined,
  };
}
