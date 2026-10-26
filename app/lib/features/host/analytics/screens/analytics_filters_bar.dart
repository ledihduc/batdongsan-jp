import 'package:flutter/material.dart';
import 'package:house_booking/features/host/analytics/services/period_helper.dart';
import 'package:house_booking/features/host/analytics/widgets/offline_badge.dart';
import 'package:house_booking/features/host/analytics/widgets/stale_cache_badge.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

// ---------------------------------------------------------------------------
// Period toggle action button — month / year chips.
// ---------------------------------------------------------------------------

class AnalyticsPeriodToggle extends StatelessWidget {
  const AnalyticsPeriodToggle({
    super.key,
    required this.current,
    required this.onToggle,
  });

  final PeriodType current;
  final void Function(PeriodType) onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToggleChip(
          label: 'Tháng',
          isActive: current == PeriodType.month,
          onTap: () => onToggle(PeriodType.month),
        ),
        const SizedBox(width: HD.s4),
        _ToggleChip(
          label: 'Năm',
          isActive: current == PeriodType.year,
          onTap: () => onToggle(PeriodType.year),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HD.s8,
          vertical: HD.s4,
        ),
        decoration: BoxDecoration(
          color: isActive ? HD.ink : Colors.transparent,
          border: Border.all(color: isActive ? HD.ink : HD.hairline),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          style: HD.caption(
            color: isActive ? HD.paperRaised : HD.inkSoft,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status badge row — offline pill + stale-cache pill.
// Rendered above KPI grid (data state) and above period header (empty state).
// ---------------------------------------------------------------------------

class AnalyticsStatusBadgeRow extends StatelessWidget {
  const AnalyticsStatusBadgeRow({
    super.key,
    required this.offline,
    required this.lastFetchAt,
  });

  final bool offline;
  final DateTime? lastFetchAt;

  /// True when cached data is 5+ minutes old per AC-17.
  bool get _isStale {
    if (lastFetchAt == null) return false;
    return DateTime.now().difference(lastFetchAt!).inMinutes >= 5;
  }

  @override
  Widget build(BuildContext context) {
    final showOffline = offline;
    final showStale = !offline && _isStale;

    if (!showOffline && !showStale) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: HD.s4),
      child: Row(
        key: const Key('status_badge_row'),
        children: [
          if (showOffline)
            OfflineBadge(lastFetchAt: lastFetchAt),
          if (showStale)
            const StaleCacheBadge(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Period header bar — used in empty state (no swipe area needed).
// Mirrors PeriodSwiper's header row without the GestureDetector child.
// ---------------------------------------------------------------------------

class AnalyticsPeriodHeaderBar extends StatelessWidget {
  const AnalyticsPeriodHeaderBar({
    super.key,
    required this.period,
    required this.anchorDate,
    required this.currentPeriodStart,
    required this.onShift,
  });

  final PeriodType period;
  final DateTime anchorDate;
  final DateTime currentPeriodStart;
  final void Function(int) onShift;

  bool get _isAtCurrentPeriod =>
      PeriodHelper.formatPeriodKey(period, anchorDate) ==
      PeriodHelper.formatPeriodKey(period, currentPeriodStart);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HD.s8, vertical: HD.s4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Kỳ trước',
            onPressed: () => onShift(-1),
            icon: const Icon(Icons.chevron_left),
            color: HD.ink,
            iconSize: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          Expanded(
            child: Center(
              child: Text(
                PeriodHelper.displayLabel(period, anchorDate),
                style: HD.bodyBold(size: 15),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Kỳ sau',
            onPressed: _isAtCurrentPeriod ? null : () => onShift(1),
            icon: Icon(
              Icons.chevron_right,
              color: _isAtCurrentPeriod ? HD.inkMuted : HD.ink,
            ),
            iconSize: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }
}
