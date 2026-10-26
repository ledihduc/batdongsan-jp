/// Mock implementation of [IJpStationRepository].
///
/// Contains Tokyo 23-ku station fixture data for dev without BE.
library;

import 'package:house_booking/data/models/jp/jp_station.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_station_repository.dart';

const _fixtures = <JpStation>[
  JpStation(
    id: 101,
    name: '渋谷',
    nameKana: 'しぶや',
    lineName: '山手線',
    lineId: 11,
    prefectureName: '東京都',
    latitude: 35.6580,
    longitude: 139.7016,
  ),
  JpStation(
    id: 102,
    name: '新宿',
    nameKana: 'しんじゅく',
    lineName: '山手線',
    lineId: 11,
    prefectureName: '東京都',
    latitude: 35.6896,
    longitude: 139.7006,
  ),
  JpStation(
    id: 103,
    name: '池袋',
    nameKana: 'いけぶくろ',
    lineName: '山手線',
    lineId: 11,
    prefectureName: '東京都',
    latitude: 35.7295,
    longitude: 139.7109,
  ),
  JpStation(
    id: 104,
    name: '品川',
    nameKana: 'しながわ',
    lineName: '山手線',
    lineId: 11,
    prefectureName: '東京都',
    latitude: 35.6284,
    longitude: 139.7387,
  ),
  JpStation(
    id: 105,
    name: '秋葉原',
    nameKana: 'あきはばら',
    lineName: '山手線',
    lineId: 11,
    prefectureName: '東京都',
    latitude: 35.6984,
    longitude: 139.7731,
  ),
  JpStation(
    id: 201,
    name: '西新宿',
    nameKana: 'にしじゅんく',
    lineName: '丸ノ内線',
    lineId: 12,
    prefectureName: '東京都',
    latitude: 35.6940,
    longitude: 139.6925,
  ),
  JpStation(
    id: 202,
    name: '赤坂',
    nameKana: 'あかさか',
    lineName: '千代田線',
    lineId: 13,
    prefectureName: '東京都',
    latitude: 35.6727,
    longitude: 139.7368,
  ),
];

class MockJpStationRepository implements IJpStationRepository {
  const MockJpStationRepository();

  @override
  Future<List<JpStation>> search(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (query.trim().isEmpty) return List<JpStation>.from(_fixtures);
    final q = query.trim().toLowerCase();
    return _fixtures
        .where((s) =>
            s.name.contains(q) ||
            s.nameKana.contains(q) ||
            s.lineName.contains(q))
        .toList();
  }

  @override
  Future<JpStation> getById(int stationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return _fixtures.firstWhere(
      (s) => s.id == stationId,
      orElse: () => throw Exception('Station $stationId not found'),
    );
  }
}
