import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/hoa_don_thang_api.dart';
import 'package:house_booking/features/host/hoa_don/dich_vu_hoa_don_screen.dart';

import '../../../helpers/pump_app.dart';

/// Trang "Dịch vụ & hoá đơn" — bước hai của việc lập hoá đơn tháng.
///
/// Điều phải giữ bằng test:
///   * bật/tắt dịch vụ hay sửa giảm trừ là GỌI LẠI server, không tự cộng ở máy
///     — con số trên màn phải là con số sẽ ghi vào hoá đơn.
///   * chỉ số chưa duyệt thì nói thẳng, và hỏi lại trước khi gửi hoá đơn thiếu
///     tiền điện nước.
///   * hoá đơn đã gửi thì không gửi lần hai sau lưng khách.
class _ApiGia extends HoaDonThangApi {
  _ApiGia({this.chiSo = 'da_duyet', this.trangThaiHoaDon});

  final String chiSo;

  /// `null` = kỳ này chưa có hoá đơn nào.
  final String? trangThaiHoaDon;

  /// Lựa chọn dịch vụ của từng lượt xem trước (null = mặc định hợp đồng).
  final List<Map<int, double>?> luot = [];
  double giamTruCuoi = 0;
  Map<String, Object?>? daChot;

  static const _catalog = [
    (id: 11, ten: 'Internet', gia: 100000.0, chuKy: 'monthly'),
    (id: 12, ten: 'Giữ xe', gia: 80000.0, chuKy: 'monthly'),
    (id: 13, ten: 'Giặt sấy', gia: 40000.0, chuKy: 'one_time'),
  ];

  /// Mặc định của hợp đồng: Internet + Giữ xe.
  static const _macDinh = {11: 1.0, 12: 1.0};

  @override
  Future<HoaDonThang> xemTruoc(
    int contractId,
    String thang, {
    Map<int, double>? dichVu,
    double giamTru = 0,
  }) async {
    luot.add(dichVu);
    giamTruCuoi = giamTru;
    final chon = dichVu ?? _macDinh;
    double tienDichVu = 0;
    final dongDichVu = <Map<String, dynamic>>[];
    for (final f in _catalog) {
      final sl = chon[f.id] ?? 0;
      if (sl <= 0) continue;
      tienDichVu += f.gia * sl;
      dongDichVu.add({
        'category': 'service',
        'description': sl == 1 ? f.ten : '${f.ten} x${sl.toStringAsFixed(0)}',
        'quantity': sl,
        'unit_price': f.gia,
        'amount': f.gia * sl,
      });
    }
    final daDuyet = chiSo == 'da_duyet';
    final tienDien = daDuyet ? 360000.0 : 0.0;
    final tienNuoc = daDuyet ? 200000.0 : 0.0;
    return HoaDonThang.fromMap({
      'contract_id': contractId,
      'thang': thang,
      'toa': {
        'id': 1,
        'ten': 'An Cư Garden',
        'dia_chi': '25 Hoàng Văn Thụ · Ba Đình · Hà Nội',
        'anh': null,
      },
      'phong': {'id': 2, 'ma': '301', 'trang_thai': 'occupied'},
      'khach': {'ten': 'Nguyễn Văn A', 'sdt': '0987654321'},
      'tien_thue': 2000000,
      'han_dong': '2024-09-05',
      'con_ngay': 3,
      'hoa_don': trangThaiHoaDon == null
          ? null
          : {
              'id': 77,
              'so': 'HD-77',
              'ky': thang,
              'tong': 2650000,
              'da_tra': 0,
              'trang_thai': trangThaiHoaDon,
              'han_dong': '2024-09-05',
            },
      'dien': {'dung': daDuyet ? 120 : 0, 'gia': 3000, 'tien': tienDien},
      'nuoc': {'dung': daDuyet ? 10 : 0, 'gia': 20000, 'tien': tienNuoc},
      'chi_so_trang_thai': chiSo,
      'canh_bao_chi_so': daDuyet
          ? null
          : 'Chỉ số điện nước tháng này chưa được duyệt nên chưa vào hoá đơn.',
      'dich_vu': [
        for (final f in _catalog)
          {
            'id': f.id,
            'ten': f.ten,
            'don_gia': f.gia,
            'chu_ky': f.chuKy,
            'dang_bat': (chon[f.id] ?? 0) > 0,
            'so_luong': chon[f.id] ?? 0,
          },
      ],
      'tien_phong': 2000000,
      'tien_dich_vu': tienDichVu,
      'giam_tru': giamTru,
      'tong': 2000000 + tienDien + tienNuoc + tienDichVu - giamTru,
      'dong': [
        {
          'category': 'rent',
          'description': 'Tiền thuê phòng',
          'quantity': 1,
          'unit_price': 2000000,
          'amount': 2000000,
        },
        ...dongDichVu,
      ],
      'lich_su': [
        {
          'id': 70,
          'so': 'HD-70',
          'ky': '2024-07',
          'tong': 2600000,
          'da_tra': 2600000,
          'trang_thai': 'paid',
          'han_dong': '2024-08-05',
        },
      ],
    });
  }

  @override
  Future<ChotHoaDon> chot(
    int contractId,
    String thang, {
    Map<int, double>? dichVu,
    double giamTru = 0,
    bool gui = false,
  }) async {
    daChot = {
      'contract': contractId,
      'thang': thang,
      'dich_vu': dichVu,
      'giam_tru': giamTru,
      'gui': gui,
    };
    return ChotHoaDon(
      invoiceId: 77,
      so: 'HD-77',
      tong: 2650000,
      trangThai: gui ? 'sent' : 'draft',
      daGui: gui,
    );
  }
}

Future<_ApiGia> _mo(
  WidgetTester t, {
  String chiSo = 'da_duyet',
  String? trangThaiHoaDon,
  List<int>? daMo,
}) async {
  t.view.physicalSize = const Size(1000, 2400);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final api = _ApiGia(chiSo: chiSo, trangThaiHoaDon: trangThaiHoaDon);
  await pumpApp(
    t,
    DichVuHoaDonScreen(
      contractId: 5,
      thang: '2024-08',
      api: api,
      moHoaDonThu: (id) => daMo?.add(id),
    ),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  return api;
}

void main() {
  testWidgets('hiện phòng, tổng tiền, hạn đóng và từng dòng tiền', (t) async {
    await _mo(t);
    expect(find.text('Dịch vụ & hóa đơn'), findsOneWidget);
    expect(find.text('An Cư Garden'), findsOneWidget);
    expect(find.text('Phòng 301'), findsOneWidget);
    expect(find.text('Nguyễn Văn A · 0987654321'), findsOneWidget);
    // 2.000.000 phòng + 360.000 điện + 200.000 nước + 180.000 dịch vụ.
    expect(find.text('2.740.000đ'), findsNWidgets(2)); // thẻ tổng + dòng tổng
    expect(find.textContaining('Hạn thanh toán: 05/09/2024'), findsOneWidget);
    expect(find.textContaining('(còn 3 ngày)'), findsOneWidget);
    expect(find.textContaining('120 kWh'), findsOneWidget);
    expect(find.textContaining('10 m³'), findsOneWidget);
    expect(find.text('Lịch sử hóa đơn'), findsOneWidget);
    expect(find.text('Tháng 7/2024'), findsOneWidget);
  });

  testWidgets('tắt một dịch vụ → gọi lại xem trước, tổng giảm đúng', (t) async {
    final api = await _mo(t);
    await t.tap(find.byKey(const ValueKey('bat-12'))); // Giữ xe 80.000
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    expect(api.luot.first, isNull, reason: 'lượt đầu để server dùng mặc định');
    expect(api.luot.last, {11: 1.0});
    expect(find.text('2.660.000đ'), findsNWidgets(2));
  });

  testWidgets('dịch vụ theo lượt: tăng số lượt thì gửi đúng số', (t) async {
    final api = await _mo(t);
    await t.tap(find.byKey(const ValueKey('tang-13')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.luot.last, {11: 1.0, 12: 1.0, 13: 1.0});

    await t.tap(find.byKey(const ValueKey('tang-13')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.luot.last![13], 2.0);
    expect(find.text('2.820.000đ'), findsNWidgets(2)); // + 40.000 × 2
  });

  testWidgets('giảm trừ: nhập số → gửi lên và hiện dòng âm', (t) async {
    final api = await _mo(t);
    await t.tap(find.byKey(const ValueKey('dong-giam-tru')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('o-giam-tru')), '50000');
    await t.tap(find.byKey(const ValueKey('luu-giam-tru')));
    await t.pumpAndSettle();

    expect(api.giamTruCuoi, 50000);
    expect(find.text('-50.000đ'), findsOneWidget);
    expect(find.text('2.690.000đ'), findsNWidgets(2));
  });

  testWidgets('chỉ số chưa duyệt: báo rõ và hỏi lại trước khi gửi', (t) async {
    final daMo = <int>[];
    final api = await _mo(t, chiSo: 'cho_duyet', daMo: daMo);
    expect(
      find.textContaining('chưa được duyệt nên chưa vào hoá đơn'),
      findsOneWidget,
    );
    // Tiền điện nước bằng 0 vì hoá đơn chỉ tính số ĐÃ DUYỆT.
    expect(find.text('2.180.000đ'), findsNWidgets(2));

    await t.tap(find.byKey(const ValueKey('gui-hoa-don')));
    await t.pumpAndSettle();
    expect(find.text('Chưa có chỉ số đã duyệt'), findsOneWidget);
    expect(api.daChot, isNull, reason: 'chưa xác nhận thì chưa gửi');

    await t.tap(find.byKey(const ValueKey('gui-thieu-chi-so')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.daChot!['gui'], isTrue);
    expect(api.daChot!['contract'], 5);
    expect(daMo, [77], reason: 'gửi xong mở luôn hoá đơn vừa tạo');
  });

  testWidgets('chỉ số đã duyệt: gửi luôn, không hỏi lại', (t) async {
    final api = await _mo(t);
    await t.tap(find.byKey(const ValueKey('gui-hoa-don')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.daChot!['gui'], isTrue);
    expect(api.daChot!['thang'], '2024-08');
  });

  testWidgets('hoá đơn đã gửi: không gửi lần hai, nhắc được', (t) async {
    await _mo(t, trangThaiHoaDon: 'sent');
    expect(find.text('Đã gửi'), findsOneWidget);
    expect(find.text('Chưa thanh toán'), findsOneWidget);
    final nut = t.widget<FilledButton>(
      find.ancestor(
        of: find.text('Đã gửi'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(nut.onPressed, isNull);
    final nhac = t.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Nhắc thanh toán'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(nhac.onPressed, isNotNull);
  });

  testWidgets('chưa có hoá đơn: chưa nhắc được, nhãn "Chưa lập"', (t) async {
    await _mo(t);
    expect(find.text('Chưa lập'), findsOneWidget);
    final nhac = t.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Nhắc thanh toán'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(nhac.onPressed, isNull);
  });
}
