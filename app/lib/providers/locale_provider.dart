import 'package:flutter/widgets.dart';

import 'package:house_booking/core/config/feature_flags.dart';
import 'package:house_booking/data/services/user_prefs_service.dart';

/// Ngôn ngữ ứng dụng — Nhật · Việt · Anh · Trung. Lưu qua UserPrefsService (localStorage trên web);
/// MaterialApp.locale đọc từ đây. Mặc định theo THỊ TRƯỜNG khi chưa lưu lựa chọn (Phase 14, T16):
/// bản jp ⇒ `ja`, bản vn ⇒ `vi`. [load] ghi đè bằng ngôn ngữ đã lưu.
class LocaleProvider extends ChangeNotifier {
  LocaleProvider({bool? japan}) : _locale = Locale(initialLocaleFor(japan ?? FeatureFlags.isJapan));

  static const supported = <Locale>[Locale('ja'), Locale('vi'), Locale('en'), Locale('zh')];

  static String initialLocaleFor(bool japan) => japan ? 'ja' : 'vi';

  Locale _locale;
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
