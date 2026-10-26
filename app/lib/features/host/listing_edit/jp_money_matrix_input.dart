/// JP money matrix input widget for the listing edit form.
///
/// Renders all chintai money fields (月額家賃/管理費/敷金/礼金/更新料/仲介手数料率)
/// with ¥ formatting and validation. Used inside [JpTermsEditSection].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/jp_rental_terms.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class JpMoneyMatrixInput extends StatefulWidget {
  const JpMoneyMatrixInput({
    super.key,
    required this.onChanged,
    this.initialTerms,
  });

  final void Function(Map<String, dynamic> values) onChanged;
  final JpRentalTerms? initialTerms;

  @override
  State<JpMoneyMatrixInput> createState() => _JpMoneyMatrixInputState();
}

class _JpMoneyMatrixInputState extends State<JpMoneyMatrixInput> {
  late final TextEditingController _rentCtrl;
  late final TextEditingController _mgmtCtrl;
  late final TextEditingController _shikikinCtrl;
  late final TextEditingController _reikinCtrl;
  late final TextEditingController _koushinCtrl;
  late final TextEditingController _brokerageCtrl;
  late final TextEditingController _guaranteeCtrl;
  bool _taxIncluded = false;

  @override
  void initState() {
    super.initState();
    final t = widget.initialTerms;
    _rentCtrl = TextEditingController(text: t?.monthlyRent.toString() ?? '');
    _mgmtCtrl = TextEditingController(
        text: t?.managementFee?.toString() ?? '');
    _shikikinCtrl =
        TextEditingController(text: t?.shikikin?.toString() ?? '');
    _reikinCtrl =
        TextEditingController(text: t?.reikin?.toString() ?? '');
    _koushinCtrl =
        TextEditingController(text: t?.koushinryo?.toString() ?? '');
    _brokerageCtrl = TextEditingController(
        text: t?.brokerageFeeRate?.toString() ?? '');
    _guaranteeCtrl = TextEditingController(
        text: t?.guaranteeCompanyFee?.toString() ?? '');
    _taxIncluded = t?.taxIncluded ?? false;

    for (final c in [
      _rentCtrl,
      _mgmtCtrl,
      _shikikinCtrl,
      _reikinCtrl,
      _koushinCtrl,
      _brokerageCtrl,
      _guaranteeCtrl,
    ]) {
      c.addListener(_notifyChanged);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _rentCtrl,
      _mgmtCtrl,
      _shikikinCtrl,
      _reikinCtrl,
      _koushinCtrl,
      _brokerageCtrl,
      _guaranteeCtrl,
    ]) {
      c.removeListener(_notifyChanged);
      c.dispose();
    }
    super.dispose();
  }

  void _notifyChanged() {
    widget.onChanged({
      'monthly_rent': int.tryParse(_rentCtrl.text) ?? 0,
      'management_fee': int.tryParse(_mgmtCtrl.text),
      'shikikin': int.tryParse(_shikikinCtrl.text),
      'reikin': int.tryParse(_reikinCtrl.text),
      'koushinryo': int.tryParse(_koushinCtrl.text),
      'brokerage_fee_rate': double.tryParse(_brokerageCtrl.text),
      'guarantee_company_fee': int.tryParse(_guaranteeCtrl.text),
      'tax_included': _taxIncluded,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _yenField(_rentCtrl, l.jp_monthly_rent, required: true),
        _yenField(_mgmtCtrl, l.jp_management_fee),
        _yenField(_shikikinCtrl, l.jp_shikikin),
        _yenField(_reikinCtrl, l.jp_reikin),
        _yenField(_koushinCtrl, l.jp_koushinryo),
        DsTextField(
          controller: _brokerageCtrl,
          label: '${l.jp_brokerage}（率）',
          hint: '1.0（月額の倍率）',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            final rate = double.tryParse(v);
            if (rate == null || rate < 0 || rate > 2) {
              return '0〜2の範囲で入力してください';
            }
            return null;
          },
        ),
        _yenField(_guaranteeCtrl, '保証会社料'),
        SwitchListTile(
          title: Text(l.jp_shouhizei + '込み'),
          value: _taxIncluded,
          activeColor: HD.accent,
          onChanged: (v) {
            setState(() => _taxIncluded = v);
            _notifyChanged();
          },
        ),
      ],
    );
  }

  Widget _yenField(
    TextEditingController ctrl,
    String label, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DsTextField(
        controller: ctrl,
        label: label,
        hint: '例: 100000',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        prefixIcon: Icons.currency_yen,
        validator: required
            ? (v) {
                if (v == null || v.trim().isEmpty) return '必須項目です';
                final n = int.tryParse(v);
                if (n == null || n <= 0) return '正の数値を入力してください';
                return null;
              }
            : null,
      ),
    );
  }
}
