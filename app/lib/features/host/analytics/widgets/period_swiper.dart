import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/telemetry/telemetry_service.dart';
import 'package:house_booking/features/host/analytics/services/period_helper.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Period navigation bar — arrow buttons + swipe gesture.
///
/// Wraps [child] with a [GestureDetector] for horizontal swipe.
/// Swipe threshold: velocity > 300 OR horizontal displacement > 80px.
/// Right arrow disabled when [anchorDate] is at the current period.
/// Triggers [HapticFeedback.lightImpact] on every valid period shift.
class PeriodSwiper extends StatefulWidget {
  const PeriodSwiper({
    super.key,
    required this.period,
    required this.anchorDate,
    required this.currentPeriodStart,
    required this.onShift,
    required this.child,
  });

  /// Current period type.
  final PeriodType period;

  /// Anchor date displayed in the label.
  final DateTime anchorDate;

  /// Start of the CURRENT real-world period (used to disable future nav).
  final DateTime currentPeriodStart;

  /// Called with -1 (back in time / left arrow) or +1 (forward / right arrow).
  ///
  /// Left arrow / swipe left = go back in time (delta = -1).
  /// Right arrow / swipe right = go forward in time (delta = +1).
  final void Function(int delta) onShift;

  /// Content wrapped by the gesture detector (typically the KPI grid).
  final Widget child;

  @override
  State<PeriodSwiper> createState() => _PeriodSwiperState();
}

class _PeriodSwiperState extends State<PeriodSwiper> {
  double? _dragStartX;

  bool get _isAtCurrentPeriod =>
      PeriodHelper.formatPeriodKey(widget.period, widget.anchorDate) ==
      PeriodHelper.formatPeriodKey(widget.period, widget.currentPeriodStart);

  void _handleDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
  }

  void _shift(int delta) {
    HapticFeedback.lightImpact();
    // Track swipe gesture (not arrow-button tap — those are handled separately).
    Provider.of<TelemetryService>(context, listen: false).track(
      'period_swiped',
      props: {'direction': delta > 0 ? 'next' : 'prev'},
    );
    widget.onShift(delta);
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final startX = _dragStartX ?? 0;
    final displacement = details.globalPosition.dx - startX;
    _dragStartX = null;

    // Velocity-based (fast swipe)
    if (velocity.abs() > 300) {
      if (velocity < 0) {
        // Swipe left = earlier period
        _shift(-1);
      } else if (!_isAtCurrentPeriod) {
        // Swipe right = later period
        _shift(1);
      }
      return;
    }

    // Displacement-based fallback (slow deliberate drag > 80px)
    if (displacement.abs() > 80) {
      if (displacement < 0) {
        _shift(-1);
      } else if (!_isAtCurrentPeriod) {
        _shift(1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PeriodHeader(
          label: PeriodHelper.displayLabel(widget.period, widget.anchorDate),
          canGoForward: !_isAtCurrentPeriod,
          onBack: () => _shift(-1),
          onForward: _isAtCurrentPeriod ? null : () => _shift(1),
        ),
        Expanded(
          child: GestureDetector(
            key: const Key('period_swipe_area'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _handleDragStart,
            onHorizontalDragEnd: _handleDragEnd,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({
    required this.label,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
  });

  final String label;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback? onForward;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HD.s8,
        vertical: HD.s4,
      ),
      child: Row(
        children: [
          IconButton(
            key: const Key('period_back_btn'),
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left),
            color: HD.ink,
            iconSize: 22,
            tooltip: 'Kỳ trước',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: HD.bodyBold(size: 15),
              ),
            ),
          ),
          IconButton(
            key: const Key('period_forward_btn'),
            onPressed: onForward,
            icon: Icon(
              Icons.chevron_right,
              color: canGoForward ? HD.ink : HD.inkMuted,
            ),
            iconSize: 22,
            tooltip: canGoForward ? 'Kỳ sau' : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }
}
