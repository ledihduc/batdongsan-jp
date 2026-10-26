/// Lọc loại hình theo NHÓM (0074) trong HouseProvider.
///
/// Đây là luật quyết định người đăng tin thấy loại nào ở bước 2 và người tìm
/// nhà thấy chip nào ở trang chủ — sai là hoặc mất loại, hoặc cho chọn loại
/// không thuộc nhóm.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/providers/house_provider.dart';

void main() {
  late HouseProvider p;

  setUp(() {
    p = HouseProvider();
    // Đổ thẳng danh mục vào provider qua API công khai duy nhất có sẵn: gán
    // bằng cách gọi hàm nạp là phải đi mạng, nên test này dựng dữ liệu tối
    // thiểu bằng cách dùng chính cấu trúc map mà backend trả.
    p.debugSetCategories(const [
      {'id': 6, 'name': 'Phòng trọ', 'group_key': 'stay_long'},
      {'id': 1, 'name': 'Căn hộ', 'group_key': 'stay_long'},
      {'id': 3, 'name': 'Villa', 'group_key': 'stay_short'},
      {'id': 12, 'name': 'Văn phòng', 'group_key': 'business'},
      // Danh mục từ backend CŨ (chưa migrate) — không có group_key.
      {'id': 99, 'name': 'Loại cũ'},
    ]);
  });

  test('chưa chọn nhóm → thấy tất cả loại', () {
    expect(p.selectedGroup, '');
    expect(p.categoriesInSelectedGroup.length, 5);
  });

  test('chọn nhóm → chỉ còn loại thuộc nhóm đó', () {
    p.selectGroup('stay_short');
    expect(
      p.categoriesInSelectedGroup.map((c) => c['name']).toList(),
      ['Villa'],
    );
  });

  test('danh mục thiếu group_key được coi là dài hạn, KHÔNG biến mất', () {
    p.selectGroup('stay_long');
    final names = p.categoriesInSelectedGroup.map((c) => c['name']).toList();
    expect(names, containsAll(['Phòng trọ', 'Căn hộ', 'Loại cũ']));
  });

  test('chạm lại nhóm đang chọn = bỏ lọc', () {
    p.selectGroup('business');
    expect(p.selectedGroup, 'business');
    p.selectGroup('business');
    expect(p.selectedGroup, '');
  });

  test('đổi nhóm thì bỏ loại đã chọn (tránh lưu loại lệch nhóm)', () {
    p.selectCategory(3); // Villa (stay_short)
    expect(p.selectedCategoryId, 3);
    p.selectGroup('business');
    expect(p.selectedCategoryId, isNull);
  });
}
