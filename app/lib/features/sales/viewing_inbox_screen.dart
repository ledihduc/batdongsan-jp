/// JP sales agent viewing inbox screen.
///
/// Lists all incoming 内見リクエスト for the agent's assigned listings.
/// Agent can confirm one slot or reject the request.
///
/// Route: /sales/viewings (GoRoute).
/// Provider: none — uses [IJpViewingRepository].
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/jp_viewing.dart';
import 'package:house_booking/data/repositories/jp/mock_jp_viewing_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_viewing_repository.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class ViewingInboxScreen extends StatefulWidget {
  /// Route: /sales/viewings
  const ViewingInboxScreen({
    super.key,
    IJpViewingRepository? repository,
  }) : _repository = repository;

  final IJpViewingRepository? _repository;

  @override
  State<ViewingInboxScreen> createState() => _ViewingInboxScreenState();
}

class _ViewingInboxScreenState extends State<ViewingInboxScreen> {
  late final IJpViewingRepository _repo;
  List<JpViewing> _viewings = [];
  bool _loading = true;

  static const int _agentId = 501;

  @override
  void initState() {
    super.initState();
    _repo = widget._repository ?? MockJpViewingRepository();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _repo.listForAgent(_agentId);
      if (mounted) setState(() {
        _viewings = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(eyebrow: '仲介', title: l.jp_viewing_inbox_title),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : _viewings.isEmpty
              ? DsEmptyState(
                  icon: Icons.calendar_month_outlined,
                  title: '内見リクエストはありません',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _viewings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) => _ViewingCard(
                      viewing: _viewings[idx],
                      repository: _repo,
                      onRefresh: _load,
                    ),
                  ),
                ),
    );
  }
}

class _ViewingCard extends StatefulWidget {
  const _ViewingCard({
    required this.viewing,
    required this.repository,
    required this.onRefresh,
  });

  final JpViewing viewing;
  final IJpViewingRepository repository;
  final VoidCallback onRefresh;

  @override
  State<_ViewingCard> createState() => _ViewingCardState();
}

class _ViewingCardState extends State<_ViewingCard> {
  bool _busy = false;

  Future<void> _confirmSlot(JpViewingSlot slot) async {
    setState(() => _busy = true);
    try {
      await widget.repository.confirmSlot(
        viewingId: widget.viewing.id,
        slot: slot,
      );
      widget.onRefresh();
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    try {
      await widget.repository.cancel(widget.viewing.id);
      widget.onRefresh();
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final v = widget.viewing;
    final isPending = v.status == JpViewingStatus.pending;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending ? HD.accent.withOpacity(0.3) : HD.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  v.listingTitle ?? '物件ID: ${v.listingId}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HD.ink,
                  ),
                ),
              ),
              _StatusPill(status: v.status, l: l),
            ],
          ),
          if (v.tenantName != null) ...[
            const SizedBox(height: 4),
            Text(
              '申込者: ${v.tenantName}',
              style: const TextStyle(fontSize: 12, color: HD.inkMuted),
            ),
          ],
          const SizedBox(height: 10),
          // Slot list — tap to confirm
          if (isPending) ...[
            Text(
              l.jp_select_slots,
              style: const TextStyle(
                fontSize: 11,
                color: HD.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...v.proposedSlots.asMap().entries.map((e) {
              final slot = e.value;
              final dt = DateTime.tryParse(slot.startAt);
              final label = dt == null
                  ? slot.startAt
                  : '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
                      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: _busy ? null : () => _confirmSlot(slot),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: HD.accentTint,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: HD.accent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule,
                            size: 14, color: HD.accent),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: const TextStyle(
                              fontSize: 13, color: HD.accent),
                        ),
                        const Spacer(),
                        Text(
                          l.jp_confirm_slot,
                          style: const TextStyle(
                            fontSize: 11,
                            color: HD.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _reject,
                child: Text(
                  l.jp_reject_viewing,
                  style: const TextStyle(
                      color: HD.inkMuted, fontSize: 12),
                ),
              ),
            ),
          ],
          // Confirmed slot display
          if (v.confirmedSlot != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  l.jp_slot_confirmed,
                  style: const TextStyle(
                      color: Colors.green, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.l});

  final JpViewingStatus status;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _forStatus(status, l);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  static (String, Color) _forStatus(
      JpViewingStatus s, AppLocalizations l) {
    switch (s) {
      case JpViewingStatus.confirmed:
        return (l.jp_viewing_status_confirmed, Colors.green);
      case JpViewingStatus.rejected:
        return (l.jp_viewing_status_rejected, HD.accent);
      case JpViewingStatus.cancelled:
        return (l.jp_viewing_status_cancelled, HD.inkMuted);
      case JpViewingStatus.completed:
        return (l.jp_viewing_status_completed, Colors.blue);
      default:
        return (l.jp_viewing_status_pending, HD.warning);
    }
  }
}
