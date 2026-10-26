/// Owner-side: view + manage one delegation — pause/resume/terminate, update thresholds.
///
/// Covers AC-09, AC-10, AC-31b. Read-only banner when viewing as mình mode (AC-18).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/models/operator_delegation_model.dart';
import 'package:house_booking/providers/delegation_provider.dart';
import 'package:house_booking/features/host/delegation/threshold_config_widget.dart';

class DelegationDetailScreen extends StatefulWidget {
  const DelegationDetailScreen({
    super.key,
    required this.delegationId,
  });

  final String delegationId;

  @override
  State<DelegationDetailScreen> createState() =>
      _DelegationDetailScreenState();
}

class _DelegationDetailScreenState extends State<DelegationDetailScreen> {
  OperatorDelegationModel? _delegation;
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _showThresholds = false;
  DelegationThresholds _editedThresholds = const DelegationThresholds();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prov = context.read<DelegationProvider>();
    // Find from cached owner list first.
    final cached = prov.myDelegationsAsOwner
        .where((d) => d.id == widget.delegationId)
        .firstOrNull;

    if (cached != null) {
      setState(() {
        _delegation = cached;
        _editedThresholds = cached.thresholds ?? const DelegationThresholds();
        _isLoading = false;
      });
    } else {
      await prov.fetchMyDelegationsAsOwner();
      if (!mounted) return;
      final loaded = prov.myDelegationsAsOwner
          .where((d) => d.id == widget.delegationId)
          .firstOrNull;
      setState(() {
        _delegation = loaded;
        _editedThresholds =
            loaded?.thresholds ?? const DelegationThresholds();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: HD.paper,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final d = _delegation;
    if (d == null) {
      return Scaffold(
        backgroundColor: HD.paper,
        appBar: DsAppBar(title: l.hDelegDetNotFound, compact: true),
        body: DsEmptyState(
          icon: Icons.search_off_outlined,
          title: l.hDelegDetNotFoundDelegation,
        ),
      );
    }

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: d.operatorName ?? l.hDelegDetOperator,
        eyebrow: l.hDelegDetEyebrow,
        compact: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(HD.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusCard(delegation: d),
            const SizedBox(height: HD.s16),
            _ActionButtons(
              delegation: d,
              isUpdating: _isUpdating,
              onPause: () => _pause(d),
              onResume: () => _resume(d),
              onTerminate: () => _confirmTerminate(d),
            ),
            const SizedBox(height: HD.s24),
            _ThresholdsSection(
              delegation: d,
              showEditor: _showThresholds,
              editedThresholds: _editedThresholds,
              onToggle: () =>
                  setState(() => _showThresholds = !_showThresholds),
              onChanged: (t) => setState(() => _editedThresholds = t),
              onSave: () => _saveThresholds(d),
              isSaving: _isUpdating,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pause(OperatorDelegationModel d) async {
    final l = AppLocalizations.of(context);
    setState(() => _isUpdating = true);
    final updated = await context
        .read<DelegationProvider>()
        .pauseDelegation(d.id);
    if (!mounted) return;
    setState(() {
      _delegation = updated ?? _delegation;
      _isUpdating = false;
    });
    if (updated != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hDelegDetPausedToast)),
      );
    }
  }

  Future<void> _resume(OperatorDelegationModel d) async {
    final l = AppLocalizations.of(context);
    setState(() => _isUpdating = true);
    final updated = await context
        .read<DelegationProvider>()
        .resumeDelegation(d.id);
    if (!mounted) return;
    setState(() {
      _delegation = updated ?? _delegation;
      _isUpdating = false;
    });
    if (updated != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hDelegDetResumedToast)),
      );
    }
  }

  Future<void> _confirmTerminate(OperatorDelegationModel d) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => DsDialog(
        title: l.hDelegDetTerminateTitle,
        bodyText: l.hDelegDetTerminateBody,
        actions: [
          DsButton(
            label: l.cancel,
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          DsButton(
            label: l.hDelegDetTerminate,
            variant: DsButtonVariant.destructive,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isUpdating = true);
    final updated = await context
        .read<DelegationProvider>()
        .terminateDelegation(d.id);
    if (!mounted) return;
    setState(() {
      _delegation = updated ?? _delegation;
      _isUpdating = false;
    });
    if (updated != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hDelegDetTerminatedToast)),
      );
      context.pop();
    }
  }

  Future<void> _saveThresholds(OperatorDelegationModel d) async {
    final l = AppLocalizations.of(context);
    setState(() => _isUpdating = true);
    final updated = await context
        .read<DelegationProvider>()
        .updateThresholds(d.id, _editedThresholds);
    if (!mounted) return;
    setState(() {
      _delegation = updated ?? _delegation;
      _showThresholds = false;
      _isUpdating = false;
    });
    if (updated != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hDelegDetThresholdsUpdatedToast)),
      );
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.delegation});
  final OperatorDelegationModel delegation;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DsCard(
      padding: const EdgeInsets.all(HD.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                delegation.operatorName ?? l.hDelegDetOperator,
                style: HD.bodyBold(color: HD.ink),
              ),
              const Spacer(),
              DsStatusPill(
                label: _statusLabel(l, delegation.status),
                tone: _statusTone(delegation.status),
              ),
            ],
          ),
          const SizedBox(height: HD.s8),
          Text(
            l.hDelegDetPermissionLabel(_roleLabel(l, delegation.rolePreset)),
            style: HD.body(color: HD.inkSoft),
          ),
          Text(
            l.hDelegDetStartLabel(_formatDate(delegation.createdAt)),
            style: HD.caption(color: HD.inkMuted),
          ),
          Text(
            l.hDelegDetPropertiesLabel(delegation.propertyCount),
            style: HD.caption(color: HD.inkMuted),
          ),
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l, DelegationStatus status) {
    switch (status) {
      case DelegationStatus.active:
        return l.hDelegDetStatusActive;
      case DelegationStatus.paused:
        return l.hDelegDetStatusPaused;
      case DelegationStatus.terminated:
        return l.hDelegDetStatusTerminated;
      default:
        return status.name;
    }
  }

  DsStatusTone _statusTone(DelegationStatus status) {
    switch (status) {
      case DelegationStatus.active:
        return DsStatusTone.positive;
      case DelegationStatus.paused:
        return DsStatusTone.warning;
      case DelegationStatus.terminated:
        return DsStatusTone.negative;
      default:
        return DsStatusTone.neutral;
    }
  }

  String _roleLabel(AppLocalizations l, DelegationRolePreset preset) {
    switch (preset) {
      case DelegationRolePreset.operatorFull:
        return l.hDelegDetRoleOperatorFull;
      case DelegationRolePreset.accountant:
        return l.hDelegDetRoleAccountant;
      case DelegationRolePreset.viewer:
        return l.hDelegDetRoleViewer;
      case DelegationRolePreset.ownerView:
        return l.hDelegDetRoleOwnerView;
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.delegation,
    required this.isUpdating,
    required this.onPause,
    required this.onResume,
    required this.onTerminate,
  });

  final OperatorDelegationModel delegation;
  final bool isUpdating;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onTerminate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (delegation.status == DelegationStatus.terminated) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        if (delegation.isActive) ...[
          Expanded(
            child: DsButton(
              label: l.hDelegDetPause,
              icon: Icons.pause_outlined,
              variant: DsButtonVariant.secondary,
              isLoading: isUpdating,
              onPressed: onPause,
            ),
          ),
          const SizedBox(width: HD.s12),
        ],
        if (delegation.isPaused) ...[
          Expanded(
            child: DsButton(
              label: l.hDelegDetResume,
              icon: Icons.play_arrow_outlined,
              variant: DsButtonVariant.secondary,
              isLoading: isUpdating,
              onPressed: onResume,
            ),
          ),
          const SizedBox(width: HD.s12),
        ],
        Expanded(
          child: DsButton(
            label: l.hDelegDetTerminate,
            icon: Icons.cancel_outlined,
            variant: DsButtonVariant.destructive,
            isLoading: isUpdating,
            onPressed: onTerminate,
          ),
        ),
      ],
    );
  }
}

class _ThresholdsSection extends StatelessWidget {
  const _ThresholdsSection({
    required this.delegation,
    required this.showEditor,
    required this.editedThresholds,
    required this.onToggle,
    required this.onChanged,
    required this.onSave,
    required this.isSaving,
  });

  final OperatorDelegationModel delegation;
  final bool showEditor;
  final DelegationThresholds editedThresholds;
  final VoidCallback onToggle;
  final ValueChanged<DelegationThresholds> onChanged;
  final VoidCallback onSave;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l.hDelegDetThresholds,
                style: HD.bodyBold(color: HD.ink)),
            const Spacer(),
            DsButton(
              label: showEditor ? l.cancel : l.hDelegDetEdit,
              variant: DsButtonVariant.ghost,
              size: DsButtonSize.compact,
              onPressed: onToggle,
            ),
          ],
        ),
        if (showEditor) ...[
          const SizedBox(height: HD.s12),
          ThresholdConfigWidget(
            initial: editedThresholds,
            onChanged: onChanged,
          ),
          const SizedBox(height: HD.s16),
          DsButton(
            label: l.hDelegDetSaveThresholds,
            expand: true,
            isLoading: isSaving,
            onPressed: onSave,
          ),
        ],
      ],
    );
  }
}
