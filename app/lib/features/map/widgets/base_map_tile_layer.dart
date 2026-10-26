import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

import 'package:house_booking/core/config/env.dart';

/// Lớp tile dùng chung cho MỌI bản đồ trong app.
///
/// ## Vì sao có tệp này
///
/// Trước đây 6 chỗ vẽ [TileLayer] tự khai báo riêng, mỗi chỗ lệch một ít
/// (`userAgentPackageName` khác nhau, chỗ có `errorTileCallback` chỗ không) và
/// KHÔNG chỗ nào đặt `tileProvider`. Mặc định của flutter_map 7.0.2 là
/// `NetworkTileProvider` — thứ mà chính nó log cảnh báo khuyên đừng dùng trên
/// web (`tile_layer.dart:287`).
///
/// Vấn đề của mặc định đó: nó KHÔNG huỷ được request tile đã trôi khỏi màn.
/// Kéo bản đồ nhanh một cái là hàng chục ô cũ vẫn đang tải, chen chỗ những ô
/// đang thật sự cần trên cùng một kết nối HTTP/2 — trình duyệt chỉ cho một số
/// request song song hữu hạn. Kết quả đúng như cảm giác người dùng mô tả: kéo
/// tới đâu xám tới đó, dừng lại vài giây nền mới đuổi kịp.
///
/// [CancellableNetworkTileProvider] dùng dio, huỷ được request giữa chừng, nên
/// ô vừa trôi khỏi màn nhả chỗ ngay cho ô đang cần.
///
/// ## Cạm bẫy: KHÔNG được dùng chung một instance provider
///
/// [TileLayer] tự gọi `tileProvider.dispose()` khi bị gỡ khỏi cây widget
/// (`tile_layer.dart:463`). Nếu để một provider singleton dùng cho nhiều bản
/// đồ thì bản đồ nào đóng trước sẽ đóng luôn client dio của tất cả những bản
/// đồ còn lại — biểu hiện là bản đồ thứ hai đột nhiên trắng nền mà không có
/// lỗi nào. Vì vậy MỖI lần gọi hàm dưới đây phải tạo một provider mới.

/// Nền bản đồ (OpenStreetMap qua proxy backend — xem `basemap_tile_proxy.py`).
TileLayer lopTileNen() => TileLayer(
      urlTemplate: Env.baseMapTileUrl,
      userAgentPackageName: 'com.ancu365.app',
      maxNativeZoom: 19,
      tileProvider: _providerMoi(),
      // Ô thiếu (biển khơi, ngoài vùng phủ của mirror) trả 404 — để trống chứ
      // đừng vẽ ô lỗi hay spam console.
      errorTileCallback: (_, __, ___) {},
    );

/// Lớp phủ raster quy hoạch theo tỉnh (proxy CDN Guland — `guland_tile_proxy.py`).
TileLayer lopTileQuyHoach(String urlTemplate) => TileLayer(
      urlTemplate: urlTemplate,
      userAgentPackageName: 'com.ancu365.app',
      minNativeZoom: 8,
      maxNativeZoom: 17,
      tileProvider: _providerMoi(),
      errorTileCallback: (_, __, ___) {},
    );

/// Nguồn tạo provider. Là biến để WIDGET TEST thay được bằng bản không đụng
/// vào mạng — xem `test/helpers/pump_app.dart`.
///
/// Vì sao phải thay được: dio (thứ [CancellableNetworkTileProvider] dùng để
/// huỷ request) tạo một `Timer` cho mỗi request. Trong widget test, thời gian
/// là giả và request không bao giờ hoàn tất, nên timer đó còn treo ở lúc kết
/// thúc test → `flutter_test` ném "Pending timers" và MỌI test có bản đồ đều
/// đỏ, dù sản phẩm không có lỗi gì.
@visibleForTesting
TileProvider Function() taoProviderTile = _providerMang;

/// Instance MỚI mỗi lần — xem phần "Cạm bẫy" ở trên.
TileProvider _providerMoi() => taoProviderTile();

TileProvider _providerMang() => CancellableNetworkTileProvider(
      // Ô 404 là chuyện thường (biển, rìa vùng phủ). Ném lỗi ra sẽ làm nhiễu
      // log tới mức che mất sự cố thật.
      silenceExceptions: true,
    );
