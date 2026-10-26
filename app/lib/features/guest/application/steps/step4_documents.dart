/// Step 4 — 書類アップロード (document uploads).
///
/// Tenant uploads required documents: 本人確認書類, 収入証明書, etc.
/// Uses a signed-URL flow via [IJpApplicationRepository.requestUploadUrl].
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/jp_application.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Required document types.
const _kRequiredDocTypes = [
  ('id_card', '本人確認書類（パスポート等）', true),
  ('income_certificate', '収入証明書', true),
  ('residence_certificate', '住民票', false),
  ('bank_statement', '通帳コピー（任意）', false),
];

class ApplicationStep4Documents extends StatefulWidget {
  const ApplicationStep4Documents({
    super.key,
    required this.applicationId,
    required this.onNext,
    required this.onBack,
    this.existingDocuments = const [],
  });

  final int applicationId;
  final void Function(List<JpDocumentRef> documents) onNext;
  final VoidCallback onBack;
  final List<JpDocumentRef> existingDocuments;

  @override
  State<ApplicationStep4Documents> createState() =>
      _ApplicationStep4DocumentsState();
}

class _ApplicationStep4DocumentsState
    extends State<ApplicationStep4Documents> {
  late final Map<String, JpDocumentRef?> _uploaded;

  @override
  void initState() {
    super.initState();
    _uploaded = {for (final (type, _, _) in _kRequiredDocTypes) type: null};
    for (final doc in widget.existingDocuments) {
      _uploaded[doc.type] = doc;
    }
  }

  bool get _canProceed {
    for (final (type, _, required) in _kRequiredDocTypes) {
      if (required && _uploaded[type] == null) return false;
    }
    return true;
  }

  Future<void> _simulateUpload(String docType) async {
    // In real app: show file picker → upload to presigned URL → get storage_key
    // Here we stub with a fake key so the wizard progresses.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    setState(() {
      _uploaded[docType] = JpDocumentRef(
        type: docType,
        storageKey: 'jp-apps/${widget.applicationId}/$docType/placeholder.pdf',
        uploadedAt: DateTime.now().toIso8601String(),
      );
    });
  }

  void _next() {
    if (!_canProceed) return;
    final docs = _uploaded.values.whereType<JpDocumentRef>().toList();
    widget.onNext(docs);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l.jp_upload_documents,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: HD.inkMuted,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '以下の書類をアップロードしてください。必須書類はすべて提出が必要です。',
                style: TextStyle(fontSize: 13, color: HD.inkSoft),
              ),
              const SizedBox(height: 16),
              ..._kRequiredDocTypes.map((entry) {
                final (type, label, required) = entry;
                final uploaded = _uploaded[type];
                return _DocUploadTile(
                  type: type,
                  label: label,
                  isRequired: required,
                  isUploaded: uploaded != null,
                  onUpload: () => _simulateUpload(type),
                );
              }),
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
                  onPressed: widget.onBack,
                  variant: DsButtonVariant.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DsButton(
                  label: '次へ',
                  onPressed: _canProceed ? _next : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocUploadTile extends StatelessWidget {
  const _DocUploadTile({
    required this.type,
    required this.label,
    required this.isRequired,
    required this.isUploaded,
    required this.onUpload,
  });

  final String type;
  final String label;
  final bool isRequired;
  final bool isUploaded;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUploaded ? Colors.green.withOpacity(0.4) : HD.hairline,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUploaded
                ? Icons.check_circle_outline
                : Icons.upload_file_outlined,
            color: isUploaded ? Colors.green : HD.inkMuted,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 14, color: HD.ink)),
                    ),
                    if (isRequired)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: HD.accentTint,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '必須',
                          style: TextStyle(
                              fontSize: 10, color: HD.accent),
                        ),
                      ),
                  ],
                ),
                if (isUploaded)
                  const Text(
                    'アップロード済み',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onUpload,
            child: Text(
              isUploaded ? '変更' : 'アップロード',
              style: const TextStyle(color: HD.accent, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
