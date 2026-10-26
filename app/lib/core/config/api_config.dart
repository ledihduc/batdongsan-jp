import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    // Deploy: cho phép override qua --dart-define; web mặc định same-origin ('')
    // để API gọi theo đúng origin đang phục vụ trang (IP/domain, http/https).
    const defined = String.fromEnvironment('API_BASE_URL');
    if (defined.isNotEmpty) return defined;
    if (kIsWeb) {
      return Uri.base.origin; // same-origin tuyệt đối (IP/domain, http/https)
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3003';
      default:
        return 'http://localhost:3003';
    }
  }
}
