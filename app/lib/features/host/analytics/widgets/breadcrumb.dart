import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/features/host/analytics/providers/drill_provider.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Sticky breadcrumb row for drill-down navigation.
///
/// Shows the full path from summary to the current level.
/// Each segment is tappable → pops back to that level.
/// Long labels are truncated at 20 chars with ellipsis.
/// Horizontal scroll enabled for overflow.
class Breadcrumb extends StatelessWidget {
  const Breadcrumb({super.key});

  static const int _kMaxLabelLen = 20;

  /// Truncate [text] to [_kMaxLabelLen] chars + ellipsis if longer.
  static String _truncate(String text) {
    if (text.length <= _kMaxLabelLen) return text;
    return '${text.substring(0, _kMaxLabelLen)}…';
  }

  /// Route path for a given breadcrumb level + params.
  static String _routeFor(BreadcrumbItem item) {
    switch (item.level) {
      case 0:
        return '/host/analytics';
      case 1:
        return '/host/analytics/drill/rooms';
      case 2:
        final roomId = item.params['roomId'];
        return '/host/analytics/drill/room/${roomId ?? 0}/contracts';
      case 3:
        final contractId = item.params['contractId'];
        return '/host/analytics/drill/contract/${contractId ?? 0}/tenants';
      case 4:
        final tenantId = item.params['tenantId'];
        final contractId = item.params['contractId'];
        return '/host/analytics/drill/tenant/${tenantId ?? 0}/invoices'
            '?contract_id=${contractId ?? 0}';
      default:
        return '/host/analytics';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DrillProvider>(
      builder: (context, provider, _) {
        final items = provider.breadcrumb;

        return Semantics(
          label: 'Breadcrumb: ${items.map((i) => i.title).join(', ')}',
          child: Container(
            color: HD.paperRaised,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: HD.s8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _buildSegments(context, items, provider),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildSegments(
    BuildContext context,
    List<BreadcrumbItem> items,
    DrillProvider provider,
  ) {
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isLast = i == items.length - 1;

      widgets.add(
        TextButton(
          onPressed: isLast
              ? null
              : () {
                  provider.popToLevel(item.level);
                  context.go(_routeFor(item));
                },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: HD.s4, vertical: 0),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          child: Text(
            _truncate(item.title),
            style: isLast
                ? HD.caption(color: HD.ink).copyWith(fontWeight: FontWeight.w600)
                : HD.caption(color: HD.inkMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );

      if (!isLast) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '/',
              style: HD.caption(color: HD.hairline),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}
