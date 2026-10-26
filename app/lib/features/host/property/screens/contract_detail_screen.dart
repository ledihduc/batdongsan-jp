import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/models/contract_model.dart';
import 'package:house_booking/data/repositories/api_contract_repository.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/features/host/property/providers/contract_provider.dart';
import 'package:house_booking/features/host/property/providers/room_provider.dart';
import 'package:house_booking/features/host/property/screens/contract_terminate_screen.dart';
import 'package:house_booking/features/host/property/screens/contract_transfer_room_screen.dart';

/// Screen: Contract detail — shows all fields, tenant list, action buttons.
///
/// Converted to StatefulWidget (H6) so it can fetch the contract by ID
/// when the contract is not already in provider state (e.g. deep-link).
class ContractDetailScreen extends StatefulWidget {
  final int contractId;

  const ContractDetailScreen({super.key, required this.contractId});

  @override
  State<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends State<ContractDetailScreen> {
  /// Locally fetched contract — used when the contract is absent from provider.
  ContractModel? _localContract;
  bool _fetchingLocal = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureContractLoaded();
    });
  }

  /// If the contract is not already in the provider's list, fetch it directly.
  Future<void> _ensureContractLoaded() async {
    final provider = context.read<ContractProvider>();
    final found = _findInProvider(provider);
    if (found != null) return;

    setState(() => _fetchingLocal = true);
    try {
      final repo = ApiContractRepository();
      final contract = await repo.getContract(widget.contractId);
      if (mounted) setState(() => _localContract = contract);
    } catch (_) {
      // If fetch fails the "not found" UI is shown — acceptable.
    } finally {
      if (mounted) setState(() => _fetchingLocal = false);
    }
  }

  ContractModel? _findInProvider(ContractProvider p) {
    try {
      return p.contracts.firstWhere((c) => c.id == widget.contractId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Consumer<ContractProvider>(
      builder: (_, provider, _) {
        final contract = _findInProvider(provider) ?? _localContract;

        if (_fetchingLocal && contract == null) {
          return Scaffold(
            backgroundColor: HD.paper,
            appBar: DsAppBar(title: l.hContractDetTitle, eyebrow: l.hContractDetTitle),
            body: const Center(
              child: CircularProgressIndicator(
                color: HD.ink,
                strokeWidth: 1.5,
              ),
            ),
          );
        }

        if (contract == null) {
          return Scaffold(
            backgroundColor: HD.paper,
            appBar: DsAppBar(title: l.hContractDetTitle, eyebrow: l.hContractDetTitle),
            body: Center(
              child: Text(
                l.hContractDetNotFound,
                style: HD.body(color: HD.inkMuted),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: HD.paper,
          appBar: DsAppBar(
            title: '#${contract.id}',
            eyebrow: l.hContractDetTitle,
          ),
          body: ListView(
            padding: const EdgeInsets.all(HD.s16),
            children: [
              _statusBadge(contract.status),
              const SizedBox(height: HD.s12),
              _infoRow(l.hContractDetStartDate, contract.startDate),
              _infoRow(l.hContractDetEndDate, contract.endDate),
              _infoRow(l.hContractDetRent,
                  l.hContractDetRentPerMonth(contract.monthlyRent.toStringAsFixed(0))),
              _infoRow(l.hContractDetDeposit,
                  l.hContractDetAmountDong(contract.deposit.toStringAsFixed(0))),
              const SizedBox(height: HD.s12),
              const HDHairline(),
              const SizedBox(height: HD.s16),

              // Tenants
              Text(l.hContractDetTenants, style: HD.bodyBold()),
              const SizedBox(height: HD.s8),
              ...contract.tenants.map((ct) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline, color: HD.inkSoft),
                    title: Text(ct.tenant.fullName, style: HD.body(color: HD.ink)),
                    subtitle: ct.tenant.phone.isEmpty
                        ? null
                        : Text(ct.tenant.phone, style: HD.caption()),
                    trailing: ct.isPrimary
                        ? DsStatusPill(
                            label: l.hContractDetRepresentative,
                            tone: DsStatusTone.accent,
                            dense: true,
                          )
                        : null,
                  )),
              const SizedBox(height: HD.s8),
              const HDHairline(),
              const SizedBox(height: HD.s16),

              // Action buttons
              if (contract.isDraft)
                DsButton(
                  label: l.hContractDetActivate,
                  icon: Icons.check_circle_outline,
                  expand: true,
                  onPressed: () => _activateWithConfirm(contract, provider),
                ),
              if (contract.isActive) ...[
                DsButton(
                  label: l.hContractDetCheckout,
                  icon: Icons.logout,
                  variant: DsButtonVariant.destructive,
                  expand: true,
                  onPressed: () => _openTerminate(contract, provider),
                ),
                const SizedBox(height: HD.s8),
                DsButton(
                  label: l.hContractDetTransferRoom,
                  icon: Icons.swap_horiz,
                  variant: DsButtonVariant.secondary,
                  expand: true,
                  onPressed: () => _openTransfer(contract, provider),
                ),
              ],

              if (contract.isTerminated) ...[
                const SizedBox(height: HD.s8),
                _infoRow(l.hContractDetActualEndDate, contract.actualEndDate ?? '-'),
                _infoRow(l.hContractDetDepositRefund,
                    l.hContractDetAmountDong((contract.depositRefundAmount ?? 0).toStringAsFixed(0))),
                if (contract.damageNote != null)
                  _infoRow(l.hContractDetDamage, contract.damageNote!),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// H2: confirmation before activating contract (room → occupied).
  Future<void> _activateWithConfirm(
      ContractModel contract, ContractProvider provider) async {
    final l = AppLocalizations.of(context);
    final ok = await showDsConfirm(
      context: context,
      eyebrow: l.hContractDetActivateEyebrow,
      title: l.hContractDetActivate,
      message: l.hContractDetActivateConfirmMsg,
      confirmLabel: l.hContractDetActivateEyebrow,
    );
    if (!ok || !mounted) return;

    final result = await provider.activateContract(contract.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result != null
            ? l.hContractDetActivateSuccess
            : provider.error ?? l.hContractDetFailed),
      ),
    );
  }

  /// Open terminate screen; H10: listen for result=true and pop self.
  void _openTerminate(ContractModel contract, ContractProvider provider) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: ContractTerminateScreen(contractId: contract.id),
        ),
      ),
    ).then((terminated) {
      if (terminated == true && mounted) {
        Navigator.pop(context);
      }
    });
  }

  /// Open transfer screen with BuildingProvider + RoomProvider in scope (C6).
  void _openTransfer(ContractModel contract, ContractProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider.value(
                value: context.read<BuildingProvider>()),
            ChangeNotifierProvider(create: (_) => RoomProvider()),
          ],
          child: ContractTransferRoomScreen(contractId: contract.id),
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _statusBadge(String status) {
    final l = AppLocalizations.of(context);
    final (label, tone) = switch (status) {
      'draft' => (l.hContractDetStatusDraft, DsStatusTone.neutral),
      'active' => (l.hContractDetStatusActive, DsStatusTone.positive),
      'expired' => (l.hContractDetStatusExpired, DsStatusTone.warning),
      'terminated' => (l.hContractDetStatusTerminated, DsStatusTone.negative),
      _ => (status, DsStatusTone.neutral),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: DsStatusPill(label: label, tone: tone),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HD.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: HD.caption()),
          ),
          Expanded(
            child: Text(value, style: HD.bodyBold(size: 13)),
          ),
        ],
      ),
    );
  }
}
