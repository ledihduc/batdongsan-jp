/// Lịch hẹn neo vào TIN hay vào PHÒNG — và hệ quả lên giao diện.
///
/// Trước 08/09/2026 `houseId` là `int` bắt buộc. Nhưng phòng trong dự án chưa
/// gắn tin nào thì không có tin để neo (luồng "dựng dự án trước, gắn tin sau"),
/// nên backend trả `house_id: null`. Giữ kiểu cũ nghĩa là mọi nút mở tin sẽ
/// đẩy sang `/house/null` — trang lỗi.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/viewing_appointment_model.dart';

Map<String, dynamic> _goc({
  Object? houseId = 11,
  Object? roomId,
  String loai = 'xem',
}) => {
  'id': 1,
  'house_id': houseId,
  'room_id': roomId,
  'loai': loai,
  'guest_id': 5,
  'booking_date': '2026-10-01',
  'booking_time': '09:00-10:00',
  'created_at': '2026-09-08T00:00:00',
};

void main() {
  test('lịch neo vào TIN → mở được trang tin', () {
    final a = ViewingAppointmentModel.fromMap(_goc(roomId: 3));
    expect(a.houseId, 11);
    expect(a.roomId, 3);
    expect(a.moDuocTin, isTrue);
  });

  test('lịch neo THẲNG vào phòng → KHÔNG mở trang tin', () {
    final a = ViewingAppointmentModel.fromMap(_goc(houseId: null, roomId: 3));
    expect(a.houseId, isNull);
    expect(a.roomId, 3);
    // Cái này gác nút "Xem tin" và nút "Đánh giá" — cả hai đều cần một tin có
    // thật để mở.
    expect(a.moDuocTin, isFalse);
  });

  test('API cũ chưa trả "loai" → mặc định là lịch XEM', () {
    final m = _goc()..remove('loai');
    expect(ViewingAppointmentModel.fromMap(m).loai, 'xem');
    expect(ViewingAppointmentModel.fromMap(m).laHenChot, isFalse);
  });

  test('lịch hẹn CHỐT phân biệt được với lịch xem', () {
    final a = ViewingAppointmentModel.fromMap(_goc(loai: 'chot'));
    expect(a.laHenChot, isTrue);
  });

  test('gửi lên backend: bỏ HẲN khoá rỗng, không gửi null', () {
    // Gửi `house_id: null` thì backend đọc thành "có khoá, giá trị null" và
    // phải phân biệt thêm một trạng thái nữa. Vắng mặt là rõ nhất.
    final m = ViewingAppointmentModel(
      roomId: 3,
      guestId: 5,
      bookingDate: '2026-10-01',
      bookingTime: '09:00-10:00',
      message: '',
    ).toMap();
    expect(m.containsKey('house_id'), isFalse);
    expect(m['room_id'], 3);
    expect(m['loai'], 'xem');
  });
}
