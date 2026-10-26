import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/user_preferences.dart';

/// Quy tắc chọn "thế giới" mở đầu app + tab nào đứng slot 0.
/// Hỏng ở đây là người dùng mở app vào nhầm nửa sản phẩm, hoặc tệ hơn: cài đặt
/// họ tự chọn bị ghi đè và không sửa được.
void main() {
  group('đơn vị thi công → mở vào Thi công', () {
    test('đơn vị chưa tự chọn gì → Thi công (dù giá trị lưu là BĐS)', () {
      expect(
        UserPreferences.resolveWorld(
          theGioiDaLuu: kWorldRealEstate,
          nguoiDungTuChon: false,
          laDonVi: true,
        ),
        kWorldConstruction,
      );
    });

    test('đơn vị mà khảo sát đã ra Thi công → vẫn Thi công', () {
      expect(
        UserPreferences.resolveWorld(
          theGioiDaLuu: kWorldConstruction,
          nguoiDungTuChon: false,
          laDonVi: true,
        ),
        kWorldConstruction,
      );
    });
  });

  group('lựa chọn tường minh của người dùng LUÔN thắng', () {
    test('đơn vị nhưng tự chọn BĐS trong Profile → giữ BĐS', () {
      expect(
        UserPreferences.resolveWorld(
          theGioiDaLuu: kWorldRealEstate,
          nguoiDungTuChon: true,
          laDonVi: true,
        ),
        kWorldRealEstate,
      );
    });

    test('không phải đơn vị nhưng tự chọn Thi công → giữ Thi công', () {
      expect(
        UserPreferences.resolveWorld(
          theGioiDaLuu: kWorldConstruction,
          nguoiDungTuChon: true,
          laDonVi: false,
        ),
        kWorldConstruction,
      );
    });
  });

  group('người dùng thường — giữ nguyên kết quả khảo sát', () {
    test('không phải đơn vị, chưa tự chọn → theo giá trị đã lưu', () {
      expect(
        UserPreferences.resolveWorld(
          theGioiDaLuu: kWorldRealEstate,
          nguoiDungTuChon: false,
          laDonVi: false,
        ),
        kWorldRealEstate,
      );
    });
  });

  group('computeWorld — khảo sát suy ra thế giới', () {
    test('chỉ quan tâm dịch vụ thi công → construction', () {
      expect(UserPreferences.computeWorld(['find_service']),
          kWorldConstruction);
    });
    test('có mục đích BĐS thì BĐS thắng', () {
      expect(UserPreferences.computeWorld(['find_service', 'buy']),
          kWorldRealEstate);
    });
    test('rỗng → BĐS', () {
      expect(UserPreferences.computeWorld([]), kWorldRealEstate);
    });
  });
}
