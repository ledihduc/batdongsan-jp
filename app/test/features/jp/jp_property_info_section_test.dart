/// Widget tests for [JpPropertyInfoSection].
library;

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/jp/jp_property_info.dart';
import 'package:house_booking/data/models/jp/jp_station.dart';
import 'package:house_booking/features/guest/listing/jp_property_info_section.dart';
import 'package:house_booking/l10n/app_localizations.dart';

import '../../helpers/pump_app.dart';

void main() {
  const info = JpPropertyInfo(
    id: 1,
    layout: '1LDK',
    floorAreaM2: 45.5,
    structure: JpStructure.rc,
    buildingYear: 2015,
    floorNumber: 8,
    totalFloors: 15,
    orientation: JpOrientation.s,
    availableFrom: '2026-12-01',
  );

  final transit = [
    JpTransitAccess(
      id: 1,
      listingId: 9001,
      station: const JpStation(
        id: 101,
        name: '渋谷',
        nameKana: 'しぶや',
        lineName: '山手線',
        lineId: 11,
      ),
      walkMinutes: 8,
    ),
  ];

  testWidgets('renders layout chip', (tester) async {
    await pumpApp(
      tester,
      JpPropertyInfoSection(propertyInfo: info, transitAccesses: transit),
    );
    await tester.pump();
    expect(find.textContaining('1LDK'), findsAtLeastNWidgets(1));
  });

  testWidgets('renders floor area', (tester) async {
    await pumpApp(
      tester,
      JpPropertyInfoSection(propertyInfo: info),
    );
    await tester.pump();
    expect(find.textContaining('45.5'), findsAtLeastNWidgets(1));
  });

  testWidgets('renders transit station name when provided', (tester) async {
    await pumpApp(
      tester,
      JpPropertyInfoSection(propertyInfo: info, transitAccesses: transit),
    );
    await tester.pump();
    expect(find.textContaining('渋谷'), findsAtLeastNWidgets(1));
    // pumpApp ghim locale vi; nhãn đi bộ theo ngôn ngữ giao diện (Phase 12).
    final l = await AppLocalizations.delegate.load(const Locale('vi'));
    expect(find.textContaining(l.jpWalkMinutes(8)), findsAtLeastNWidgets(1));
  });

  testWidgets('renders without transit when list is empty', (tester) async {
    await pumpApp(
      tester,
      JpPropertyInfoSection(propertyInfo: info),
    );
    await tester.pump();
    // Transit section header (交通アクセス) should NOT appear
    final l = await AppLocalizations.delegate.load(const Locale('vi'));
    expect(find.text(l.jpTransitTitle), findsNothing);
  });

  testWidgets('renders available date', (tester) async {
    await pumpApp(
      tester,
      JpPropertyInfoSection(propertyInfo: info),
    );
    await tester.pump();
    expect(find.textContaining('2026-12-01'), findsAtLeastNWidgets(1));
  });
}
