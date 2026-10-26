/// Operator Portfolio Screen — lists all owners who have delegated to the current user.
///
/// Covers AC-11, AC-12, AC-14. NFR-09: paginated (20/page), lazy thumbnails.
/// Tap a card → enters acting-as context + navigates to operator workspace.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/operator_delegation_model.dart';
import 'package:house_booking/providers/actor_context_provider.dart';
import 'package:house_booking/providers/delegation_provider.dart';
import 'package:house_booking/features/operator/portfolio/owner_card_widget.dart';

class OperatorPortfolioScreen extends StatefulWidget {
  const OperatorPortfolioScreen({super.key});

  @override
  State<OperatorPortfolioScreen> createState() =>
      _OperatorPortfolioScreenState();
}

class _OperatorPortfolioScreenState extends State<OperatorPortfolioScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
          .read<DelegationProvider>()
          .fetchMyDelegationsAsOperator();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: 'Danh mục của tôi',
        eyebrow: 'OPERATOR · PORTFOLIO',
        showBack: false,
        actions: [
          DsIconButton(
            icon: Icons.mail_outline,
            onPressed: () => context.push('/operator/invitations'),
            tooltip: 'Lời mời',
          ),
        ],
      ),
      body: const _PortfolioBody(),
    );
  }
}

class _PortfolioBody extends StatelessWidget {
  const _PortfolioBody();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DelegationProvider>();

    if (prov.state == DelegationLoadState.loading) {
      return ListView.separated(
        padding: const EdgeInsets.all(HD.s16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: HD.s12),
        itemBuilder: (_, __) => const DsSkeleton(height: 100),
      );
    }

    if (prov.state == DelegationLoadState.error) {
      return DsEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Không tải được dữ liệu',
        subtitle: prov.error ?? 'Vui lòng thử lại',
        actionLabel: 'Thử lại',
        onAction: () => context
            .read<DelegationProvider>()
            .fetchMyDelegationsAsOperator(),
      );
    }

    final delegations = prov.myDelegationsAsOperator
        .where((d) => d.isActive || d.isPaused)
        .toList();

    if (delegations.isEmpty) {
      return const DsEmptyState(
        icon: Icons.handshake_outlined,
        title: 'Chưa có bất động sản nào',
        subtitle:
            'Khi chủ nhà ủy thác cho bạn, tài sản sẽ xuất hiện ở đây.',
      );
    }

    return RefreshIndicator(
      color: HD.accent,
      onRefresh: () => context
          .read<DelegationProvider>()
          .fetchMyDelegationsAsOperator(),
      child: ListView.separated(
        padding: const EdgeInsets.all(HD.s16),
        itemCount: delegations.length,
        separatorBuilder: (_, __) => const SizedBox(height: HD.s12),
        itemBuilder: (context, index) {
          final delegation = delegations[index];
          return OwnerCardWidget(
            delegation: delegation,
            onTap: () => _enterContext(context, delegation),
          );
        },
      ),
    );
  }

  void _enterContext(
      BuildContext context, OperatorDelegationModel delegation) {
    context.read<ActorContextProvider>().enterContext(delegation);
    context.push('/operator/owner/${delegation.ownerUserId}');
  }
}
