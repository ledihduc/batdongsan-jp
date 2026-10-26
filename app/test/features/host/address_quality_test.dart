import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/host/post/address_quality.dart';

/// Vì sao có tệp này: màn đăng tin trước đây KHÔNG có test nào. Quy tắc dưới
/// đây quyết định có nhắc chủ nhà bổ sung số nhà hay không — sai thì tin đăng
/// chỉ có "Phường X, Tỉnh Y" và người mua không tìm ra nhà.
///
/// Các chuỗi dùng ở đây lấy theo dạng thật mà Nominatim self-host trả về.
void main() {
  group('laDiaChiTho — địa chỉ ĐỦ chi tiết (không nhắc)', () {
    test('có số nhà ở đầu', () {
      expect(laDiaChiTho('63 Lý Tự Trọng, Phường Bến Nghé, TP.HCM'), isFalse);
    });

    test('có danh từ chỉ đường dù không có số nhà', () {
      expect(laDiaChiTho('Đường Nguyễn Huệ, Phường Bến Nghé, TP.HCM'), isFalse);
      expect(laDiaChiTho('Hẻm 220, Phường 5, Quận 3'), isFalse);
      expect(laDiaChiTho('Quốc lộ 1A, Xã Bình Chánh'), isFalse);
    });

    test('không phân biệt hoa thường', () {
      expect(laDiaChiTho('ĐƯỜNG TRẦN PHÚ, Phường 4'), isFalse);
    });
  });

  group('laDiaChiTho — địa chỉ THÔ (phải nhắc bổ sung)', () {
    test('chỉ tới phường/tỉnh — ca vùng ven đã gặp thật', () {
      expect(laDiaChiTho('Phường Long Tuyền, Thành phố Cần Thơ'), isTrue);
    });

    test('chỉ có xã và tỉnh', () {
      expect(laDiaChiTho('Xã Trà Liên, Thành phố Đà Nẵng, Việt Nam'), isTrue);
    });

    test('chuỗi rỗng coi như thô', () {
      expect(laDiaChiTho(''), isTrue);
      expect(laDiaChiTho('   '), isTrue);
    });
  });
}
