import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/core/config/env.dart';

/// URL tile bản đồ — khoá lại đúng lỗi làm lớp quy hoạch không hiện trên iPhone
/// thật: `martinTileUrl` từng hardcode `http://localhost:3001` (iOS) và
/// `http://10.0.2.2:3001` (Android). Trên máy thật `localhost` là chính cái
/// điện thoại đó; còn `http://` thì bị iOS chặn thẳng (App Transport Security),
/// nên lớp thửa đất im lặng không hiện mà không báo lỗi gì.
void main() {
  group('martinTileUrl (lớp thửa đất)', () {
    test('gốc API thật → đi CÙNG GỐC, giữ https', () {
      // Máy chủ phục vụ app mới là nơi có proxy /martin.
      expect(
        Env.martinTileUrlTu('https://digilab.ddns.net'),
        'https://digilab.ddns.net/martin/planning.parcels/{z}/{x}/{y}',
      );
    });

    test('KHÔNG còn trỏ localhost/10.0.2.2 khi gốc API là domain thật', () {
      for (final base in ['https://digilab.ddns.net', 'https://ancu365.ddns.net']) {
        final url = Env.martinTileUrlTu(base);
        expect(url, isNot(contains('localhost')));
        expect(url, isNot(contains('10.0.2.2')));
        expect(url, isNot(startsWith('http://')),
            reason: 'iOS chặn cleartext http');
      }
    });

    test('dev cục bộ vẫn giữ cổng 3001 (không có nginx gắn tiền tố /martin)',
        () {
      expect(Env.martinTileUrlTu('http://localhost:3003'),
          'http://localhost:3001/planning.parcels/{z}/{x}/{y}');
      expect(Env.martinTileUrlTu('http://10.0.2.2:3003'),
          'http://10.0.2.2:3001/planning.parcels/{z}/{x}/{y}');
    });
  });

  group('planningRasterTileUrl (ảnh quy hoạch)', () {
    test('cùng gốc với API và giữ nguyên slug tỉnh', () {
      expect(
        Env.planningRasterTileUrl('bac-ninh-2030'),
        '${Env.apiBaseUrl}/planning-tiles/bac-ninh-2030/{z}/{x}/{y}.png'
        '?v=${Env.planningRasterTileRevision}',
      );
    });
  });

  group('baseMapTileUrl (nền bản đồ)', () {
    test('đi qua backend, không gọi thẳng tile.openstreetmap.org', () {
      expect(Env.baseMapTileUrl, isNot(contains('openstreetmap.org')));
      expect(Env.baseMapTileUrl, startsWith(Env.apiBaseUrl));
    });
  });
}
