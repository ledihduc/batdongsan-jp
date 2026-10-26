import 'package:house_booking/data/models/house_model.dart';

/// Bốn loại pin trên bản đồ — cùng bộ với [HD.pinColorFor] và chú giải.
/// Dùng chuỗi (không phải enum) để khớp thẳng với `categoryGroup` từ API.
class PinKind {
  static const String stayShort = 'stay_short';
  static const String stayLong = 'stay_long';
  static const String business = 'business';
  static const String sale = 'sale';

  /// Thứ tự hiển thị trong chú giải: nhu cầu tra cứu nhiều nhất lên trước.
  static const List<String> all = [stayShort, stayLong, business, sale];
}

/// Loại của một tin. [isSale] THẮNG nhóm — giống hệt luật màu ở
/// `HD.pinColorFor`, hai chỗ lệch nhau thì lọc theo chú giải sẽ ẩn nhầm pin.
String pinKindFor(HouseModel h) {
  if (h.isForSale) return PinKind.sale;
  switch (h.categoryGroup) {
    case PinKind.stayShort:
      return PinKind.stayShort;
    case PinKind.business:
      return PinKind.business;
    default:
      return PinKind.stayLong;
  }
}
