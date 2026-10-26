/// Centralized Vietnamese error copy — one glossary-aligned message per
/// error type. Prefer these over inline strings so terminology stays
/// consistent across the app.
///
/// See `docs/vietnamese-glossary.md` for the source of truth.
library;

enum AppErrorType {
  network,
  notFound,
  permission,
  validation,
  server,
  unknown,
}

class AppErrorMessages {
  const AppErrorMessages._();

  static const String network =
      'Không có kết nối mạng. Vui lòng kiểm tra và thử lại.';
  static const String notFound = 'Không tìm thấy dữ liệu.';
  static const String permission = 'Bạn không có quyền thực hiện thao tác này.';
  static const String validation = 'Dữ liệu chưa hợp lệ.';
  static const String server = 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';
  static const String unknown = 'Đã có lỗi xảy ra. Vui lòng thử lại.';

  static const String loadListFailed = 'Không tải được danh sách.';
  static const String saveFailed = 'Lưu không thành công.';
  static const String deleteFailed = 'Xóa không thành công.';
  static const String uploadFailed = 'Tải lên không thành công.';
  static const String actionFailed = 'Thao tác không thành công.';

  static String forType(AppErrorType type) {
    switch (type) {
      case AppErrorType.network:
        return network;
      case AppErrorType.notFound:
        return notFound;
      case AppErrorType.permission:
        return permission;
      case AppErrorType.validation:
        return validation;
      case AppErrorType.server:
        return server;
      case AppErrorType.unknown:
        return unknown;
    }
  }
}
