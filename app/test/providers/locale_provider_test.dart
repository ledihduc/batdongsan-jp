/// `LocaleProvider`: ngôn ngữ mặc định theo thị trường — jp ⇒ ja, vn ⇒ vi (Phase 14, T16).
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/providers/locale_provider.dart';

void main() {
  test('locale_provider_default_japan_is_ja', () {
    // Arrange + Act
    final p = LocaleProvider(japan: true);
    // Assert
    expect(p.locale.languageCode, 'ja');
  });

  test('locale_provider_default_vietnam_is_vi', () {
    // Arrange + Act
    final p = LocaleProvider(japan: false);
    // Assert
    expect(p.locale.languageCode, 'vi');
  });

  test('locale_provider_unsupported_code_keeps_locale', () {
    // Arrange
    final p = LocaleProvider(japan: false);
    // Act
    p.setLocale('fr');
    // Assert
    expect(p.locale.languageCode, 'vi');
  });

  test('locale_provider_initial_locale_for_maps_market', () {
    // Act + Assert
    expect(LocaleProvider.initialLocaleFor(true), 'ja');
    expect(LocaleProvider.initialLocaleFor(false), 'vi');
  });

  test('locale_provider_load_saved_language_overrides_market_default', () async {
    // Arrange — khách đã chọn English trước đó (QA P14 F3)
    FlutterSecureStorage.setMockInitialValues({'app_lang': 'en'});
    final p = LocaleProvider(japan: false);
    // Act
    await p.load();
    // Assert
    expect(p.locale.languageCode, 'en');
  });

  test('locale_provider_load_nothing_saved_keeps_market_default', () async {
    // Arrange
    FlutterSecureStorage.setMockInitialValues({});
    final p = LocaleProvider(japan: true);
    // Act
    await p.load();
    // Assert
    expect(p.locale.languageCode, 'ja');
  });

  test('locale_provider_load_invalid_saved_code_keeps_market_default', () async {
    // Arrange
    FlutterSecureStorage.setMockInitialValues({'app_lang': 'fr'});
    final p = LocaleProvider(japan: false);
    // Act
    await p.load();
    // Assert
    expect(p.locale.languageCode, 'vi');
  });
}
