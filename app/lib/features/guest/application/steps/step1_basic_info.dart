/// Step 1 — 基本情報 (basic applicant info).
///
/// Collects applicant name, phone, email, and move-in date.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class ApplicationStep1BasicInfo extends StatefulWidget {
  const ApplicationStep1BasicInfo({
    super.key,
    required this.onNext,
    this.initialName = '',
    this.initialPhone = '',
    this.initialEmail = '',
  });

  final void Function({
    required String name,
    required String phone,
    required String email,
  }) onNext;
  final String initialName;
  final String initialPhone;
  final String initialEmail;

  @override
  State<ApplicationStep1BasicInfo> createState() =>
      _ApplicationStep1BasicInfoState();
}

class _ApplicationStep1BasicInfoState
    extends State<ApplicationStep1BasicInfo> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onNext(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        children: [
          DsFormSection(
            title: l.jp_step_basic_info,
            children: [
              DsTextField(
                controller: _nameCtrl,
                label: '申込人氏名',
                hint: '山田 太郎',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '氏名を入力してください' : null,
              ),
              DsTextField(
                controller: _phoneCtrl,
                label: '電話番号',
                hint: '090-1234-5678',
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '電話番号を入力してください' : null,
              ),
              DsTextField(
                controller: _emailCtrl,
                label: 'メールアドレス',
                hint: 'taro@example.com',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'メールアドレスを入力してください';
                  if (!v.contains('@')) return 'メールアドレスの形式が正しくありません';
                  return null;
                },
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: DsButton(label: '次へ', onPressed: _next),
          ),
        ],
      ),
    );
  }
}
