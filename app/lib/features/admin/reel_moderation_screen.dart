import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/reel_api.dart';
import 'package:house_booking/l10n/app_localizations.dart';

String _abs(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

/// Kiểm duyệt REEL (admin) — mô hình duyệt-TRƯỚC: reel user đăng nằm ở
/// "Chờ duyệt" và chỉ công khai sau khi admin duyệt.
///
/// 3 tab: Chờ duyệt · Bị ẩn (do báo cáo) · Đã đăng.
class ReelModerationScreen extends StatefulWidget {
  const ReelModerationScreen({super.key, this.api = const ReelApi()});

  /// Cho phép bơm ReelApi giả trong test. Mặc định là bản thật nên mã
  /// sản phẩm không đổi hành vi — chỉ mở một khe để test không cần mạng.
  final ReelApi api;

  @override
  State<ReelModerationScreen> createState() => _ReelModerationScreenState();
}

class _ReelModerationScreenState extends State<ReelModerationScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = <(String, String)>[
    ('pending', 'Chờ duyệt'),
    ('hidden', 'Bị ẩn'),
    ('published', 'Đã đăng'),
  ];

  late final TabController _tc = TabController(length: _tabs.length, vsync: this)
    ..addListener(() {
      if (!_tc.indexIsChanging) _load();
    });

  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await widget.api.moderationQueue(status: _tabs[_tc.index].$1);
      if (mounted) setState(() => _rows = r);
      // Số liệu vận hành — lỗi thì bỏ qua, không chặn việc kiểm duyệt.
      try {
        final st = await widget.api.analytics();
        if (mounted) setState(() => _stats = st);
      } catch (_) {}
    } catch (_) {
      if (mounted) setState(() => _rows = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _moderate(int id, String action, {String reason = ''}) async {
    final l = AppLocalizations.of(context);
    try {
      await widget.api.moderate(id, action, reason: reason);
      if (mounted) {
        AppFeedback.success(
            context,
            action == 'approve'
                ? l.adminReelApproved
                : action == 'reject'
                    ? l.adminReelRejected
                    : l.adminReelHidden);
      }
      _load();
    } catch (e) {
      if (mounted) AppFeedback.error(context, l.adminReelActionFailed('$e'));
    }
  }

  Future<void> _rejectWithReason(int id) async {
    final l = AppLocalizations.of(context);
    final ctl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.adminReelRejectTitle),
        content: TextField(
          controller: ctl,
          maxLines: 2,
          decoration: InputDecoration(
              labelText: l.adminReelReasonLabel,
              hintText: l.adminReelReasonHint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HD.negative),
            onPressed: () {
              if (ctl.text.trim().isEmpty) return;
              Navigator.pop(ctx, ctl.text.trim());
            },
            child: Text(l.adminReelReject),
          ),
        ],
      ),
    );
    if (reason != null) _moderate(id, 'reject', reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String tabLabel(String code) => switch (code) {
          'pending' => l.adminReelTabPending,
          'hidden' => l.adminReelTabHidden,
          _ => l.adminReelTabPublished,
        };
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        eyebrow: l.adminReelEyebrow,
        title: l.adminReelTitle,
        bottom: TabBar(
          controller: _tc,
          labelColor: HD.ink,
          unselectedLabelColor: HD.inkMuted,
          indicatorColor: HD.accent,
          tabs: [for (final (code, _) in _tabs) Tab(text: tabLabel(code))],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: HD.accent,
        child: Column(children: [
          if (_stats != null) _statsBar(),
          Expanded(
            child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _rows.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 80),
                    const Icon(Icons.inbox_outlined,
                        size: 48, color: HD.inkMuted),
                    const SizedBox(height: 12),
                    Center(
                        child: Text(l.adminReelEmpty,
                            style: const TextStyle(color: HD.inkMuted))),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _rows.length,
                    itemBuilder: (context, i) => _card(_rows[i]),
                  ),
          ),
        ]),
      ),
    );
  }

  /// Dải số liệu vận hành — admin thấy ngay tính năng có khoẻ và tốn bao nhiêu.
  Widget _statsBar() {
    final l = AppLocalizations.of(context);
    final s = _stats!;
    final fail = ((s['failure_rate'] as num?)?.toDouble() ?? 0) * 100;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      color: HD.paperRaised,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.adminReelStatsTitle,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: HD.inkSoft)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _stat('${s['total'] ?? 0}', l.adminReelStatReels),
          _stat('${s['pending_moderation'] ?? 0}', l.adminReelStatPending,
              warn: ((s['pending_moderation'] as num?)?.toInt() ?? 0) > 0),
          _stat('${s['total_views'] ?? 0}', l.adminReelStatViews),
          _stat('${s['total_likes'] ?? 0}', l.adminReelStatLikes),
          _stat('${s['total_comments'] ?? 0}', l.adminReelStatComments),
          _stat('${s['storage_mb'] ?? 0} MB', l.adminReelStatStorage),
          // Tỉ lệ hỏng cao = pipeline có vấn đề, cần xem log worker.
          _stat('${fail.toStringAsFixed(1)}%', l.adminReelStatFailures,
              warn: fail > 10),
        ]),
      ]),
    );
  }

  Widget _stat(String value, String label, {bool warn = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: warn ? HD.accentTint : HD.paper,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: warn ? HD.accent : HD.hairline),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: warn ? HD.accent : HD.ink)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 11, color: HD.inkMuted)),
        ]),
      );

  Widget _card(Map<String, dynamic> r) {
    final l = AppLocalizations.of(context);
    final id = (r['id'] as num).toInt();
    final status = (r['status'] as String?) ?? '';
    final thumb = r['thumbnail_url'] as String?;
    final reports = (r['report_count'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HD.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 84,
            height: 112,
            child: (thumb != null && thumb.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: _abs(thumb),
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) =>
                        Container(color: HD.paperSunken))
                : Container(
                    color: HD.paperSunken,
                    child: const Icon(Icons.videocam_outlined,
                        color: HD.inkMuted)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r['author_name'] ?? ''} · #$id',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: HD.ink,
                          fontSize: 13)),
                  const SizedBox(height: 4),
                  Text((r['caption'] as String?)?.isNotEmpty == true
                          ? r['caption'] as String
                          : l.adminReelNoCaption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: HD.inkSoft, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _chip(r['category'] as String? ?? 'all', HD.accent),
                    if (reports > 0)
                      _chip(l.adminReelReportCount(reports), HD.negative),
                    if ((r['reject_reason'] as String?)?.isNotEmpty == true)
                      _chip(
                          l.adminReelRejectReason(r['reject_reason'] as String),
                          HD.warning),
                  ]),
                ],
              ),
            ),
          ),
        ]),
        const Divider(height: 1, color: HD.hairline),
        Row(children: [
          if (status != 'published')
            Expanded(
              child: TextButton.icon(
                onPressed: () => _moderate(id, 'approve'),
                icon: const Icon(Icons.check, size: 18, color: HD.positive),
                label: Text(l.adminReelApprove,
                    style: const TextStyle(color: HD.positive)),
              ),
            ),
          if (status == 'published')
            Expanded(
              child: TextButton.icon(
                onPressed: () => _moderate(id, 'hide'),
                icon: const Icon(Icons.visibility_off_outlined,
                    size: 18, color: HD.warning),
                label: Text(l.adminReelHide,
                    style: const TextStyle(color: HD.warning)),
              ),
            ),
          Expanded(
            child: TextButton.icon(
              onPressed: () => _rejectWithReason(id),
              icon: const Icon(Icons.close, size: 18, color: HD.negative),
              label: Text(l.adminReelReject,
                  style: const TextStyle(color: HD.negative)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6)),
        child: Text(t,
            style: TextStyle(
                color: c, fontSize: 10.5, fontWeight: FontWeight.bold)),
      );
}
