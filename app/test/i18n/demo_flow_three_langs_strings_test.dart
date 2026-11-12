/// Luồng demo không lẫn chữ của ngôn ngữ khác ở ja/vi/en (plan 20261027-1102 Phase 12, AC10, F-3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/widgets/ds_trusted_badge.dart';
import 'package:house_booking/data/models/jp/jp_property_info.dart';
import 'package:house_booking/data/models/jp/jp_rental_terms.dart';
import 'package:house_booking/data/models/jp/jp_station.dart';
import 'package:house_booking/features/guest/listing/jp_property_info_section.dart';
import 'package:house_booking/features/guest/listing/jp_terms_section.dart';
import 'package:house_booking/features/guest/home/advanced_filter_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/house_provider.dart';
import 'package:provider/provider.dart';

final _viDiacritics = RegExp(
  r'[ăâđêôơưàáạảãầấậẩẫằắặẳẵèéẹẻẽềếệểễìíịỉĩòóọỏõồốộổỗờớợởỡùúụủũừứựửữỳýỵỷỹ]',
  caseSensitive: false,
);
final _cjk = RegExp(r'[぀-ヿ一-鿿]');

List<String> _demoValues(AppLocalizations l) => [
      l.shellNavActivity, l.drawerBusinessPremises, l.trustedBadgeSemantic, l.trustedBadgeLabel,
      l.fbPostOptions, l.fbPostCommentCount(3), l.fbPostLike, l.fbPostComposerHint,
      l.hdUnitHour, l.hdUnitNight, l.hdUnitDay, l.routerInvalidHouseId, l.routerPageNotFound,
      l.hmPriceRent, l.hmPriceSale, l.hmPerMonth,
      l.aiChatTitle, l.aiChatErrorTimeout, l.aiChatSuggestionVn1,
      l.aiConfirmTitle, l.aiConfirmWarning, l.aiConfirmDoneViewing, l.aiConfirmLoginRequired,
      // Màn tìm của bản vn (`advanced_filter_screen.dart`) dùng lại key `tf*` có sẵn.
      l.tfDirection, l.tfTrust, l.tfTrustedOnly, l.tfMinRating, l.tfMinQuality, l.tfQualityStar(4),
      l.tfSort, l.tfSortNewest, l.tfSortTrust, l.tfSortRating, l.tfSortPriceAsc, l.tfSortPriceDesc,
      l.tfDirN, l.tfDirS, l.tfDirNW,
    ];

Widget _app(Locale locale, Widget home) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

void main() {
  testWidgets('demo_flow_ja_values_have_no_vietnamese', (t) async {
    // Arrange
    final l = await AppLocalizations.delegate.load(const Locale('ja'));
    // Act + Assert
    for (final v in _demoValues(l)) {
      expect(_viDiacritics.hasMatch(v), isFalse, reason: v);
    }
  });

  testWidgets('demo_flow_en_values_have_no_vietnamese_or_japanese', (t) async {
    // Arrange
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // Act + Assert
    for (final v in _demoValues(l)) {
      expect(_viDiacritics.hasMatch(v), isFalse, reason: v);
      expect(_cjk.hasMatch(v), isFalse, reason: v);
    }
  });

  testWidgets('demo_flow_vi_values_have_no_japanese', (t) async {
    // Arrange
    final l = await AppLocalizations.delegate.load(const Locale('vi'));
    // Act + Assert
    for (final v in _demoValues(l)) {
      expect(_cjk.hasMatch(v), isFalse, reason: v);
    }
  });

  testWidgets('ds_trusted_badge_shows_label_in_each_locale', (t) async {
    for (final code in const ['ja', 'vi', 'en']) {
      // Arrange
      final l = await AppLocalizations.delegate.load(Locale(code));
      // Act
      await t.pumpWidget(_app(Locale(code), const Scaffold(body: DsTrustedBadge())));
      await t.pumpAndSettle();
      // Assert
      expect(find.text(l.trustedBadgeLabel), findsOneWidget, reason: code);
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == l.trustedBadgeSemantic),
        findsOneWidget,
        reason: code,
      );
    }
  });

  testWidgets('advanced_filter_screen_en_shows_no_vietnamese_text', (t) async {
    // Arrange — viewport cao để ListView dựng hết các mục (kể cả hướng nhà, sắp xếp)
    t.view.physicalSize = const Size(900, 6000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // Act
    await t.pumpWidget(ChangeNotifierProvider(
      create: (_) => HouseProvider(),
      child: _app(const Locale('en'), const AdvancedFilterScreen()),
    ));
    await t.pump();
    // Assert
    final texts = t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? w.textSpan?.toPlainText() ?? '').toList();
    expect(texts, contains(l.tfSortPriceAsc));
    expect(texts, contains(l.tfDirNW));
    for (final s in texts) {
      expect(_viDiacritics.hasMatch(s), isFalse, reason: s);
    }
  });

  testWidgets('jp_detail_sections_en_show_no_japanese_ui_text', (t) async {
    // Arrange — màn chi tiết bản jp ở tiếng Anh (checklist mục 12). Dữ liệu tin dùng ASCII để
    // mọi chữ CJK còn lại chắc chắn là chữ giao diện cứng; nhãn ARB `jp_*` có kèm thuật ngữ gốc
    // trong ngoặc (vd "Key money (礼金)") nên bỏ phần trong ngoặc trước khi soát.
    t.view.physicalSize = const Size(900, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    const info = JpPropertyInfo(
      id: 1, layout: '1LDK', floorAreaM2: 30, structure: JpStructure.rc, buildingYear: 2015,
      floorNumber: 3, totalFloors: 10, orientation: JpOrientation.s, availableFrom: '2026-12-01',
    );
    final transit = [
      JpTransitAccess(
        id: 1, listingId: 1, walkMinutes: 5,
        station: const JpStation(id: 1, name: 'Shibuya', nameKana: 'shibuya', lineName: 'Yamanote', lineId: 1),
      ),
    ];
    const terms = JpRentalTerms(
      id: 1, monthlyRent: 150000, shikikinMonths: 1, reikinMonths: 1, brokerageFeeRate: 1.0,
      taxIncluded: true, guaranteeCompanyFee: 30000,
    );
    // Act
    await t.pumpWidget(_app(
      const Locale('en'),
      Scaffold(body: ListView(children: [JpPropertyInfoSection(propertyInfo: info, transitAccesses: transit), const JpTermsSection(terms: terms)])),
    ));
    await t.pump();
    // Assert
    final texts = t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').toList();
    expect(texts.join(' '), contains('5 min walk'));
    for (final s in texts) {
      final ui = s.replaceAll(RegExp(r'\([^)]*\)'), '');
      expect(_cjk.hasMatch(ui), isFalse, reason: s);
    }
  });

  testWidgets('vn_only_price_values_never_read_as_yen_in_any_locale', (t) async {
    // Arrange — key chỉ bản vn dùng (màn tìm vn, hàng giá chi tiết bản vn) mang số VND:
    // ở giao diện ja/zh trước đây ra "50万円"/"8百万円/月" ⇒ đọc thành yên, sai tiền tệ và sai 100× (QA P12 H1).
    final yen = RegExp(r'[円¥]|日元');
    for (final code in const ['ja', 'zh', 'en', 'vi']) {
      final l = await AppLocalizations.delegate.load(Locale(code));
      // Act + Assert
      for (final v in [l.filterPriceValueVnd('50'), l.filterPriceValueShort('50'), l.hdPricePerMonth('8')]) {
        expect(yen.hasMatch(v), isFalse, reason: '$code: $v');
      }
    }
  });

  testWidgets('en_comment_count_uses_singular_for_one', (t) async {
    // Arrange
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    // Act + Assert
    expect(l.fbPostCommentCount(1), '1 comment');
    expect(l.fbPostCommentCount(3), '3 comments');
  });
}
