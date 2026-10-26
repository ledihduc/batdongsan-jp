/// 審査 (application review) screen — full detail view with decision form.
///
/// Shows all application fields readonly + document links + radio buttons
/// for decision (approve / reject / needs_info) + textarea for reason.
/// Used by both Sales agent and Owner personas.
///
/// Route: /applications/:id/review (GoRoute).
/// Provider: none — uses [IJpApplicationRepository] via constructor.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/jp_application.dart';
import 'package:house_booking/data/repositories/jp/mock_jp_application_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_application_repository.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Review decision values.
const String kDecisionApprove = 'approved';
const String kDecisionReject = 'rejected';
const String kDecisionNeedsInfo = 'needs_info';

class ApplicationReviewScreen extends StatefulWidget {
  /// Route: /applications/:id/review
  const ApplicationReviewScreen({
    super.key,
    required this.applicationId,
    this.repository,
  });

  final int applicationId;
  final IJpApplicationRepository? repository;

  @override
  State<ApplicationReviewScreen> createState() =>
      _ApplicationReviewScreenState();
}

class _ApplicationReviewScreenState extends State<ApplicationReviewScreen> {
  late final IJpApplicationRepository _repo;
  JpApplication? _application;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  String? _decision;
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MockJpApplicationRepository();
    _load();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final app = await _repo.getById(widget.applicationId);
      if (mounted) setState(() {
        _application = app;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get _canSubmit =>
      _decision != null && _decision!.isNotEmpty && !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    // needs_info is not a valid ReviewDecision backend value —
    // map it to a note-bearing rejection for now.
    final decision = _decision == kDecisionNeedsInfo
        ? kDecisionReject
        : _decision!;
    final note = _decision == kDecisionNeedsInfo
        ? '追加情報が必要: ${_reasonCtrl.text.trim()}'
        : _reasonCtrl.text.trim().isEmpty
            ? null
            : _reasonCtrl.text.trim();
    setState(() => _submitting = true);
    try {
      await _repo.review(JpApplicationReview(
        applicationId: widget.applicationId,
        decision: decision,
        note: note,
      ));
      if (mounted) {
        final l = AppLocalizations.of(context);
        AppFeedback.success(context, l.review_submitted);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(eyebrow: '審査', title: l.review_decision),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : _error != null && _application == null
              ? DsEmptyState(
                  icon: Icons.error_outline,
                  title: _error!,
                )
              : _buildBody(l),
    );
  }

  Widget _buildBody(AppLocalizations l) {
    final app = _application!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              // ── Applicant info ──────────────────────────────────────────
              _SectionCard(
                title: l.review_applicant_info,
                children: [
                  _InfoRow('氏名', app.applicantName),
                  if (app.applicantPhone.isNotEmpty)
                    _InfoRow('電話', app.applicantPhone),
                  if (app.applicantEmail.isNotEmpty)
                    _InfoRow('メール', app.applicantEmail),
                  _InfoRow('物件', app.listingTitle ?? '—'),
                  _InfoRow('ステータス',
                      jpApplicationStatusToString(app.status)),
                ],
              ),
              // ── Employer info ──────────────────────────────────────────
              if (app.employer != null) ...[
                _SectionCard(
                  title: l.review_employer_info,
                  children: [
                    _InfoRow('勤務先', app.employer!.companyName),
                    _InfoRow('雇用形態', app.employer!.employmentType),
                    _InfoRow('年収',
                        '¥${app.employer!.annualIncomeJpy}'),
                    if (app.employer!.yearsEmployed != null)
                      _InfoRow('勤続年数',
                          '${app.employer!.yearsEmployed}年'),
                  ],
                ),
              ],
              // ── Guarantor info ─────────────────────────────────────────
              if (app.guarantor != null) ...[
                _SectionCard(
                  title: l.review_guarantor_info,
                  children: [
                    _InfoRow('氏名', app.guarantor!.name),
                    _InfoRow('続柄', app.guarantor!.relationship),
                    _InfoRow('電話', app.guarantor!.phone),
                    if (app.guarantor!.annualIncomeJpy != null)
                      _InfoRow('年収',
                          '¥${app.guarantor!.annualIncomeJpy}'),
                  ],
                ),
              ],
              // ── Documents ─────────────────────────────────────────────
              _SectionCard(
                title: l.review_documents,
                children: app.documents.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(l.review_no_documents,
                              style: HD.body()),
                        )
                      ]
                    : app.documents.map((doc) => DsListTile(
                          leading: const Icon(Icons.description_outlined,
                              color: HD.inkMuted, size: 20),
                          title: doc.type,
                          subtitle: doc.uploadedAt != null
                              ? doc.uploadedAt!.split('T').first
                              : null,
                        )).toList(),
              ),
              // ── Decision form ──────────────────────────────────────────
              _SectionCard(
                title: l.review_decision,
                children: [
                  // Approve
                  _DecisionRadio(
                    value: kDecisionApprove,
                    groupValue: _decision,
                    label: l.review_approve,
                    color: Colors.green,
                    onChanged: (v) => setState(() => _decision = v),
                  ),
                  // Reject
                  _DecisionRadio(
                    value: kDecisionReject,
                    groupValue: _decision,
                    label: l.review_reject,
                    color: HD.accent,
                    onChanged: (v) => setState(() => _decision = v),
                  ),
                  // Needs info
                  _DecisionRadio(
                    value: kDecisionNeedsInfo,
                    groupValue: _decision,
                    label: l.review_needs_info,
                    color: HD.warning,
                    onChanged: (v) => setState(() => _decision = v),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DsTextField(
                      controller: _reasonCtrl,
                      label: l.review_reason,
                      hint: l.review_reason_hint,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Text(_error!,
                      style: HD.body(size: 12)
                          .copyWith(color: HD.accent)),
                ),
            ],
          ),
        ),
        // Sticky submit button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: DsButton(
            label: _submitting ? l.review_submitting : l.review_submit,
            variant: DsButtonVariant.primary,
            size: DsButtonSize.large,
            expand: true,
            isLoading: _submitting,
            onPressed: _canSubmit ? _submit : null,
          ),
        ),
      ],
    );
  }
}

/// Card section wrapper.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(title, style: HD.eyebrow()),
          ),
          const Divider(color: HD.hairline, height: 1),
          ...children,
        ],
      ),
    );
  }
}

/// Read-only key-value row.
class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
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

/// Radio button for a decision option.
class _DecisionRadio extends StatelessWidget {
  const _DecisionRadio({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.color,
    required this.onChanged,
  });

  final String value;
  final String? groupValue;
  final String label;
  final Color color;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = groupValue == value;
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: color,
            ),
            Text(
              label,
              style: HD.body().copyWith(
                color: selected ? color : HD.ink,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
