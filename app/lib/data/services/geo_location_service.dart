import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

/// Trạng thái khi lấy vị trí — UI dùng để hiện đúng fallback (không ngõ cụt).
enum GeoLocationStatus {
  ok,
  serviceOff, // dịch vụ định vị của thiết bị đang tắt
  denied, // người dùng từ chối (có thể xin lại)
  deniedForever, // từ chối vĩnh viễn → phải mở Cài đặt
  outOfVietnam, // toạ độ ngoài lãnh thổ VN → ngoài phạm vi phục vụ
  /// WEB: trang đang mở qua HTTP (hoặc IP LAN). Trình duyệt CHẶN THẲNG mọi yêu
  /// cầu vị trí ở ngữ cảnh không an toàn — không hộp thoại, không hỏi gì. Rất
  /// dễ bị đọc nhầm thành "người dùng đã từ chối".
  insecureContext,
  error,
}

class GeoLocationResult {
  const GeoLocationResult(this.status, {this.lat, this.lng});
  final GeoLocationStatus status;
  final double? lat;
  final double? lng;

  bool get isOk => status == GeoLocationStatus.ok;
}

/// Bọc geolocator: xin quyền + lấy toạ độ, phân biệt rõ các trạng thái lỗi.
/// Priming (giải thích trước khi xin quyền OS) do UI đảm nhận — service chỉ
/// gọi OS khi được yêu cầu.
class GeoLocationService {
  const GeoLocationService();

  // Bbox VN (south, west, north, east) — khớp settings.vn_bbox_full ở backend.
  static const double _south = 8.0;
  static const double _west = 102.0;
  static const double _north = 23.5;
  static const double _east = 110.0;

  static bool _inVietnam(double lat, double lng) =>
      lat >= _south && lat <= _north && lng >= _west && lng <= _east;

  /// Xin quyền (nếu cần) và trả về vị trí hiện tại.
  /// Gọi sau khi UI đã hiện priming và người dùng đồng ý.
  /// [chinhXacCao] dùng GPS thay vì suy ra từ wifi/cell. Chậm hơn vài giây và
  /// tốn pin hơn, nhưng mức `medium` chỉ cho sai số hàng trăm mét — đủ để chấm
  /// "vị trí của tôi" rơi sang phường bên cạnh.
  Future<GeoLocationResult> getCurrentLocation({
    bool chinhXacCao = false,
  }) async {
    if (kIsWeb && !_secureContext) {
      return const GeoLocationResult(GeoLocationStatus.insecureContext);
    }

    // TRÊN WEB: bỏ hẳn bước hỏi quyền trước, đi thẳng vào lấy toạ độ.
    //
    // Trình duyệt chỉ bật hộp thoại "Cho phép truy cập vị trí?" khi trang THẬT
    // SỰ gọi getCurrentPosition. `requestPermission()` của geolocator trên web
    // chỉ hỏi Permissions API, và khi trạng thái là "chưa quyết định" nó trả về
    // `denied` — nên nhánh kiểm tra bên dưới bỏ cuộc, người dùng chưa từng
    // thấy hộp thoại nào mà đã nhận thông báo "chưa cấp quyền".
    if (!kIsWeb) {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const GeoLocationResult(GeoLocationStatus.serviceOff);
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        return const GeoLocationResult(GeoLocationStatus.deniedForever);
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.unableToDetermine) {
        return const GeoLocationResult(GeoLocationStatus.denied);
      }
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: chinhXacCao
              ? LocationAccuracy.best
              : LocationAccuracy.medium,
          // Định vị GPS nguội cần nhiều thời gian hơn để bắt vệ tinh.
          timeLimit: Duration(seconds: chinhXacCao ? 20 : 12),
        ),
      );
      if (!_inVietnam(pos.latitude, pos.longitude)) {
        return const GeoLocationResult(GeoLocationStatus.outOfVietnam);
      }
      return GeoLocationResult(
        GeoLocationStatus.ok,
        lat: pos.latitude,
        lng: pos.longitude,
      );
    } on PermissionDeniedException {
      // Người dùng bấm "Chặn" ở hộp thoại trình duyệt/hệ điều hành.
      return const GeoLocationResult(GeoLocationStatus.denied);
    } on LocationServiceDisabledException {
      return const GeoLocationResult(GeoLocationStatus.serviceOff);
    } catch (_) {
      // Hết giờ chờ hoặc lỗi khác → thử vị trí biết gần nhất. Trên web không
      // có nên bỏ qua luôn, đừng để một ngoại lệ nữa nuốt mất lỗi gốc.
      if (!kIsWeb) {
        try {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null && _inVietnam(last.latitude, last.longitude)) {
            return GeoLocationResult(
              GeoLocationStatus.ok,
              lat: last.latitude,
              lng: last.longitude,
            );
          }
        } catch (_) {}
      }
      return const GeoLocationResult(GeoLocationStatus.error);
    }
  }

  /// Lấy vị trí CHỈ KHI quyền đã được cấp từ trước — tuyệt đối không hỏi.
  ///
  /// Dùng cho những chỗ vị trí là thứ "có thì tốt": bản đồ xem trước ở trang
  /// chủ chẳng hạn. Bật hộp thoại xin quyền ngay khi người ta vừa mở app, lúc
  /// chưa hiểu mình được lợi gì, là cách nhanh nhất để bị bấm Từ chối — mà từ
  /// chối vĩnh viễn thì những màn THẬT SỰ cần vị trí sau này cũng chết theo.
  /// Trang có đang ở "ngữ cảnh an toàn" không. Trình duyệt chỉ cho lấy vị trí
  /// khi trang chạy trên HTTPS — hoặc localhost, ngoại lệ dành cho lập trình.
  /// Mở bằng IP LAN qua HTTP thì mọi yêu cầu vị trí bị chặn im lặng.
  static bool get _secureContext {
    final u = Uri.base;
    return u.scheme == 'https' ||
        u.host == 'localhost' ||
        u.host == '127.0.0.1';
  }

  Future<GeoLocationResult> currentIfAllowed({bool chinhXacCao = false}) async {
    if (kIsWeb && !_secureContext) {
      return const GeoLocationResult(GeoLocationStatus.insecureContext);
    }
    if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
      return const GeoLocationResult(GeoLocationStatus.serviceOff);
    }
    // Ở đây `checkPermission` DÙNG ĐƯỢC trên cả web: trạng thái "đã cấp" được
    // báo đúng. Chỉ trạng thái "chưa quyết định" mới bị báo nhầm thành denied —
    // và đúng ý ta, chưa quyết định thì không tự hỏi.
    final perm = await Geolocator.checkPermission();
    if (perm != LocationPermission.always &&
        perm != LocationPermission.whileInUse) {
      return const GeoLocationResult(GeoLocationStatus.denied);
    }
    return getCurrentLocation(chinhXacCao: chinhXacCao);
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
