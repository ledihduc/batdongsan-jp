/// 個人情報の取扱い settings screen — lists consents + revoke + DSR flows.
///
/// Route: /settings/privacy (GoRoute, JP-gated).
/// Provider: none — uses [IConsentRepository] via constructor injection.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/repositories/jp/mock_consent_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_consent_repository.dart';
import 'package:house_booking/features/consent/account_deletion_screen.dart';
import 'package:house_booking/features/consent/data_export_request_screen.dart';
import 'package:house_booking/features/consent/models/consent_purpose.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Route: /settings/privacy
class ConsentSettingsScreen extends StatefulWidget {
  const ConsentSettingsScreen({super.key, this.repository});

  final IConsentRepository? repository;

  @override
  State<ConsentSettingsScreen> createState() => _ConsentSettingsScreenState();
}

class _ConsentSettingsScreenState extends State<ConsentSettingsScreen> {
  late final IConsentRepository _repo;
  List<ConsentRecord> _consents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MockConsentRepository();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _repo.listConsents();
      if (mounted) setState(() {
        _consents = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revoke(ConsentPurpose purpose) async {
    try {
      await _repo.revokeConsent(purpose);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        eyebrow: '個人情報',
        title: l.appi_privacy_settings_title,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : ListView(
              children: [
                // Consent list section
                DsFormSection(
                  title: l.appi_consent_list_title,
                  children: _consents.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(l.appi_no_consents,
                                style: HD.body()),
                          ),
                        ]
                      : _consents.map((r) => _ConsentTile(
                            record: r,
                            onRevoke: isConsentPurposeRequired(r.purpose)
                                ? null
                                : () => _revoke(r.purpose),
                            l: l,
                          )).toList(),
                ),
                // Data subject rights section
                DsFormSection(
                  title: l.data_export_request,
                  children: [
                    DsListTile(
                      leading: const Icon(Icons.download_outlined,
                          color: HD.inkMuted, size: 20),
                      title: l.data_export_title,
                      subtitle: l.data_export_description,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              DataExportRequestScreen(repository: _repo),
                        ),
                      ),
                    ),
                    DsListTile(
                      leading: const Icon(Icons.delete_outline,
                          color: HD.accent, size: 20),
                      title: l.jp_deletion_title,
                      subtitle: l.jp_deletion_settings_subtitle,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AccountDeletionScreen(
                            repository: _repo,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.record,
    required this.l,
    this.onRevoke,
  });

  final ConsentRecord record;
  final AppLocalizations l;
  final VoidCallback? onRevoke;

  String _purposeLabel() {
    switch (record.purpose) {
      case ConsentPurpose.serviceUse:
        return l.appi_purpose_service_use;
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
    final dateStr = record.grantedAt?.split('T').firstOrNull ?? '';
    return DsListTile(
      leading: Icon(
        record.granted ? Icons.check_circle_outline : Icons.cancel_outlined,
        color: record.granted ? Colors.green : HD.inkMuted,
        size: 20,
      ),
      title: _purposeLabel(),
      subtitle: record.granted
          ? '${l.appi_consent_granted_on}: $dateStr'
          : l.appi_consent_revoked,
      trailing: onRevoke != null && record.granted
          ? TextButton(
              onPressed: onRevoke,
              child: Text(l.appi_revoke_consent,
                  style: HD.body(size: 12).copyWith(color: HD.accent)),
            )
          : null,
    );
  }
}
