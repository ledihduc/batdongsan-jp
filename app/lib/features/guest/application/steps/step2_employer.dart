/// Step 2 — 勤務先・収入 (employer and income).
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/jp_application.dart';
import 'package:house_booking/l10n/app_localizations.dart';

const _kEmploymentTypes = ['正社員', '契約社員', 'パート・アルバイト', '自営業', '無職', 'その他'];

class ApplicationStep2Employer extends StatefulWidget {
  const ApplicationStep2Employer({
    super.key,
    required this.onNext,
    required this.onBack,
    this.initialEmployer,
  });

  final void Function(JpEmployerInfo employer) onNext;
  final VoidCallback onBack;
  final JpEmployerInfo? initialEmployer;

  @override
  State<ApplicationStep2Employer> createState() =>
      _ApplicationStep2EmployerState();
}

class _ApplicationStep2EmployerState extends State<ApplicationStep2Employer> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _companyCtrl;
  late final TextEditingController _incomeCtrl;
  late final TextEditingController _yearsCtrl;
  String _employmentType = _kEmploymentTypes.first;

  @override
  void initState() {
    super.initState();
    _companyCtrl = TextEditingController(
        text: widget.initialEmployer?.companyName ?? '');
    _incomeCtrl = TextEditingController(
        text: widget.initialEmployer?.annualIncomeJpy.toString() ?? '');
    _yearsCtrl = TextEditingController(
        text: widget.initialEmployer?.yearsEmployed?.toString() ?? '');
    _employmentType = widget.initialEmployer?.employmentType ??
        _kEmploymentTypes.first;
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _incomeCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onNext(JpEmployerInfo(
      companyName: _companyCtrl.text.trim(),
      employmentType: _employmentType,
      annualIncomeJpy: int.tryParse(_incomeCtrl.text.replaceAll(',', '')) ?? 0,
      yearsEmployed: int.tryParse(_yearsCtrl.text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        children: [
          DsFormSection(
            title: l.jp_step_employer,
            children: [
              DsTextField(
                controller: _companyCtrl,
                label: l.jp_employer,
                hint: '株式会社〇〇',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '勤務先を入力してください' : null,
              ),
              // Employment type picker
              DropdownButtonFormField<String>(
                value: _employmentType,
                decoration: const InputDecoration(
                  labelText: '雇用形態',
                  border: OutlineInputBorder(),
                ),
                items: _kEmploymentTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _employmentType = v);
                },
              ),
              DsTextField(
                controller: _incomeCtrl,
                label: l.jp_annual_income,
                hint: '3500000（円単位）',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '年収を入力してください';
                  final n = int.tryParse(v.replaceAll(',', ''));
                  if (n == null || n < 0) return '正しい金額を入力してください';
                  return null;
                },
              ),
              DsTextField(
                controller: _yearsCtrl,
                label: '勤続年数（任意）',
                hint: '3',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const Spacer(),
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
                Expanded(child: DsButton(label: '次へ', onPressed: _next)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
