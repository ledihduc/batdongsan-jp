import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/dat_phong_api.dart';
import 'package:house_booking/features/guest/booking/room_booking_screen.dart';

import '../../../helpers/pump_app.dart';

/// ĐẶT PHÒNG THEO HẠNG — tin ngắn hạn của sale neo vào hạng phòng (0130).
///
/// Điều phải giữ:
///   * màn đặt hỏi ĐÚNG bộ endpoint của TIN (`/tin/{id}/…`), không hỏi bộ của
///     phòng: app không biết phòng nào vừa có người giữ;
///   * KHÔNG hiện mã phòng — lễ tân mới gán số lúc nhận, in "LT-102" lên đây
///     là hứa một con số app không giữ được;
///   * nói rõ hạng còn mấy phòng cùng loại;
///   * chốt đơn gửi qua `datTheoTin` kèm số khách, KHÔNG gửi `room_id`.
class _ApiHang extends DatPhongApi {
  _ApiHang({this.soPhong = 3, this.conTrong = true});

  final int soPhong;
  final bool conTrong;

  var hoiPhong = false;
  final baoGiaTin = <(int, String)>[];
  Map<String, dynamic>? daDat;

  // Bộ endpoint của PHÒNG: gọi tới là sai luồng → đánh dấu để test bắt.
  @override
  Future<ThongTinDatPhong> thongTinDat(int roomId, {int? houseId}) async {
    hoiPhong = true;
    throw StateError('tin theo hạng không được hỏi endpoint của phòng');
  }

  @override
  Future<ThongTinDatPhong> thongTinDatTheoTin(int houseId) async =>
      ThongTinDatPhong.fromMap({
        'phong': {
          'room_id': 49,
          'ma': 'LT-102',
          'hang': 'Deluxe hướng biển',
          'toa': 'Vua Nhà Homestay Lạch Tray',
          'dien_tich': 25,
          'suc_chua': 2,
          'dia_chi': '12 Lạch Tray, Ngô Quyền, Tp Hải Phòng',
          'house_id': houseId,
        },
        'goi': const [
          {
            'booking_mode': 'theo_gio',
            'label': 'Theo giờ',
            'unit': 'giờ',
            'unit_price': 80000,
            'free_cancel_hours': 1,
          },
        ],
        'sale': const {
          'id': 58,
          'ten': 'Hoàng Minh Tuấn',
          'sdt': '•••••••456',
          'so_don_xong': 12,
        },
        'nhan_dat': true,
        'gio_tra': 12,
        'hang_phong': {
          'id': 5,
          'ten': 'Deluxe hướng biển',
          'suc_chua': 2,
          'giuong': 'King 1m8',
          'so_phong': soPhong,
          'gia_qua_dem': 350000,
        },
        'dat_theo_hang': true,
        'con_trong_bay_gio': conTrong,
        'chinh_sach': const ['Thanh toán tại nơi lưu trú khi nhận phòng.'],
      });

  @override
  Future<List<KhoangBan>> lichBanTheoTin(
    int houseId,
    DateTime tuNgay, {
    int soNgay = 14,
  }) async => const [];

  @override
  Future<BaoGiaPhong> baoGiaTheoTin(
    int houseId,
    String hinhThuc,
    DateTime nhan,
    DateTime tra,
  ) async {
    baoGiaTin.add((houseId, hinhThuc));
    return BaoGiaPhong.fromMap({
      // Server trả room_id của phòng đại diện; app KHÔNG dùng nó để đặt.
      'room_id': 49,
      'booking_mode': hinhThuc,
      'check_in_at': '${nhan.toIso8601String().split('.').first}+07:00',
      'check_out_at': '${tra.toIso8601String().split('.').first}+07:00',
      'quote_token': 'gia-v1',
      'quantity': 2,
      'unit': 'giờ',
      'unit_price': 80000,
      'fees': 0,
      'total_amount': 160000,
    });
  }

  @override
  Future<int> datTheoTin({
    required int houseId,
    required BaoGiaPhong baoGia,
    required String ten,
    required String sdt,
    required int soKhach,
    String ghiChu = '',
  }) async {
    daDat = {
      'house_id': houseId,
      'ma_bao_gia': baoGia.maBaoGia,
      'ten': ten,
      'sdt': sdt,
      'so_khach': soKhach,
    };
    return 7;
  }

  @override
  Future<int> datPhong({
    required BaoGiaPhong baoGia,
    required String ten,
    required String sdt,
    required int soKhach,
    String ghiChu = '',
    int? houseId,
  }) async => throw StateError('tin theo hạng phải đặt qua datTheoTin');

  @override
  Future<PhieuDatPhong> phieu(int id) async => PhieuDatPhong.fromMap({
    'id': id,
    'ma': 'AC-260923-AABBCCDDEE',
    'trang_thai': 'pending',
    'hinh_thuc': 'theo_gio',
    'nhan_luc': '2030-01-15T16:00:00+07:00',
    'tra_luc': '2030-01-15T18:00:00+07:00',
    'so_luong': 2,
    'don_vi': 'giờ',
    'don_gia': 80000,
    'tong': 160000,
    'so_khach': 2,
    'ten_khach': 'Lê Tuấn Anh',
    'sdt_khach': '0918234889',
    'phong': const {
      'room_id': 49,
      'ma': 'LT-102',
      'hang': 'Deluxe hướng biển',
      'toa': 'Vua Nhà Homestay Lạch Tray',
    },
    'diem_den': const {'dia_chi': '12 Lạch Tray, Ngô Quyền'},
    'chinh_sach': const <String>[],
  });
}

const _args = RoomBookingArgs(
  roomId: 0,
  roomCode: '',
  buildingName: 'Vua Nhà Homestay Lạch Tray',
  price: 0,
  saleName: '',
  houseId: 321,
  theoHang: true,
);

void _manRong(WidgetTester t) {
  t.view.physicalSize = const Size(1000, 4200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Future<void> _cho(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<_ApiHang> _mo(
  WidgetTester t, {
  int soPhong = 3,
  bool conTrong = true,
}) async {
  _manRong(t);
  final api = _ApiHang(soPhong: soPhong, conTrong: conTrong);
  await pumpApp(
    t,
    RoomBookingScreen(
      args: _args,
      api: api,
      homNay: DateTime(2026, 9, 15, 8),
    ),
    auth: SignedInAuthProvider(),
  );
  await _cho(t);
  return api;
}

Future<void> _bam(WidgetTester t, String khoa) async {
  await t.tap(find.byKey(Key(khoa)));
  await _cho(t);
}

void main() {
  testWidgets('hỏi endpoint của TIN, không hỏi endpoint của phòng', (t) async {
    final api = await _mo(t);
    expect(api.hoiPhong, isFalse);
    expect(find.text('Deluxe hướng biển'), findsWidgets);
  });

  testWidgets('không hiện mã phòng, nói rõ còn mấy phòng cùng hạng', (t) async {
    await _mo(t);
    expect(find.textContaining('LT-102'), findsNothing);
    expect(find.text('Hạng phòng · 3 phòng cùng loại'), findsOneWidget);
    expect(find.textContaining('xếp khi nhận phòng'), findsOneWidget);
  });

  testWidgets('hạng đang kín hôm nay vẫn cho chọn ngày khác', (t) async {
    await _mo(t, conTrong: false);
    expect(find.textContaining('đang kín trong hôm nay'), findsOneWidget);
  });

  testWidgets('chốt đơn đi qua datTheoTin kèm tin và số khách', (t) async {
    final api = await _mo(t);
    await _bam(t, 'dat-phong-gio-16:00');
    expect(api.baoGiaTin.single.$1, 321);

    await t.enterText(find.byKey(const Key('dat-phong-ten')), 'Lê Tuấn Anh');
    await t.enterText(find.byKey(const Key('dat-phong-sdt')), '0918234889');
    await _bam(t, 'dat-phong-xac-nhan');
    await t.pump(const Duration(milliseconds: 400));

    expect(api.daDat, {
      'house_id': 321,
      'ma_bao_gia': 'gia-v1',
      'ten': 'Lê Tuấn Anh',
      'sdt': '0918234889',
      'so_khach': 2,
    });
  });
}
