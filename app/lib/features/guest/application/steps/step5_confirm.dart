/// Step 5 — 確認・送信 (confirm and submit application).
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/jp_application.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class ApplicationStep5Confirm extends StatelessWidget {
  const ApplicationStep5Confirm({
    super.key,
    required this.application,
    required this.onSubmit,
    required this.onBack,
    this.submitting = false,
  });

  final JpApplication application;
  final VoidCallback onSubmit;
  final VoidCallback onBack;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '申込内容の確認',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: HD.inkMuted,
                ),
              ),
              const SizedBox(height: 12),

              // Basic info summary
              _SectionCard(
                title: l.jp_step_basic_info,
                rows: [
                  ('氏名', application.applicantName),
                  ('電話番号', application.applicantPhone),
                  ('メール', application.applicantEmail),
                ],
              ),

              // Employer summary
              if (application.employer != null)
                _SectionCard(
                  title: l.jp_step_employer,
                  rows: [
                    ('勤務先', application.employer!.companyName),
                    ('雇用形態', application.employer!.employmentType),
                    ('年収', '¥${_formatAmount(application.employer!.annualIncomeJpy)}'),
                  ],
                ),

              // Guarantor
              if (application.guarantor != null)
                _SectionCard(
                  title: l.jp_guarantor,
                  rows: [
                    ('氏名', application.guarantor!.name),
                    ('続柄', application.guarantor!.relationship),
                    ('電話', application.guarantor!.phone),
                  ],
                ),

              // Emergency contact
              if (application.emergencyContact != null)
                _SectionCard(
                  title: l.jp_emergency_contact,
                  rows: [
                    ('氏名', application.emergencyContact!.name),
                    ('続柄', application.emergencyContact!.relationship),
                    ('電話', application.emergencyContact!.phone),
                  ],
                ),

              // Documents
              if (application.documents.isNotEmpty)
                _SectionCard(
                  title: l.jp_step_documents,
                  rows: application.documents
                      .map((d) => (d.type, 'アップロード済み'))
                      .toList(),
                ),

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HD.accentTint,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: HD.accent.withOpacity(0.3)),
                ),
                child: const Text(
                  '送信後は内容の変更ができません。内容をご確認の上、申込を送信してください。',
                  style: TextStyle(fontSize: 12, color: HD.accent),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DsButton(
                  label: '戻る',
                  onPressed: onBack,
                  variant: DsButtonVariant.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DsButton(
                  label: submitting ? '送信中...' : l.jp_apply,
                  onPressed: submitting ? null : onSubmit,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatAmount(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    final start = s.length % 3;
    for (var i = 0; i < s.length; i++) {
      if (i != 0 && (i - start) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: HD.inkMuted,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(row.$1,
                          style: const TextStyle(
                              fontSize: 12, color: HD.inkMuted)),
                    ),
                    Expanded(
                      child: Text(row.$2,
                          style: const TextStyle(
                              fontSize: 13, color: HD.ink)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
