/// 5 threshold input fields for delegation approval thresholds (AC-31b).
///
/// Each field configures the VND amount above which the operator must request
/// owner approval. Empty = no threshold (unlimited for that action type).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/operator_delegation_model.dart';

class ThresholdConfigWidget extends StatefulWidget {
  const ThresholdConfigWidget({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  final DelegationThresholds initial;
  final ValueChanged<DelegationThresholds> onChanged;

  @override
  State<ThresholdConfigWidget> createState() =>
      _ThresholdConfigWidgetState();
}

class _ThresholdConfigWidgetState extends State<ThresholdConfigWidget> {
  late final TextEditingController _contractCreate;
  late final TextEditingController _expenseApproval;
  late final TextEditingController _refundApproval;
  late final TextEditingController _kb04Filing;
  late final TextEditingController _terminationApproval;

  @override
  void initState() {
    super.initState();
    _contractCreate =
        TextEditingController(text: _fmt(widget.initial.contractCreate));
    _expenseApproval =
        TextEditingController(text: _fmt(widget.initial.expenseApproval));
    _refundApproval =
        TextEditingController(text: _fmt(widget.initial.refundApproval));
    _kb04Filing =
        TextEditingController(text: _fmt(widget.initial.kb04Filing));
    _terminationApproval = TextEditingController(
        text: _fmt(widget.initial.terminationApproval));
  }

  @override
  void dispose() {
    _contractCreate.dispose();
    _expenseApproval.dispose();
    _refundApproval.dispose();
    _kb04Filing.dispose();
    _terminationApproval.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(DelegationThresholds(
      contractCreate: _parse(_contractCreate.text),
      expenseApproval: _parse(_expenseApproval.text),
      refundApproval: _parse(_refundApproval.text),
      kb04Filing: _parse(_kb04Filing.text),
      terminationApproval: _parse(_terminationApproval.text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _field('Tạo hợp đồng (₫)', _contractCreate),
        const SizedBox(height: HD.s12),
        _field('Phê duyệt chi phí (₫)', _expenseApproval),
        const SizedBox(height: HD.s12),
        _field('Hoàn tiền (₫)', _refundApproval),
        const SizedBox(height: HD.s12),
        _field('Khai báo KB04 (₫)', _kb04Filing),
        const SizedBox(height: HD.s12),
        _field('Chấm dứt hợp đồng (₫)', _terminationApproval),
        const SizedBox(height: HD.s8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            'Để trống = không giới hạn. ≥ 50.000.000₫ yêu cầu xác thực sinh trắc học.',
            style: HD.caption(color: HD.inkMuted),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return DsTextField(
      controller: controller,
      label: label,
      hint: 'Không giới hạn',
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => _notify(),
    );
  }

  String _fmt(double? value) =>
      value != null ? value.toStringAsFixed(0) : '';

  double? _parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }
}
