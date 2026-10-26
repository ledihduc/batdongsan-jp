/// Deposit settlement — owner itemize screen (敷金精算 オーナー画面).
///
/// Owner adds deduction lines (title, amount, photos).
/// Live net refund total shown at bottom.
/// Submit sends to tenant_review state.
///
/// Route: /settlements/:id/itemize (GoRoute, JP-gated).
/// Provider: none — [ISettlementRepository] injected by constructor.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/image_grid_uploader.dart';
import 'package:house_booking/data/models/jp/deposit_settlement.dart';
import 'package:house_booking/data/repositories/jp/mock_settlement_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_settlement_repository.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Route: /settlements/:id/itemize
class OwnerItemizeScreen extends StatefulWidget {
  const OwnerItemizeScreen({
    super.key,
    required this.settlementId,
    this.repository,
  });

  final int settlementId;
  final ISettlementRepository? repository;

  @override
  State<OwnerItemizeScreen> createState() => _OwnerItemizeScreenState();
}

class _OwnerItemizeScreenState extends State<OwnerItemizeScreen> {
  late final ISettlementRepository _repo;
  JpDepositSettlement? _settlement;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  // Local editable deduction list (mirrors the settlement).
  final List<_EditableDeduction> _lines = [];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MockSettlementRepository();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await _repo.getSettlement(widget.settlementId);
      if (mounted) {
        setState(() {
          _settlement = s;
          _loading = false;
          _lines
            ..clear()
            ..addAll(s.deductions.map(_EditableDeduction.fromLine));
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _addLine() {
    setState(() => _lines.add(_EditableDeduction.empty()));
  }

  void _removeLine(int index) {
    setState(() => _lines.removeAt(index));
  }

  int get _totalDeduction =>
      _lines.fold(0, (sum, l) => sum + (int.tryParse(l.amountCtrl.text) ?? 0));

  int get _netRefund => (_settlement?.depositYen ?? 0) - _totalDeduction;

  Future<void> _submit() async {
    final settlement = _settlement;
    if (settlement == null) return;

    // Validate: all lines must have title and positive amount.
    for (final line in _lines) {
      if (line.titleCtrl.text.trim().isEmpty) {
        AppFeedback.error(context, '全ての項目にタイトルを入力してください');
        return;
      }
      final amt = int.tryParse(line.amountCtrl.text) ?? 0;
      if (amt <= 0) {
        AppFeedback.error(context, '全ての金額は1円以上で入力してください');
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final deductions = _lines.map((l) {
        return DeductionLine(
          id: l.id ?? 'new-${DateTime.now().millisecondsSinceEpoch}',
          title: l.titleCtrl.text.trim(),
          amountYen: int.tryParse(l.amountCtrl.text) ?? 0,
          photoUrls: l.images.map((img) => img.url ?? '').where((u) => u.isNotEmpty).toList(),
          note: l.noteCtrl.text.trim().isEmpty ? null : l.noteCtrl.text.trim(),
        );
      }).toList();

      await _repo.updateDeductions(settlement.id, deductions);
      await _repo.submitToTenant(settlement.id);
      if (mounted) {
        AppFeedback.success(context, '入居者に送付しました');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        AppFeedback.error(context, e.toString());
      }
    }
  }

  static Future<String> _stubUpload(List<int> bytes, String filename) async {
    // Replace with real upload client when BE is ready.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return 'https://cdn.example.com/uploads/$filename';
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        eyebrow: l.jp_settlement_eyebrow,
        title: l.jp_settlement_owner_title,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : _error != null
              ? DsErrorState(message: _error!, onRetry: _load)
              : _settlement == null
                  ? const SizedBox.shrink()
                  : _OwnerItemizeBody(
                      settlement: _settlement!,
                      lines: _lines,
                      netRefund: _netRefund,
                      onAddLine: _addLine,
                      onRemoveLine: _removeLine,
                      onSubmit: _submitting ? null : _submit,
                      submitting: _submitting,
                      uploadFn: _stubUpload,
                      onChanged: () => setState(() {}),
                      l: l,
                    ),
    );
  }
}

class _OwnerItemizeBody extends StatelessWidget {
  const _OwnerItemizeBody({
    required this.settlement,
    required this.lines,
    required this.netRefund,
    required this.onAddLine,
    required this.onRemoveLine,
    required this.onSubmit,
    required this.submitting,
    required this.uploadFn,
    required this.onChanged,
    required this.l,
  });

  final JpDepositSettlement settlement;
  final List<_EditableDeduction> lines;
  final int netRefund;
  final VoidCallback onAddLine;
  final void Function(int) onRemoveLine;
  final VoidCallback? onSubmit;
  final bool submitting;
  final ImageUploadFn uploadFn;
  final VoidCallback onChanged;
  final AppLocalizations l;

  static final _yenFormat = NumberFormat('#,###', 'ja_JP');
  String _formatYen(int v) => '¥${_yenFormat.format(v)}';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Deposit summary
              DsFormSection(
                title: l.jp_settlement_deposit_summary,
                children: [
                  _InfoRow(label: l.jp_settlement_property, value: settlement.propertyName),
                  _InfoRow(label: l.jp_settlement_room, value: settlement.roomNumber),
                  _InfoRow(label: l.jp_settlement_tenant, value: settlement.tenantName),
                  _InfoRow(label: l.jp_shikikin, value: _formatYen(settlement.depositYen)),
                ],
              ),
              const SizedBox(height: 8),
              // Deduction lines
              DsFormSection(
                title: l.jp_settlement_deductions,
                children: [
                  ...lines.asMap().entries.map((entry) {
                    final i = entry.key;
                    final line = entry.value;
                    return _DeductionLineCard(
                      index: i,
                      line: line,
                      onRemove: () => onRemoveLine(i),
                      uploadFn: uploadFn,
                      onChanged: onChanged,
                      l: l,
                    );
                  }),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: onAddLine,
                    icon: const Icon(Icons.add, color: HD.accent, size: 18),
                    label: Text(
                      l.jp_settlement_add_deduction,
                      style: const TextStyle(color: HD.accent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Live net refund total
              _NetRefundCard(
                depositYen: settlement.depositYen,
                netRefund: netRefund,
                formatYen: _formatYen,
                l: l,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
        // Sticky submit
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: DsButton(
              label: l.jp_settlement_submit_to_tenant,
              variant: DsButtonVariant.primary,
              size: DsButtonSize.large,
              expand: true,
              isLoading: submitting,
              onPressed: onSubmit,
            ),
          ),
        ),
      ],
    );
  }
}

class _DeductionLineCard extends StatelessWidget {
  const _DeductionLineCard({
    required this.index,
    required this.line,
    required this.onRemove,
    required this.uploadFn,
    required this.onChanged,
    required this.l,
  });

  final int index;
  final _EditableDeduction line;
  final VoidCallback onRemove;
  final ImageUploadFn uploadFn;
  final VoidCallback onChanged;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${l.jp_settlement_deduction_item} ${index + 1}',
                style: HD.eyebrow(),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18, color: HD.inkMuted),
                tooltip: l.jp_settlement_remove_deduction,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DsTextField(
            controller: line.titleCtrl,
            label: l.jp_settlement_deduction_title,
            hint: '例：畳表替え',
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 10),
          DsTextField(
            controller: line.amountCtrl,
            label: l.jp_settlement_deduction_amount,
            hint: '例：25000',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 10),
          Text(l.jp_settlement_deduction_photos, style: HD.caption()),
          const SizedBox(height: 6),
          ImageGridUploader(
            images: line.images,
            uploadFn: uploadFn,
            maxImages: 3,
            crossAxisCount: 3,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _NetRefundCard extends StatelessWidget {
  const _NetRefundCard({
    required this.depositYen,
    required this.netRefund,
    required this.formatYen,
    required this.l,
  });

  final int depositYen;
  final int netRefund;
  final String Function(int) formatYen;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final refundColor = netRefund >= 0 ? HD.positive : HD.accent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HD.hairlineStrong),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.jp_shikikin, style: HD.body(size: 13).copyWith(color: HD.inkSoft)),
              Text(formatYen(depositYen), style: HD.body(size: 13)),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: HD.hairline),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.jp_settlement_net_refund,
                style: HD.body(size: 15).copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                formatYen(netRefund),
                style: HD.body(size: 15).copyWith(
                  fontWeight: FontWeight.bold,
                  color: refundColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: HD.body(size: 13).copyWith(color: HD.inkSoft)),
          Text(value, style: HD.body(size: 13)),
        ],
      ),
    );
  }
}

/// Mutable state for one deduction line being edited.
class _EditableDeduction {
  _EditableDeduction({
    this.id,
    required this.titleCtrl,
    required this.amountCtrl,
    required this.noteCtrl,
    required this.images,
  });

  factory _EditableDeduction.empty() => _EditableDeduction(
        id: null,
        titleCtrl: TextEditingController(),
        amountCtrl: TextEditingController(),
        noteCtrl: TextEditingController(),
        images: [],
      );

  factory _EditableDeduction.fromLine(DeductionLine line) => _EditableDeduction(
        id: line.id,
        titleCtrl: TextEditingController(text: line.title),
        amountCtrl: TextEditingController(text: line.amountYen.toString()),
        noteCtrl: TextEditingController(text: line.note ?? ''),
        images: line.photoUrls.map(UploadImage.existing).toList(),
      );

  final String? id;
  final TextEditingController titleCtrl;
  final TextEditingController amountCtrl;
  final TextEditingController noteCtrl;
  final List<UploadImage> images;

  void dispose() {
    titleCtrl.dispose();
    amountCtrl.dispose();
    noteCtrl.dispose();
  }
}
