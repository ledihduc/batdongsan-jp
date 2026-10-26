/// Activity feed screen — timeline of operator actions on an owner's property.
///
/// Covers AC-38, AC-39, AC-40, AC-41. Filters: today/week/month + entity type.
/// Dual-identity display: each row shows operator avatar + action + timestamp.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/repositories/api_delegation_repository.dart';
import 'package:house_booking/features/audit/audit_timeline_widget.dart';
import 'package:house_booking/providers/actor_context_provider.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({
    super.key,
    required this.delegationId,
  });

  final String delegationId;

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  final _repo = ApiDelegationRepository();

  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;
  String? _error;
  String _filterPeriod = 'week';
  String? _filterEntityType;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final entries = await _repo.fetchAuditLog(
        widget.delegationId,
        filterPeriod: _filterPeriod,
        entityType: _filterEntityType,
      );
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final actor = context.watch<ActorContextProvider>();
    final ownerName =
        actor.isActingAs ? actor.actingAsOwnerName : l.auditOwnerFallback;

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: l.auditTitle,
        eyebrow: l.auditRepresentative(ownerName).toUpperCase(),
        compact: true,
      ),
      body: Column(
        children: [
          _FilterBar(
            selectedPeriod: _filterPeriod,
            onPeriodChanged: (p) {
              setState(() => _filterPeriod = p);
              _load();
            },
          ),
          const HDHairline(),
          Expanded(child: _Body(
            isLoading: _isLoading,
            error: _error,
            entries: _entries,
            onRetry: _load,
          )),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;

  static const _periods = [
    ('today', 'Hôm nay'),
    ('week', 'Tuần này'),
    ('month', 'Tháng này'),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: HD.s16,
        vertical: HD.s8,
      ),
      child: Row(
        children: _periods.map((p) {
          final label = switch (p.$1) {
            'today' => l.auditPeriodToday,
            'week' => l.auditPeriodWeek,
            'month' => l.auditPeriodMonth,
            _ => p.$2,
          };
          return Padding(
            padding: const EdgeInsets.only(right: HD.s8),
            child: DsFilterChip(
              label: label,
              selected: selectedPeriod == p.$1,
              onTap: () => onPeriodChanged(p.$1),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.isLoading,
    required this.error,
    required this.entries,
    required this.onRetry,
  });

  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> entries;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.all(HD.s16),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: HD.s12),
        itemBuilder: (_, __) => const DsSkeleton(height: 64),
      );
    }

    if (error != null) {
      return DsEmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.auditLoadError,
        subtitle: error,
        actionLabel: l.auditRetry,
        onAction: onRetry,
      );
    }

    if (entries.isEmpty) {
      return DsEmptyState(
        icon: Icons.history_outlined,
        title: l.auditEmptyTitle,
        subtitle: l.auditEmptySubtitle,
      );
    }

    return AuditTimelineWidget(entries: entries);
  }
}
