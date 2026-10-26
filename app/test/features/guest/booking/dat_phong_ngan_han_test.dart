import 'package:house_booking/features/guest/review/write_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/su_kien_lich_su.dart';
import 'package:house_booking/data/services/dat_phong_api.dart';
import 'package:house_booking/features/guest/booking/phieu_dat_phong_screen.dart';
import 'package:house_booking/features/guest/booking/room_booking_screen.dart';

import '../../../helpers/pump_app.dart';

/// ĐẶT PHÒNG NGẮN HẠN + PHIẾU ĐẶT PHÒNG.
///
/// Điều phải giữ:
///   * đặt LUÔN, không có bước hẹn xem; muốn hỏi thì nhắn SALE, SĐT sale che
///     cho tới khi đã đặt;
///   * giờ đã có khách bị gạch THEO THỜI LƯỢNG đang chọn — đổi thời lượng làm giờ
///     đang chọn đụng lịch thì bỏ chọn, không gửi mù;
///   * giờ trả tính đúng luật server: theo giờ = nhận + n giờ; qua đêm / theo
///     ngày = 12:00 trưa;
///   * gửi đúng số khách, tên, SĐT, tin đã dẫn khách, mã báo giá; xong mở phiếu;
///   * phòng chưa có sale thì nói trước, không cho bấm đặt;
///   * phiếu: mã + QR, gọi/Zalo đúng số sale; huỷ chỉ khi còn hạn, hỏi lại trước.
class _ApiGia extends DatPhongApi {
  _ApiGia({
    this.ban = const [],
    this.nhanDat = true,
    this.phieuTraVe,
  });

  final List<KhoangBan> ban;
  final bool nhanDat;
  final Map<String, dynamic>? phieuTraVe;

  final baoGiaGoi = <(String, DateTime, DateTime)>[];
  Map<String, dynamic>? daGui;
  String? lyDoHuy;
  var daHuy = false;
  Map<String, dynamic>? daSua;
  final baoGiaDoiGioGoi = <(int, DateTime, DateTime)>[];
  BaoGiaPhong? daDoiGio;

  @override
  Future<List<SuKienLichSu>> lichSu(int id) async => [
    if (daSua != null)
      const SuKienLichSu(
        tieuDe: 'Sửa thông tin',
        chiTiet: 'Số khách: 2 → 1',
        ai: NguoiLam(vai: 'khach', ten: 'Bạn', laBan: true),
      ),
    const SuKienLichSu(
      tieuDe: 'Xác nhận phòng',
      tong: 'xac_nhan',
      ai: NguoiLam(vai: 'sale', ten: 'Sale Hoàng Minh Tuấn'),
    ),
    const SuKienLichSu(
      tieuDe: 'Đặt phòng',
      tong: 'dat',
      chiTiet: 'Theo giờ · 16:00 15/01 → 18:00 15/01',
      ai: NguoiLam(vai: 'khach', ten: 'Bạn', laBan: true),
    ),
  ];

  @override
  Future<PhieuDatPhong> suaThongTin(
    int id, {
    String? ten,
    String? sdt,
    int? soKhach,
    String? ghiChu,
  }) async {
    daSua = {
      if (ten != null) 'ten': ten,
      if (sdt != null) 'sdt': sdt,
      if (soKhach != null) 'so_khach': soKhach,
      if (ghiChu != null) 'ghi_chu': ghiChu,
    };
    return PhieuDatPhong.fromMap({..._phieu(), 'so_khach': soKhach ?? 2});
  }

  @override
  Future<BaoGiaPhong> baoGiaDoiGio(
    int id,
    String hinhThuc,
    DateTime nhan,
    DateTime tra,
  ) async {
    baoGiaDoiGioGoi.add((id, nhan, tra));
    return baoGia(49, hinhThuc, nhan, tra);
  }

  @override
  Future<PhieuDatPhong> doiGio(int id, BaoGiaPhong baoGia) async {
    daDoiGio = baoGia;
    return PhieuDatPhong.fromMap({
      ..._phieu(),
      'nhan_luc': baoGia.nhanIso,
      'tra_luc': baoGia.traIso,
    });
  }

  @override
  Future<ThongTinDatPhong> thongTinDat(int roomId, {int? houseId}) async =>
      ThongTinDatPhong.fromMap({
        'phong': {
          'room_id': roomId,
          'ma': 'LT-102',
          'hang': 'Deluxe giường đôi',
          'toa': 'Vua Nhà Homestay Lạch Tray',
          'dien_tich': 25,
          'suc_chua': 2,
          'dia_chi': '12 Lạch Tray, Ngô Quyền, Tp Hải Phòng',
          'house_id': houseId,
        },
        'goi': [
          for (final (ma, nhan, dv, gia) in const [
            ('theo_gio', 'Theo giờ', 'giờ', 70000),
            ('qua_dem', 'Qua đêm', 'đêm', 380000),
            ('theo_ngay', 'Theo ngày', 'ngày', 480000),
          ])
            {
              'booking_mode': ma,
              'label': nhan,
              'unit': dv,
              'unit_price': gia,
              'free_cancel_hours': 1,
            },
        ],
        'sale': nhanDat
            ? {
                'id': 58,
                'ten': 'Hoàng Minh Tuấn',
                'sdt': '•••••••456',
                'so_don_xong': 12,
                'khu_vuc': 'Ngô Quyền',
              }
            : null,
        'nhan_dat': nhanDat,
        'gio_tra': 12,
        'chinh_sach': ['Thanh toán tại nơi lưu trú khi nhận phòng.'],
      });

  @override
  Future<List<KhoangBan>> lichBan(
    int roomId,
    DateTime tuNgay, {
    int soNgay = 14,
  }) async => ban;

  @override
  Future<BaoGiaPhong> baoGia(
    int roomId,
    String hinhThuc,
    DateTime nhan,
    DateTime tra,
  ) async {
    baoGiaGoi.add((hinhThuc, nhan, tra));
    return BaoGiaPhong.fromMap({
      'room_id': roomId,
      'booking_mode': hinhThuc,
      'check_in_at': '${nhan.toIso8601String().split('.').first}+07:00',
      'check_out_at': '${tra.toIso8601String().split('.').first}+07:00',
      'quote_token': 'gia-v1',
      'quantity': 2,
      'unit': 'giờ',
      'unit_price': 70000,
      'fees': 0,
      'total_amount': 140000,
      'free_cancel_until': '2026-09-15T15:00:00+07:00',
    });
  }

  @override
  Future<int> datPhong({
    required BaoGiaPhong baoGia,
    required String ten,
    required String sdt,
    required int soKhach,
    String ghiChu = '',
    int? houseId,
  }) async {
    daGui = {
      'ma_bao_gia': baoGia.maBaoGia,
      'ten': ten,
      'sdt': sdt,
      'so_khach': soKhach,
      'house_id': houseId,
    };
    return 7;
  }

  @override
  Future<PhieuDatPhong> phieu(int id) async => PhieuDatPhong.fromMap(
    daHuy ? _phieu(trangThai: 'cancelled', huyDuoc: false) : (phieuTraVe ?? _phieu()),
  );

  @override
  Future<void> huy(int id, {String lyDo = ''}) async {
    lyDoHuy = lyDo;
    daHuy = true;
  }
}

Map<String, dynamic> _phieu({String trangThai = 'pending', bool huyDuoc = true}) => {
  'id': 7,
  'ma': 'AC-260915-AABBCCDDEE',
  'trang_thai': trangThai,
  'hinh_thuc': 'theo_gio',
  // Năm xa: màn đổi giờ dùng giờ thật của máy, giờ quá khứ bị gạch hết.
  'nhan_luc': '2030-01-15T16:00:00+07:00',
  'tra_luc': '2030-01-15T18:00:00+07:00',
  'so_luong': 2,
  'don_vi': 'giờ',
  'don_gia': 70000,
  'tong': 140000,
  'huy_mien_phi_den': '2030-01-15T15:00:00+07:00',
  'huy_duoc': huyDuoc,
  'so_khach': 2,
  'ten_khach': 'Lê Tuấn Anh',
  'sdt_khach': '0918234889',
  'phong': {
    'room_id': 49,
    'ma': 'LT-102',
    'hang': 'Deluxe giường đôi',
    'toa': 'Vua Nhà Homestay Lạch Tray',
    'dien_tich': 25,
  },
  'sale': {'id': 58, 'ten': 'Hoàng Minh Tuấn', 'sdt': '0988123456'},
  'diem_den': {'dia_chi': '12 Lạch Tray, Ngô Quyền', 'lat': 20.84, 'lng': 106.68},
  'chinh_sach': ['Mang CCCD/hộ chiếu của người nhận phòng.'],
};

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

final _bayGio = DateTime(2026, 9, 15, 8);

Future<_ApiGia> _moDat(WidgetTester t, {_ApiGia? api}) async {
  _manRong(t);
  final a = api ?? _ApiGia();
  await pumpApp(
    t,
    RoomBookingScreen(
      api: a,
      homNay: _bayGio,
      args: const RoomBookingArgs(
        roomId: 49,
        roomCode: 'LT-102',
        buildingName: 'Lạch Tray',
        price: 0,
        saleName: '',
        houseId: 43,
      ),
    ),
    auth: SignedInAuthProvider(),
  );
  await _cho(t);
  return a;
}

Future<void> _bam(WidgetTester t, String khoa) async {
  await t.tap(find.byKey(Key(khoa)));
  await _cho(t);
}

void main() {
  group('Đặt phòng', () {
    testWidgets('dựng đủ phòng, ba gói, sale che SĐT; chưa chọn giờ thì không gửi',
        (t) async {
      final api = await _moDat(t);
      expect(find.text('Deluxe giường đôi · LT-102'), findsOneWidget);
      expect(find.text('Theo giờ'), findsOneWidget);
      expect(find.text('Qua đêm'), findsOneWidget);
      expect(find.text('Theo ngày'), findsOneWidget);
      expect(find.text('Hoàng Minh Tuấn'), findsOneWidget);
      expect(find.text('12 lượt khách đã ở'), findsOneWidget);
      expect(find.byKey(const Key('dat-phong-nhan-sale')), findsOneWidget);
      expect(find.textContaining('0988'), findsNothing);
      await _bam(t, 'dat-phong-xac-nhan');
      expect(api.daGui, isNull);
      expect(find.text('Chọn giờ nhận phòng'), findsOneWidget);
    });

    testWidgets('giờ đụng lịch bị gạch theo thời lượng; đổi thời lượng thì bỏ chọn',
        (t) async {
      final api = await _moDat(
        t,
        api: _ApiGia(
          ban: [KhoangBan(DateTime(2026, 9, 15, 14), DateTime(2026, 9, 15, 16))],
        ),
      );
      // 13:00 + 2 giờ = 15:00 → đụng 14:00–16:00.
      await _bam(t, 'dat-phong-gio-13:00');
      expect(api.baoGiaGoi, isEmpty);
      // 12:00 → 14:00 chạm mép, không đụng.
      await _bam(t, 'dat-phong-gio-12:00');
      expect(api.baoGiaGoi.single.$2, DateTime(2026, 9, 15, 12));
      expect(api.baoGiaGoi.single.$3, DateTime(2026, 9, 15, 14));
      expect(find.byKey(const Key('dat-phong-tong')), findsOneWidget);
      // Lên 3 giờ → 12:00–15:00 đụng lịch → bỏ chọn.
      await _bam(t, 'dat-phong-them-thoi-luong');
      expect(find.byKey(const Key('dat-phong-tong')), findsNothing);
      expect(find.text('3 giờ'), findsOneWidget);
    });

    testWidgets('đặt theo giờ: gửi đúng số khách, tên, SĐT, tin rồi mở phiếu',
        (t) async {
      final api = await _moDat(t);
      await _bam(t, 'dat-phong-gio-16:00');
      expect(find.text('140.000đ'), findsWidgets);
      await t.enterText(find.byKey(const Key('dat-phong-ten')), 'Lê Tuấn Anh');
      await t.enterText(find.byKey(const Key('dat-phong-sdt')), '0918234889');
      await _bam(t, 'dat-phong-xac-nhan');
      await t.pump(const Duration(milliseconds: 400));
      expect(api.daGui, {
        'ma_bao_gia': 'gia-v1',
        'ten': 'Lê Tuấn Anh',
        'sdt': '0918234889',
        'so_khach': 2,
        'house_id': 43,
      });
      expect(find.byType(PhieuDatPhongScreen), findsOneWidget);
      expect(find.text('Phiếu đặt phòng'), findsOneWidget);
    });

    testWidgets('qua đêm: nhận 21:00, trả 12:00 trưa hôm sau', (t) async {
      final api = await _moDat(t);
      await _bam(t, 'dat-phong-goi-qua_dem');
      await _bam(t, 'dat-phong-gio-21:00');
      expect(api.baoGiaGoi.last.$1, 'qua_dem');
      expect(api.baoGiaGoi.last.$2, DateTime(2026, 9, 15, 21));
      expect(api.baoGiaGoi.last.$3, DateTime(2026, 9, 16, 12));
      expect(find.text('T4, 16/09'), findsOneWidget);
    });

    testWidgets('theo ngày: 2 đêm trả 12:00 ngày thứ ba', (t) async {
      final api = await _moDat(t);
      await _bam(t, 'dat-phong-goi-theo_ngay');
      await _bam(t, 'dat-phong-gio-14:00');
      await _bam(t, 'dat-phong-them-thoi-luong');
      expect(api.baoGiaGoi.last.$2, DateTime(2026, 9, 15, 14));
      expect(api.baoGiaGoi.last.$3, DateTime(2026, 9, 17, 12));
    });

    testWidgets('ngày kín lịch thì báo, gợi chọn ngày khác', (t) async {
      await _moDat(
        t,
        api: _ApiGia(
          ban: [KhoangBan(DateTime(2026, 9, 15), DateTime(2026, 9, 16))],
        ),
      );
      expect(find.byKey(const Key('dat-phong-het-gio')), findsOneWidget);
      expect(find.text('Kín phòng'), findsOneWidget);
    });

    testWidgets('phòng chưa có sale: nói trước và không cho bấm đặt', (t) async {
      await _moDat(t, api: _ApiGia(nhanDat: false));
      expect(find.textContaining('chưa nhận đặt trực tuyến'), findsOneWidget);
      final nut = t.widget<ButtonStyleButton>(
        find.byKey(const Key('dat-phong-xac-nhan')),
      );
      expect(nut.onPressed, isNull);
    });
  });

  group('Phiếu đặt phòng', () {
    Future<(_ApiGia, List<Uri>)> moPhieu(WidgetTester t, Map<String, dynamic> du) async {
      _manRong(t);
      final api = _ApiGia(phieuTraVe: du);
      final mo = <Uri>[];
      await pumpApp(
        t,
        PhieuDatPhongScreen(
          phieuBanDau: PhieuDatPhong.fromMap(du),
          api: api,
          moLink: (u) async => mo.add(u),
        ),
      );
      await t.pump();
      return (api, mo);
    }

    testWidgets('đã trả phòng: có nút đánh giá kỳ lưu trú, mở đúng tin', (t) async {
      final du = _phieu(trangThai: 'checked_out', huyDuoc: false);
      (du['phong'] as Map)['house_id'] = 68;
      await moPhieu(t, du);
      await t.ensureVisible(find.byKey(const Key('phieu-dp-danh-gia')));
      await t.tap(find.byKey(const Key('phieu-dp-danh-gia')));
      await t.pumpAndSettle();
      final man = t.widget<WriteReviewScreen>(find.byType(WriteReviewScreen));
      expect(man.houseId, 68);
    });

    testWidgets('chưa trả phòng thì chưa có nút đánh giá', (t) async {
      final du = _phieu();
      (du['phong'] as Map)['house_id'] = 68;
      await moPhieu(t, du);
      expect(find.byKey(const Key('phieu-dp-danh-gia')), findsNothing);
    });

    testWidgets('chờ xác nhận: mã, QR, giờ nhận/trả, tổng; gọi/Zalo đúng số sale',
        (t) async {
      final (_, mo) = await moPhieu(t, _phieu());
      expect(find.text('Đã gửi · chờ sale xác nhận phòng'), findsOneWidget);
      expect(find.text('#AC-260915-AABBCCDDEE'), findsOneWidget);
      expect(find.byKey(const Key('phieu-dp-qr')), findsOneWidget);
      expect(find.text('16:00'), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('140.000đ'), findsOneWidget);
      await t.tap(find.byKey(const Key('phieu-dp-goi')));
      await t.tap(find.byKey(const Key('phieu-dp-zalo')));
      await t.pump();
      expect(mo[0].toString(), 'tel:0988123456');
      expect(mo[1].toString(), 'https://zalo.me/0988123456');
    });

    testWidgets('huỷ trong hạn: hỏi lại, gửi lý do, phiếu chuyển đã huỷ', (t) async {
      final (api, _) = await moPhieu(t, _phieu());
      await t.tap(find.byKey(const Key('phieu-dp-huy')));
      await _cho(t);
      await t.tap(find.byKey(const Key('phieu-dp-giu')));
      await _cho(t);
      expect(api.lyDoHuy, isNull);
      await t.tap(find.byKey(const Key('phieu-dp-huy')));
      await _cho(t);
      await t.tap(find.text('Đặt nhầm giờ'));
      await t.pump();
      await t.tap(find.byKey(const Key('phieu-dp-huy-xac-nhan')));
      await _cho(t);
      expect(api.lyDoHuy, 'Đặt nhầm giờ');
      expect(find.text('Bạn đã huỷ đặt phòng'), findsOneWidget);
      expect(find.byKey(const Key('phieu-dp-qr')), findsNothing);
      expect(find.byKey(const Key('phieu-dp-huy')), findsNothing);
    });

    testWidgets('quá hạn huỷ: không có nút huỷ, nhắc gọi sale', (t) async {
      await moPhieu(t, _phieu(huyDuoc: false));
      expect(find.byKey(const Key('phieu-dp-huy')), findsNothing);
      expect(find.textContaining('Đã quá hạn huỷ miễn phí'), findsOneWidget);
    });

    testWidgets('đã xác nhận thì nói phòng đang được giữ', (t) async {
      await moPhieu(t, _phieu(trangThai: 'approved'));
      expect(find.text('Đã xác nhận · phòng đang được giữ'), findsOneWidget);
    });
  });

  group('Kiểm soát đơn: tiến trình, sửa, đổi giờ, lịch sử', () {
    Future<_ApiGia> moPhieu(WidgetTester t, {bool huyDuoc = true}) async {
      _manRong(t);
      final api = _ApiGia(phieuTraVe: _phieu(huyDuoc: huyDuoc));
      await pumpApp(
        t,
        PhieuDatPhongScreen(
          phieuBanDau: PhieuDatPhong.fromMap(_phieu(huyDuoc: huyDuoc)),
          api: api,
          moLink: (_) async {},
        ),
        auth: SignedInAuthProvider(),
      );
      await _cho(t);
      return api;
    }

    testWidgets('phiếu có tiến trình 4 bước và lịch sử ai làm gì', (t) async {
      await moPhieu(t);
      expect(find.byKey(const Key('tien-trinh')), findsOneWidget);
      expect(find.text('Nhận phòng'), findsWidgets);
      expect(find.byKey(const Key('lich-su-thay-doi')), findsOneWidget);
      expect(find.text('Xác nhận phòng'), findsOneWidget);
      expect(find.text('Sale Hoàng Minh Tuấn'), findsOneWidget);
      expect(find.text('Theo giờ · 16:00 15/01 → 18:00 15/01'), findsOneWidget);
    });

    testWidgets('sửa thông tin: chỉ gửi trường đã đổi, lịch sử tải lại', (t) async {
      final api = await moPhieu(t);
      await t.tap(find.byKey(const Key('phieu-dp-sua')));
      await _cho(t);
      final luu = find.byKey(const Key('sua-luu'));
      expect(t.widget<FilledButton>(luu).onPressed, isNull);
      await t.tap(find.byKey(const Key('sua-bot')));
      await t.pump();
      await t.tap(luu);
      await _cho(t);
      expect(api.daSua, {'so_khach': 1});
      expect(find.text('Sửa thông tin'), findsWidgets);
      expect(find.text('Số khách: 2 → 1'), findsOneWidget);
    });

    testWidgets('đổi giờ: mở lưới giờ, báo giá bỏ qua chính đơn, xác nhận', (t) async {
      final api = await moPhieu(t);
      await t.tap(find.byKey(const Key('phieu-dp-doi-gio')));
      await _cho(t);
      expect(find.text('Đổi giờ đặt phòng'), findsOneWidget);
      // Giờ cũ 16:00 không bị gạch vì là khoảng của chính đơn này.
      expect(find.text('Giờ hiện tại'), findsOneWidget);
      await t.tap(find.byKey(const Key('dat-phong-gio-19:00')));
      await _cho(t);
      expect(api.baoGiaDoiGioGoi.last.$1, 7);
      await t.tap(find.byKey(const Key('dat-phong-xac-nhan')));
      await _cho(t);
      expect(api.daDoiGio, isNotNull);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Phiếu đặt phòng'), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('phieu-dp-nhan'))).data, '19:00');
    });

    testWidgets('quá hạn huỷ: không đổi giờ, không huỷ; vẫn sửa được thông tin',
        (t) async {
      await moPhieu(t, huyDuoc: false);
      expect(find.byKey(const Key('phieu-dp-doi-gio')), findsNothing);
      expect(find.byKey(const Key('phieu-dp-huy')), findsNothing);
      expect(find.byKey(const Key('phieu-dp-sua')), findsOneWidget);
    });

    test('cắt khoảng của chính đơn ra khỏi lịch bận', () {
      final ds = truKhoang(
        [KhoangBan(DateTime(2026, 9, 15, 14), DateTime(2026, 9, 15, 20))],
        DateTime(2026, 9, 15, 16),
        DateTime(2026, 9, 15, 18),
      );
      expect(ds.map((k) => (k.tu.hour, k.den.hour)).toList(), [(14, 16), (18, 20)]);
    });
  });
}
