/// Operator workspace shell — wraps existing host screens with acting-as overlay.
///
/// When operator taps an owner card, this shell is pushed. It:
/// 1. Sets ActorContextProvider context on entry (already set by portfolio tap)
/// 2. Displays ActingAsBanner at top (warm-orange overlay, "Thoát" button)
/// 3. Handles 401 DELEGATION_REVOKED → clears context + navigates back (AC-16b)
/// 4. On hardware back / "Thoát" → clears context
///
/// Covers AC-13, AC-14, AC-15b, AC-16b.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/acting_as_app_bar.dart';
import 'package:house_booking/features/host/host_home_screen.dart';
import 'package:house_booking/providers/actor_context_provider.dart';

/// Shell that wraps the host workspace screens under an acting-as context.
/// Rendered at /operator/owner/:ownerId route.
class OperatorWorkspaceShell extends StatefulWidget {
  const OperatorWorkspaceShell({
    super.key,
    required this.ownerId,
  });

  final String ownerId;

  @override
  State<OperatorWorkspaceShell> createState() =>
      _OperatorWorkspaceShellState();
}

class _OperatorWorkspaceShellState extends State<OperatorWorkspaceShell> {
  @override
  void initState() {
    super.initState();
    // Verify actor context is set for this owner.
    // If cold-start deep-link arrives without context, redirect back to portfolio.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final actor = context.read<ActorContextProvider>();
      if (!actor.isActingAs) {
        context.go('/operator');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final actor = context.watch<ActorContextProvider>();

    // If context was cleared (e.g. DELEGATION_REVOKED handled upstream),
    // show minimal screen until navigation fires.
    if (!actor.isActingAs) {
      return const Scaffold(
        backgroundColor: HD.paper,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          context.read<ActorContextProvider>().clear();
        }
      },
      child: Scaffold(
        backgroundColor: HD.paper,
        body: ActingAsBanner(
          child: Column(
            children: [
              // Workspace app bar with delegation info
              _WorkspaceAppBar(
                ownerName: actor.actingAsOwnerName,
                ownerId: widget.ownerId,
              ),
              const Expanded(
                // Operator sees the same host screens but all API calls
                // carry X-Acting-As-Delegation-Id header automatically.
                child: HostHomeScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceAppBar extends StatelessWidget {
  const _WorkspaceAppBar({
    required this.ownerName,
    required this.ownerId,
  });

  final String ownerName;
  final String ownerId;

  @override
  Widget build(BuildContext context) {
    return DsAppBar(
      title: ownerName,
      eyebrow: 'ĐẠI DIỆN CHO',
      background: HD.warningTint,
      foreground: HD.warning,
      showBack: true,
      onBack: () {
        context.read<ActorContextProvider>().clear();
        context.go('/operator');
      },
      actions: [
        DsIconButton(
          icon: Icons.history_outlined,
          onPressed: () =>
              context.push('/operator/owner/$ownerId/audit'),
          tooltip: 'Nhật ký hoạt động',
          color: HD.warning,
        ),
      ],
    );
  }
}
