/// Invitation inbox screen — operator views pending delegation invitations.
///
/// Displays list of pending invitations from owners. Each row shows owner name,
/// role preset, and accept/reject CTAs.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/delegation_invitation_model.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/delegation_provider.dart';

class InvitationInboxScreen extends StatefulWidget {
  const InvitationInboxScreen({super.key});

  @override
  State<InvitationInboxScreen> createState() =>
      _InvitationInboxScreenState();
}

class _InvitationInboxScreenState extends State<InvitationInboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DelegationProvider>().fetchPendingInvitations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: l.opInviteTitle,
        eyebrow: l.opInviteEyebrow,
      ),
      body: const _InvitationList(),
    );
  }
}

class _InvitationList extends StatelessWidget {
  const _InvitationList();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prov = context.watch<DelegationProvider>();
    final invitations = prov.pendingInvitations;

    if (prov.state == DelegationLoadState.loading) {
      return ListView.separated(
        padding: const EdgeInsets.all(HD.s16),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: HD.s12),
        itemBuilder: (_, __) => const DsSkeleton(height: 80),
      );
    }

    if (invitations.isEmpty) {
      return DsEmptyState(
        icon: Icons.mail_outlined,
        title: l.opInviteEmptyTitle,
        subtitle: l.opInviteEmptySubtitle,
      );
    }

    return RefreshIndicator(
      color: HD.accent,
      onRefresh: () =>
          context.read<DelegationProvider>().fetchPendingInvitations(),
      child: ListView.separated(
        padding: const EdgeInsets.all(HD.s16),
        itemCount: invitations.length,
        separatorBuilder: (_, __) => const SizedBox(height: HD.s12),
        itemBuilder: (context, index) {
          return _InvitationCard(invitation: invitations[index]);
        },
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({required this.invitation});

  final DelegationInvitationModel invitation;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.ownerName ?? l.opInviteOwnerFallback,
                      style: HD.bodyBold(color: HD.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _roleLabel(l, invitation.rolePreset),
                      style: HD.caption(color: HD.inkMuted),
                    ),
                    Text(
                      l.opInviteSentDate(_formatDate(invitation.createdAt)),
                      style: HD.caption(color: HD.inkMuted),
                    ),
                  ],
                ),
              ),
              DsStatusPill(
                label: l.opInviteStatusPending,
                tone: DsStatusTone.warning,
              ),
            ],
          ),
          const SizedBox(height: HD.s16),
          Row(
            children: [
              Expanded(
                child: DsButton(
                  label: l.opInviteReject,
                  variant: DsButtonVariant.secondary,
                  onPressed: () => _reject(context),
                ),
              ),
              const SizedBox(width: HD.s12),
              Expanded(
                child: DsButton(
                  label: l.opInviteAccept,
                  onPressed: () => _accept(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _accept(BuildContext context) async {
    final prov = context.read<DelegationProvider>();
    final delegation = await prov.acceptInvitation(invitation.id);
    if (!context.mounted) return;
    final l = AppLocalizations.of(context);
    if (delegation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.opInviteAcceptSuccess)),
      );
      context.go('/operator');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(prov.error ?? l.opInviteAcceptError),
          backgroundColor: HD.negative,
        ),
      );
    }
  }

  Future<void> _reject(BuildContext context) async {
    final prov = context.read<DelegationProvider>();
    final ok = await prov.rejectInvitation(invitation.id);
    if (!context.mounted) return;
    final l = AppLocalizations.of(context);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.opInviteRejectSuccess)),
      );
    }
  }

  String _roleLabel(AppLocalizations l, String? preset) {
    switch (preset) {
      case 'operator_full':
        return l.opInviteRoleFull;
      case 'accountant':
        return l.opInviteRoleAccountant;
      case 'viewer':
        return l.opInviteRoleViewer;
      default:
        return l.opInviteRoleOther(preset ?? l.opInviteRoleUnknown);
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
