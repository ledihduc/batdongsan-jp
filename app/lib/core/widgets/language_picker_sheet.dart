/// Bộ chọn ngôn ngữ dùng chung: Settings (đã đăng nhập), drawer trang chủ và AppBar màn chat
/// cho khách (plan 20261027-1102 Phase 14, S13, T16). Provider: [LocaleProvider].
///
/// Tên ngôn ngữ viết bằng chính ngôn ngữ đó (không qua ARB) — người không đọc được ngôn ngữ
/// đang hiển thị vẫn tìm ra ngôn ngữ của mình.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/locale_provider.dart';
import 'package:provider/provider.dart';

const kAppLanguages = <(String, String)>[('ja', '日本語'), ('vi', 'Tiếng Việt'), ('en', 'English'), ('zh', '中文')];

/// Tên hiển thị của mã ngôn ngữ (`'vi'` ⇒ `'Tiếng Việt'`); mã lạ ⇒ chính mã đó.
String appLanguageName(String code) =>
    kAppLanguages.firstWhere((e) => e.$1 == code, orElse: () => (code, code)).$2;

/// Bottom sheet chọn ngôn ngữ → [LocaleProvider.setLocale] (lưu + rebuild toàn app).
Future<void> showLanguagePickerSheet(BuildContext context) {
  final provider = context.read<LocaleProvider>();
  final current = provider.locale.languageCode;
  final l = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: HD.paper,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => SafeArea(
      // Cuộn được: màn ngang thấp (sheet giới hạn 9/16 chiều cao) vẫn tới được mọi ngôn ngữ (QA P14 F4).
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [Text(l.chooseLanguage, style: HD.eyebrow())]),
            ),
            for (final e in kAppLanguages)
              ListTile(
                leading: Icon(current == e.$1 ? Icons.check : null, color: HD.accent),
                title: Text(e.$2),
                onTap: () {
                  provider.setLocale(e.$1);
                  Navigator.pop(sheetContext);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Nút 🌐 mở [showLanguagePickerSheet] — dùng ở AppBar.
class LanguagePickerButton extends StatelessWidget {
  const LanguagePickerButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        key: const Key('language-picker-button'),
        tooltip: AppLocalizations.of(context).language,
        icon: const Icon(Icons.language),
        onPressed: () => showLanguagePickerSheet(context),
      );
}
