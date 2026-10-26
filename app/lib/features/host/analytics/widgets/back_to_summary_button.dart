import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/features/host/analytics/providers/drill_provider.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Outlined button that always takes the user back to the analytics summary.
///
/// Resets [DrillProvider] breadcrumb + filter and navigates to /host/analytics.
/// Place in AppBar actions or as a persistent footer row.
class BackToSummaryButton extends StatelessWidget {
  const BackToSummaryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Về Tổng quan',
      child: SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: () {
            context.read<DrillProvider>().reset();
            context.go('/host/analytics');
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: HD.ink,
            side: const BorderSide(color: HD.hairline),
            padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: HD.s8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          icon: const Icon(Icons.home_rounded, size: 18),
          label: Text(
            'Tổng quan',
            style: HD.caption(color: HD.ink).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
