/// Acting-as overlay app bar — warm orange tint + eyebrow + Thoát button.
///
/// Shown whenever ActorContextProvider.isActingAs == true.
/// Color: HD.warningTint background, HD.warning text (TL-3 decision).
/// See phase-07 §Architecture: "Acting-as overlay (warm orange theme variant)".
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/providers/actor_context_provider.dart';

/// Banner widget shown at top of screen when user is acting on behalf of an
/// owner. Wraps existing content; does NOT replace DsAppBar on child screens.
///
/// Wire this into the OperatorWorkspaceShell scaffold, not the GuestShell.
class ActingAsBanner extends StatelessWidget {
  const ActingAsBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final actor = context.watch<ActorContextProvider>();
    if (!actor.isActingAs) return child;

    return Column(
      children: [
        _ActingAsBannerStrip(ownerName: actor.actingAsOwnerName),
        Expanded(child: child),
      ],
    );
  }
}

/// The warm-orange strip itself. Stateless — all state in ActorContextProvider.
class _ActingAsBannerStrip extends StatelessWidget {
  const _ActingAsBannerStrip({required this.ownerName});

  final String ownerName;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HD.warningTint,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HD.s16,
            vertical: HD.s8,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: HD.warning, width: 1.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                color: HD.warning,
                size: 18,
              ),
              const SizedBox(width: HD.s8),
              Expanded(
                child: Text(
                  'Bạn đang thao tác thay cho $ownerName',
                  style: HD.body(color: HD.warning, size: 13).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: HD.s8),
              _ExitButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExitButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<ActorContextProvider>().clear();
        // Navigator back to operator portfolio — caller handles routing.
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HD.s12,
          vertical: HD.s4,
        ),
        decoration: BoxDecoration(
          color: HD.warning,
          borderRadius: BorderRadius.circular(HD.r4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.exit_to_app, size: 14, color: HD.paper),
            const SizedBox(width: 4),
            Text(
              'Thoát',
              style: HD.caption(color: HD.paper).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
