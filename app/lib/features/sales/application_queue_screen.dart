/// JP sales agent application queue screen.
///
/// Lists pending 入居申込 for the agent's assigned listings.
/// Agent can approve or reject each application.
///
/// Route: /sales/applications (GoRoute).
/// Provider: none — uses [IJpApplicationRepository].
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/jp_application.dart';
import 'package:house_booking/data/repositories/jp/mock_jp_application_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_application_repository.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class ApplicationQueueScreen extends StatefulWidget {
  /// Route: /sales/applications
  const ApplicationQueueScreen({
    super.key,
    IJpApplicationRepository? repository,
  }) : _repository = repository;

  final IJpApplicationRepository? _repository;

  @override
  State<ApplicationQueueScreen> createState() =>
      _ApplicationQueueScreenState();
}

class _ApplicationQueueScreenState extends State<ApplicationQueueScreen> {
  late final IJpApplicationRepository _repo;
  List<JpApplication> _applications = [];
  bool _loading = true;

  static const int _agentId = 501;

  @override
  void initState() {
    super.initState();
    _repo = widget._repository ?? MockJpApplicationRepository();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _repo.listForAgent(_agentId);
      if (mounted) setState(() {
        _applications = list;
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
      appBar: DsAppBar(eyebrow: '仲介', title: l.jp_application_queue_title),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : _applications.isEmpty
              ? DsEmptyState(
                  icon: Icons.assignment_outlined,
                  title: '申込はありません',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _applications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) => _ApplicationCard(
                      application: _applications[idx],
                      repository: _repo,
                      onRefresh: _load,
                    ),
                  ),
                ),
    );
  }
}

class _ApplicationCard extends StatefulWidget {
  const _ApplicationCard({
    required this.application,
    required this.repository,
    required this.onRefresh,
  });

  final JpApplication application;
  final IJpApplicationRepository repository;
  final VoidCallback onRefresh;

  @override
  State<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<_ApplicationCard> {
  bool _busy = false;
  bool _expanded = false;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _decide(String decision) async {
    setState(() => _busy = true);
    try {
      await widget.repository.review(JpApplicationReview(
        applicationId: widget.application.id,
        decision: decision,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      ));
      widget.onRefresh();
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final app = widget.application;
    final isPending = app.status == JpApplicationStatus.submitted ||
        app.status == JpApplicationStatus.underReview;

    return Container(
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending ? HD.warning.withOpacity(0.4) : HD.hairline,
        ),
      ),
      child: Column(
        children: [
          // Header tile
          DsListTile(
            leading: const Icon(Icons.assignment_ind_outlined,
                color: HD.inkMuted, size: 20),
            title: app.applicantName,
            subtitle: app.listingTitle,
            trailing: _StatusPill(status: app.status, l: l),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          // Expanded detail + decision
          if (_expanded) ...[
            const Divider(color: HD.hairline, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (app.applicantPhone.isNotEmpty)
                    _row('電話', app.applicantPhone),
                  if (app.applicantEmail.isNotEmpty)
                    _row('メール', app.applicantEmail),
                  if (app.employer != null) ...[
                    _row('勤務先', app.employer!.companyName),
                    _row('年収', '¥${app.employer!.annualIncomeJpy}'),
                  ],
                  if (isPending) ...[
                    const SizedBox(height: 12),
                    DsTextField(
                      controller: _noteCtrl,
                      label: '審査メモ（任意）',
                      hint: '内部メモを記入してください',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DsButton(
                            label: _busy ? '処理中...' : l.jp_reject_application,
                            onPressed: _busy ? null : () => _decide('rejected'),
                            variant: DsButtonVariant.secondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DsButton(
                            label: _busy ? '処理中...' : l.jp_approve_application,
                            onPressed: _busy ? null : () => _decide('approved'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: HD.inkMuted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, color: HD.ink)),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.l});

  final JpApplicationStatus status;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _forStatus(status, l);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  static (String, Color) _forStatus(
      JpApplicationStatus s, AppLocalizations l) {
    switch (s) {
      case JpApplicationStatus.submitted:
        return (l.jp_application_status_submitted, HD.warning);
      case JpApplicationStatus.underReview:
        return (l.jp_application_status_under_review, Colors.blue);
      case JpApplicationStatus.approved:
        return (l.jp_application_status_approved, Colors.green);
      case JpApplicationStatus.rejected:
        return (l.jp_application_status_rejected, HD.accent);
      case JpApplicationStatus.withdrawn:
        return (l.jp_application_status_withdrawn, HD.inkMuted);
      default:
        return (l.jp_application_status_draft, HD.inkMuted);
    }
  }
}
