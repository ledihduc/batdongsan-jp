/// Step 3 — 保証人・緊急連絡先 (guarantor and emergency contact).
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/jp_application.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class ApplicationStep3Guarantor extends StatefulWidget {
  const ApplicationStep3Guarantor({
    super.key,
    required this.onNext,
    required this.onBack,
    this.initialGuarantor,
    this.initialEmergencyContact,
  });

  final void Function(
    JpContactPerson? guarantor,
    JpContactPerson emergencyContact,
  ) onNext;
  final VoidCallback onBack;
  final JpContactPerson? initialGuarantor;
  final JpContactPerson? initialEmergencyContact;

  @override
  State<ApplicationStep3Guarantor> createState() =>
      _ApplicationStep3GuarantorState();
}

class _ApplicationStep3GuarantorState
    extends State<ApplicationStep3Guarantor> {
  final _formKey = GlobalKey<FormState>();
  bool _hasGuarantor = true;

  // Guarantor fields
  final _gNameCtrl = TextEditingController();
  final _gRelCtrl = TextEditingController();
  final _gPhoneCtrl = TextEditingController();

  // Emergency contact fields
  final _eNameCtrl = TextEditingController();
  final _eRelCtrl = TextEditingController();
  final _ePhoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final g = widget.initialGuarantor;
    if (g != null) {
      _gNameCtrl.text = g.name;
      _gRelCtrl.text = g.relationship;
      _gPhoneCtrl.text = g.phone;
    }
    final e = widget.initialEmergencyContact;
    if (e != null) {
      _eNameCtrl.text = e.name;
      _eRelCtrl.text = e.relationship;
      _ePhoneCtrl.text = e.phone;
    }
  }

  @override
  void dispose() {
    _gNameCtrl.dispose();
    _gRelCtrl.dispose();
    _gPhoneCtrl.dispose();
    _eNameCtrl.dispose();
    _eRelCtrl.dispose();
    _ePhoneCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final guarantor = _hasGuarantor
        ? JpContactPerson(
            name: _gNameCtrl.text.trim(),
            relationship: _gRelCtrl.text.trim(),
            phone: _gPhoneCtrl.text.trim(),
          )
        : null;
    final emergency = JpContactPerson(
      name: _eNameCtrl.text.trim(),
      relationship: _eRelCtrl.text.trim(),
      phone: _ePhoneCtrl.text.trim(),
    );
    widget.onNext(guarantor, emergency);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                DsFormSection(
                  title: l.jp_guarantor,
                  helper: '保証会社を利用する場合は不要な場合があります',
                  children: [
                    SwitchListTile(
                      title: const Text('連帯保証人あり'),
                      value: _hasGuarantor,
                      activeColor: HD.accent,
                      onChanged: (v) => setState(() => _hasGuarantor = v),
                    ),
                    if (_hasGuarantor) ...[
                      DsTextField(
                        controller: _gNameCtrl,
                        label: '保証人氏名',
                        hint: '山田 花子',
                        validator: (v) => _hasGuarantor &&
                                (v == null || v.trim().isEmpty)
                            ? '保証人氏名を入力してください'
                            : null,
                      ),
                      DsTextField(
                        controller: _gRelCtrl,
                        label: '続柄',
                        hint: '父',
                        validator: (v) => _hasGuarantor &&
                                (v == null || v.trim().isEmpty)
                            ? '続柄を入力してください'
                            : null,
                      ),
                      DsTextField(
                        controller: _gPhoneCtrl,
                        label: '電話番号',
                        hint: '090-0000-0000',
                        keyboardType: TextInputType.phone,
                        validator: (v) => _hasGuarantor &&
                                (v == null || v.trim().isEmpty)
                            ? '電話番号を入力してください'
                            : null,
                      ),
                    ],
                  ],
                ),
                DsFormSection(
                  title: l.jp_emergency_contact,
                  children: [
                    DsTextField(
                      controller: _eNameCtrl,
                      label: '緊急連絡先氏名',
                      hint: '山田 次郎',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '氏名を入力してください' : null,
                    ),
                    DsTextField(
                      controller: _eRelCtrl,
                      label: '続柄',
                      hint: '弟',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '続柄を入力してください' : null,
                    ),
                    DsTextField(
                      controller: _ePhoneCtrl,
                      label: '電話番号',
                      hint: '080-0000-0000',
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '電話番号を入力してください' : null,
                    ),
                  ],
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
