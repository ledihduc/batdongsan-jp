import 'package:flutter/widgets.dart';

import 'package:house_booking/data/services/user_prefs_service.dart';

/// Ngôn ngữ ứng dụng (i18n P0) — Việt (mặc định) · Anh · Trung. Lưu qua
/// UserPrefsService (localStorage trên web); MaterialApp.locale đọc từ đây.
class LocaleProvider extends ChangeNotifier {
  static const supported = <Locale>[Locale('ja'), Locale('vi'), Locale('en'), Locale('zh')];

  Locale _locale = const Locale('ja');
  Locale get locale => _locale;

  /// Nạp ngôn ngữ đã lưu (gọi lúc khởi động). Không throw.
  Future<void> load() async {
    final code = await UserPrefsService.instance.getLang();
    if (code != null && supported.any((l) => l.languageCode == code)) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  void setLocale(String code) {
    if (_locale.languageCode == code) return;
    if (!supported.any((l) => l.languageCode == code)) return;
    _locale = Locale(code);
    UserPrefsService.instance.setLang(code);
    notifyListeners();
  }
}
