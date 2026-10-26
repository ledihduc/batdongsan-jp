/// KÊNH BÁN của phòng — giá phải đi kèm ĐƠN VỊ, và bấm phải vào đúng luồng.
///
/// Lỗi đã xảy ra thật: cột giá in cứng "/tháng" cho mọi phòng, còn bấm vào thì
/// luôn mở màn đặt theo ĐÊM. Một căn hộ 5,5tr/tháng thành "3 đêm = 16,5tr".
///
/// Hai bất biến giữ ở đây:
///  1. Đơn vị hiển thị lấy từ KÊNH, không in cứng.
///  2. Chỉ kênh `ngan_han` mới mở màn chọn ngày.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/services/building_public_api.dart';

void main() {
  group('KenhBan — hậu tố giá', () {
    test('theo đêm → "/đêm"', () {
      const k = KenhBan(kenh: 'ngan_han', gia: 350000, donVi: 'dem');
      expect(k.hauTo, '/đêm');
      expect(k.laNganHan, isTrue);
    });

    test('theo tháng → "/tháng"', () {
      const k = KenhBan(kenh: 'dai_han', gia: 5500000, donVi: 'thang');
      expect(k.hauTo, '/tháng');
      expect(k.laNganHan, isFalse);
    });

    test('mặt bằng → "/m²/tháng"', () {
      const k = KenhBan(kenh: 'dai_han', gia: 250000, donVi: 'm2_thang');
      expect(k.hauTo, '/m²/tháng');
    });

    test('BÁN thì KHÔNG có hậu tố — "3 tỷ/tổng" là câu vô nghĩa', () {
      const k = KenhBan(kenh: 'ban', gia: 3000000000, donVi: 'tong');
      expect(k.hauTo, '');
      expect(k.laBan, isTrue);
    });
  });

  group('PhongCongKhai — chọn luồng đặt', () {
    PhongCongKhai phong(List<KenhBan> kenh) => PhongCongKhai(
      id: 1,
      ma: 'P01',
      gia: 5500000,
      sucChua: 2,
      conTrong: true,
      kenh: kenh,
    );

    test('chỉ dài hạn → KHÔNG có kênh theo đêm', () {
      final p = phong(const [
        KenhBan(kenh: 'dai_han', gia: 5500000, donVi: 'thang'),
      ]);
      // Đây chính là cái chặn bug 16,5tr ở phía app.
      expect(p.kenhNganHan, isNull);
    });

    test('bật CẢ HAI → lấy đúng kênh theo đêm, không lấy giá tháng', () {
      final p = phong(const [
        KenhBan(kenh: 'dai_han', gia: 5500000, donVi: 'thang'),
        KenhBan(kenh: 'ngan_han', gia: 400000, donVi: 'dem', toiThieu: 2),
      ]);
      expect(p.kenhNganHan, isNotNull);
      // Giá truyền sang màn đặt phải là 400k/đêm, KHÔNG phải 5,5tr.
      expect(p.kenhNganHan!.gia, 400000);
      expect(p.kenhNganHan!.toiThieu, 2);
    });

    test('chưa cấu hình kênh nào → không mở luồng đặt nào', () {
      expect(phong(const []).kenhNganHan, isNull);
    });
  });

  group('đọc từ API', () {
    test('ánh xạ đủ trường kênh', () {
      final p = PhongCongKhai.fromMap({
        'id': 7,
        'ma': 'P03',
        'gia': 400000,
        'con_trong': true,
        'suc_chua': 2,
        'kenh': [
          {'kenh': 'ngan_han', 'gia': 400000, 'don_vi': 'dem', 'toi_thieu': 2},
          {'kenh': 'dai_han', 'gia': 5500000, 'don_vi': 'thang'},
        ],
      });
      expect(p.kenh.length, 2);
      expect(p.kenh.first.hauTo, '/đêm');
      expect(p.kenh.last.hauTo, '/tháng');
    });

    test('API cũ chưa trả "kenh" → rỗng, không nổ', () {
      final p = PhongCongKhai.fromMap({
        'id': 7,
        'ma': 'P03',
        'gia': 5500000,
        'con_trong': true,
      });
      expect(p.kenh, isEmpty);
      expect(p.kenhNganHan, isNull);
    });
  });
}
