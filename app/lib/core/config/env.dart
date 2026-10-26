import 'package:flutter/foundation.dart';

/// Cấu hình môi trường — đọc từ `--dart-define` khi build,
/// fallback về giá trị dev mặc định.
class Env {
  Env._();

  /// Base URL của backend FastAPI.
  /// Android emulator: 10.0.2.2 map sang localhost của host.
  /// iOS simulator / Web: localhost.
  static String get apiBaseUrl {
    const defined = String.fromEnvironment('API_BASE_URL');
    if (defined.isNotEmpty) return defined;
    if (kIsWeb) return Uri.base.origin; // same-origin tuyệt đối (deploy)
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3003';
      default:
        return 'http://localhost:3003';
    }
  }

  /// Gốc URL của SITE CÔNG KHAI (Next.js SSR) — nơi link chia sẻ trỏ tới.
  ///
  /// Không dùng origin của app: app là SPA Flutter, link dán vào Zalo/Facebook
  /// sẽ không có thẻ preview và Google không đọc được. Site SSR thì có cả hai.
  static String get publicSiteUrl {
    const defined = String.fromEnvironment('PUBLIC_SITE_URL');
    return defined.isNotEmpty ? defined : 'https://ancu365.ddns.net';
  }

  /// Đường dẫn TRANG CÁ NHÂN của một người bán, dùng để chia sẻ cho khách.
  ///
  /// Trỏ vào CHÍNH app (route `/sale/:id`), không còn trỏ sang site SSR: site
  /// đó đã gỡ ngày 03/09/2026 nên mọi link chia sẻ trước đây là link chết.
  ///
  /// Đánh đổi có ý thức: link mở được ở mọi trình duyệt nhưng KHÔNG có thẻ
  /// preview khi dán vào Zalo/Facebook và Google không index — hai thứ đó cần
  /// một trang render phía máy chủ.
  ///
  /// Phần `-{slug-tên}` chỉ để link đọc được; router chỉ lấy số ở đầu.
  static String brokerPublicUrl(int userId, String name) =>
      '$apiBaseUrl/sale/$userId-${_slugify(name)}';

  /// Đường dẫn tin đăng trên site công khai (khớp `duongDanTin`).
  static String housePublicUrl(int houseId, String title) =>
      '$publicSiteUrl/tin/$houseId-${_slugify(title)}';

  /// Bỏ dấu tiếng Việt + gạch nối — PHẢI khớp `slugify()` của web, nếu lệch thì
  /// web sẽ redirect về canonical (vẫn mở được, chỉ tốn một chặng).
  static String _slugify(String input) {
    const from =
        'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ';
    const to =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    var r = input.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      r = r.split(from[i]).join(to[i]);
    }
    return r
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  /// URL template tile NỀN bản đồ — trỏ về backend, KHÔNG gọi thẳng
  /// `tile.openstreetmap.org`.
  ///
  /// Vì sao: đo 24/08/2026 thấy `tile.openstreetmap.org` KHÔNG phân giải DNS
  /// được (trình duyệt: ERR_NAME_NOT_RESOLVED; container: Name or service not
  /// known) → mọi bản đồ trong app chỉ còn khung xám + ghim, không có nền.
  /// Backend proxy sang mirror còn sống và cache lại, nên bản đồ không còn phụ
  /// thuộc DNS/ISP của từng người dùng.
  static String get baseMapTileUrl {
    const defined = String.fromEnvironment('BASEMAP_TILE_URL');
    if (defined.isNotEmpty) return defined;
    return '$apiBaseUrl/api/basemap/{z}/{x}/{y}.png';
  }

  /// URL template cho Martin tile server (MVT) — lớp THỬA ĐẤT của bản đồ quy
  /// hoạch. `{z}/{x}/{y}` sẽ được thay thế bởi vector_map_tiles.
  ///
  /// Suy ra từ [apiBaseUrl] chứ KHÔNG hardcode host theo nền tảng nữa. Bản cũ
  /// trả `http://localhost:3001` cho iOS và `http://10.0.2.2:3001` cho Android
  /// — hai địa chỉ chỉ có nghĩa với máy lập trình và máy ảo. Trên điện thoại
  /// THẬT, `localhost` chính là cái điện thoại đó, nên lớp quy hoạch chưa từng
  /// hiện lên ở bản cài đặt thật. Nặng hơn nữa trên iOS: `http://` bị App
  /// Transport Security chặn thẳng, không phải lỗi mạng mà là hệ điều hành từ
  /// chối.
  ///
  /// Máy chủ phục vụ app đã proxy sẵn `/martin/` sang Martin (nginx prod +
  /// staging), y như cách `/api/basemap` và `/planning-tiles` đang làm — nên
  /// đi chung một gốc là đủ, và tự động đúng giao thức https.
  static String get martinTileUrl {
    const defined = String.fromEnvironment('MARTIN_TILE_URL');
    if (defined.isNotEmpty) return defined;
    if (kIsWeb) {
      return '${Uri.base.origin}/martin/planning.parcels/{z}/{x}/{y}';
    }
    return martinTileUrlTu(apiBaseUrl);
  }

  /// Phần suy luận thuần của [martinTileUrl], tách ra để test được: `Env` đọc
  /// `String.fromEnvironment` lúc BIÊN DỊCH nên không thể đổi gốc API trong
  /// test để kiểm hai nhánh.
  @visibleForTesting
  static String martinTileUrlTu(String apiBase) {
    // Chạy dev với backend ở máy mình: Martin nghe cổng riêng 3001, không có
    // nginx nào đứng trước để gắn tiền tố /martin.
    final host = Uri.tryParse(apiBase)?.host ?? '';
    if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
      return 'http://$host:3001/planning.parcels/{z}/{x}/{y}';
    }
    return '$apiBase/martin/planning.parcels/{z}/{x}/{y}';
  }

  /// Bbox toàn Việt Nam (south,west,north,east) cho overlay/search VN-wide.
  static const String vnBbox = '8.0,102.0,23.5,110.0';

  /// URL template tile raster planning (Guland dataset offline).
  /// {z}/{x}/{y} sẽ thay bởi flutter_map TileLayer.
  /// `tileLayerSlug` ví dụ: 'an-giang-2030'.
  ///
  /// Tile được cache `immutable`, vì vậy phải đổi revision khi nội dung PNG
  /// trên server được xử lý lại; nếu không trình duyệt tiếp tục vẽ bản cũ dù
  /// backend đã restart.
  static const String planningRasterTileRevision = '20260921-wm-clean-2';

  static String planningRasterTileUrl(String tileLayerSlug) {
    return '$apiBaseUrl/planning-tiles/$tileLayerSlug/{z}/{x}/{y}.png'
        '?v=$planningRasterTileRevision';
  }
}
