/// JP 内見ステータス (viewing status) screen.
///
/// Shows the full lifecycle of a single viewing request: proposed slots,
/// current status badge, confirmed slot (when approved), and action buttons
/// (cancel / reschedule).
///
/// Route: /viewings/:id (GoRoute, URL-worthy for push notifications deep-link).
/// Provider: none — loads viewing via [IJpViewingRepository].
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/jp_viewing.dart';
import 'package:house_booking/data/repositories/jp/mock_jp_viewing_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_viewing_repository.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class ViewingStatusScreen extends StatefulWidget {
  /// Route: /viewings/:id
  const ViewingStatusScreen({
    super.key,
    required this.viewingId,
    IJpViewingRepository? repository,
  }) : _repository = repository;

  final int viewingId;
  final IJpViewingRepository? _repository;

  @override
  State<ViewingStatusScreen> createState() => _ViewingStatusScreenState();
}

class _ViewingStatusScreenState extends State<ViewingStatusScreen> {
  late final IJpViewingRepository _repo;
  JpViewing? _viewing;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repo = widget._repository ?? MockJpViewingRepository();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await _repo.getById(widget.viewingId);
      if (mounted) setState(() {
        _viewing = v;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = 'データを読み込めませんでした。';
        _loading = false;
      });
    }
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      final updated = await _repo.cancel(widget.viewingId);
      if (mounted) setState(() {
        _viewing = updated;
        _busy = false;
      });
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        eyebrow: '内見',
        title: l.jp_viewing_request,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : _error != null
              ? DsErrorState(message: _error!, onRetry: _load)
              : _buildBody(l),
    );
  }

  Widget _buildBody(AppLocalizations l) {
    final v = _viewing!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status badge
        _StatusBadge(status: v.status, l: l),
        const SizedBox(height: 16),

        // Listing info
        if (v.listingTitle != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HD.paperRaised,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.home_outlined, color: HD.inkMuted, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(v.listingTitle!,
                      style: const TextStyle(
                          color: HD.inkSoft, fontSize: 14)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Confirmed slot highlight
        if (v.confirmedSlot != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '確定日時',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatSlot(v.confirmedSlot!),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Proposed slots
        Text(
          '希望日時',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: HD.inkMuted,
          ),
        ),
        const SizedBox(height: 8),
        ...v.proposedSlots.asMap().entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HD.accentTint,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${e.key + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: HD.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatSlot(e.value),
                  style: const TextStyle(color: HD.inkSoft, fontSize: 14),
                ),
              ],
            ),
          );
        }),

        // Agent info
        if (v.agentName != null) ...[
          const SizedBox(height: 16),
          const Divider(color: HD.hairline),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: HD.inkMuted),
              const SizedBox(width: 6),
              Text(
                '担当: ${v.agentName}',
                style: const TextStyle(color: HD.inkSoft, fontSize: 13),
              ),
            ],
          ),
        ],

        const SizedBox(height: 24),

        // Action buttons — only when cancellable
        if (v.status == JpViewingStatus.pending ||
            v.status == JpViewingStatus.confirmed) ...[
          DsButton(
            label: _busy ? 'キャンセル中...' : l.jp_cancel_viewing,
            onPressed: _busy ? null : _cancel,
            variant: DsButtonVariant.secondary,
          ),
        ],
      ],
    );
  }

  static String _formatSlot(JpViewingSlot slot) {
    final dt = DateTime.tryParse(slot.startAt);
    if (dt == null) return slot.startAt;
    return '${dt.year}年${dt.month}月${dt.day}日 '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.l});

  final JpViewingStatus status;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final (label, color, bgColor) = _forStatus(status, l);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  static (String, Color, Color) _forStatus(
      JpViewingStatus s, AppLocalizations l) {
    switch (s) {
      case JpViewingStatus.confirmed:
        return (l.jp_viewing_status_confirmed, Colors.green,
            const Color(0xFFE8F5E9));
      case JpViewingStatus.rejected:
        return (l.jp_viewing_status_rejected, HD.accent, HD.accentTint);
      case JpViewingStatus.cancelled:
        return (l.jp_viewing_status_cancelled, HD.inkMuted, HD.paperSunken);
      case JpViewingStatus.completed:
        return (
          l.jp_viewing_status_completed,
          Colors.blue,
          const Color(0xFFE3F2FD)
        );
      default:
        return (l.jp_viewing_status_pending, HD.warning, HD.warningTint);
    }
  }
}
