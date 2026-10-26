import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/dien_nuoc_api.dart';
import 'package:house_booking/features/host/dien_nuoc/dien_nuoc_dai_han_screen.dart';

import '../../../helpers/pump_app.dart';

/// Màn "Điện nước" — chi tiết một phòng một tháng (mockup 12/09/2026) + bảng
/// duyệt cả toà khi chọn "Tất cả phòng".
///
/// Điều phải giữ bằng test:
///   * số, tiền từng thứ, % so tháng trước và ba bước duyệt là SỐ SERVER TRẢ;
///     tháng chưa có chỉ số thì nói "chưa", không in 0.
///   * nút theo ĐÚNG trạng thái — đã duyệt thì không còn Duyệt / Chụp lại.
///   * chọn "Tất cả phòng" vẫn duyệt hàng loạt được (chủ nhà 20 phòng).
class _ApiGia extends DienNuocApi {
  _ApiGia({this.ct});

  int soLanTai = 0;
  int soLanTaiCt = 0;
  ChiTietDienNuoc? ct;
  final daDuyet = <int>[];
  final traVe = <(int, String)>[];
  final phongDaHoi = <int>[];

  @override
  Future<BangDienNuoc> bangThang(int buildingId, String thang) async {
    soLanTai++;
    return _bang();
  }

  @override
  Future<ChiTietDienNuoc> chiTietPhong(int roomId, String thang) async {
    soLanTaiCt++;
    phongDaHoi.add(roomId);
    return ct ?? _chiTiet();
  }

  @override
  Future<void> duyet(int readingId) async => daDuyet.add(readingId);

  @override
  Future<void> chupLai(int readingId, String lyDo) async =>
      traVe.add((readingId, lyDo));
}

Map<String, dynamic> _dong(String ma, String trangThai, String ten, {int? id}) => {
  'reading_id': id,
  'room_id': (id ?? 99) + 100,
  'ma_phong': ma,
  'nguoi_thue': ten,
  'hop_dong_den': '2027-09-30',
  'trang_thai': trangThai,
  'cap_nhat': id == null ? null : '2026-09-12T09:14:00',
  'dien_cu': 732,
  'dien_moi': id == null ? null : 852,
  'nuoc_cu': 110,
  'nuoc_moi': id == null ? null : 125,
  'dien_dung': id == null ? null : 120,
  'nuoc_dung': id == null ? null : 15,
  'thanh_tien': id == null ? null : 468000,
  'anh_dien': null,
  'anh_nuoc': null,
  'ly_do_tra_ve': null,
};

BangDienNuoc _bang() => BangDienNuoc.fromMap({
  'building_id': 1,
  'ten_toa': 'An Cư Garden',
  'thang': '2026-09',
  'tong_phong': 4,
  'da_gui': 3,
  'cho_duyet': 1,
  'thieu_anh': 1,
  'da_duyet': 1,
  'chua_gui': 1,
  'tong_tam_tinh': 1935000,
  'dong': [
    _dong('P101', 'da_duyet', 'Nguyễn Văn An', id: 10),
    _dong('P102', 'cho_duyet', 'Trần Thị Bình', id: 11),
    _dong('P103', 'thieu_anh', 'Lê Văn Cường', id: 12),
    _dong('P104', 'chua_gui', 'Phạm Văn Dũng'),
  ],
});

/// Phòng P102 — phòng đang CHỜ DUYỆT, tức phòng màn tự mở sẵn.
ChiTietDienNuoc _chiTiet({
  String trangThai = 'cho_duyet',
  String? duyetLuc,
  bool coSo = true,
  String? lyDoTraVe,
}) => ChiTietDienNuoc.fromMap({
  'room_id': 111,
  'ma_phong': 'P102',
  'building_id': 1,
  'ten_toa': 'An Cư Garden',
  'thang': '2026-09',
  'nguoi_thue': 'Trần Thị Bình',
  'hop_dong_den': '2027-09-30',
  'trang_thai': coSo ? trangThai : 'chua_gui',
  'reading_id': coSo ? 11 : null,
  'ngay_chot': coSo ? '2026-09-12' : null,
  'gui_luc': coSo ? '2026-09-12T09:14:00' : null,
  'nguoi_gui': coSo ? 'Trần Thị Bình' : '',
  'duyet_luc': duyetLuc,
  'dien_cu': 732,
  'dien_moi': coSo ? 852 : null,
  'dien_dung': coSo ? 120 : null,
  'nuoc_cu': 110,
  'nuoc_moi': coSo ? 125 : null,
  'nuoc_dung': coSo ? 15 : null,
  'gia_dien': 2400,
  'gia_nuoc': 12000,
  'tien_dien': coSo ? 288000 : null,
  'tien_nuoc': coSo ? 180000 : null,
  'thanh_tien': coSo ? 468000 : null,
  'anh_dien': null,
  'anh_nuoc': null,
  'ly_do_tra_ve': lyDoTraVe,
  'dien_phan_tram': coSo ? 12 : null,
  'nuoc_phan_tram': coSo ? 7 : null,
  'tien_phan_tram': coSo ? 10 : null,
  'lich_su': [
    {'thang': '2026-04'},
    {'thang': '2026-05', 'dien_dung': 105, 'nuoc_dung': 14, 'thanh_tien': 420000},
    {'thang': '2026-06', 'dien_dung': 112, 'nuoc_dung': 13, 'thanh_tien': 430000},
    {'thang': '2026-07', 'dien_dung': 100, 'nuoc_dung': 11, 'thanh_tien': 380000},
    {'thang': '2026-08', 'dien_dung': 107, 'nuoc_dung': 14, 'thanh_tien': 425000},
    if (coSo)
      {'thang': '2026-09', 'dien_dung': 120, 'nuoc_dung': 15, 'thanh_tien': 468000}
    else
      {'thang': '2026-09'},
  ],
});

Future<_ApiGia> _dung(
  WidgetTester t, {
  List<({int id, String ten})> toa = const [(id: 1, ten: 'An Cư Garden')],
  ChiTietDienNuoc? ct,
  double rong = 420,
  int? contractIdHoaDon,
  int? roomIdBanDau,
}) async {
  t.view.physicalSize = Size(rong, 2600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final api = _ApiGia(ct: ct);
  await pumpApp(
    t,
    DienNuocDaiHanScreen(
      toa: toa,
      api: api,
      thangBanDau: '2026-09',
      contractIdHoaDon: contractIdHoaDon,
      roomIdBanDau: roomIdBanDau,
    ),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
  return api;
}

void main() {
  testWidgets('chi tiết một phòng: số, tiền, % và ba bước như mockup', (t) async {
    final api = await _dung(t);
    // Mở màn là nhảy vào phòng CẦN làm trước (P102 đang chờ duyệt).
    expect(api.phongDaHoi, [111]);
    for (final s in [
      'Điện nước',
      'Quản lý chỉ số và chi phí hàng tháng',
      // "Tất cả phòng" chỉ nằm trong danh sách ô chọn phòng khi mở ra — test
      // riêng ở dưới mở dropdown rồi bấm.
      'Tổng quan tháng 9, 2026',
      'Chờ chủ nhà duyệt',
      'Số điện',
      '120 kWh',
      '≈ 288.000đ',
      'Số nước',
      '15 m³',
      '≈ 180.000đ',
      'Tổng chi phí',
      '468.000đ',
      'Người thuê đã chụp',
      '12/09/2026 09:14',
      'Đã xác nhận',
      '--/--/----',
      'Đồng hồ điện',
      'Đồng hồ nước',
      'Chỉ số cũ',
      'Chỉ số mới',
      'Sản lượng tiêu thụ',
      'Lịch sử 6 tháng gần nhất',
      'Điện (kWh)',
      'Nước (m³)',
      'Mẹo nhỏ',
    ]) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    expect(find.text('12% so với tháng trước'), findsOneWidget);
    expect(find.text('7% so với tháng trước'), findsOneWidget);
    expect(find.text('T9/2026'), findsOneWidget);
    expect(find.text('T4/2026'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Duyệt chỉ số gọi đúng chỉ số rồi nạp lại', (t) async {
    final api = await _dung(t);
    await t.tap(find.byKey(const ValueKey('duyet-chi-so')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(api.daDuyet, [11]);
    expect(api.soLanTai, 2);
  });

  testWidgets('Yêu cầu chụp lại gửi kèm lý do', (t) async {
    final api = await _dung(t);
    await t.tap(find.byKey(const ValueKey('yeu-cau-chup-lai')));
    await t.pumpAndSettle();
    await t.tap(find.text('Gửi yêu cầu'));
    await t.pumpAndSettle();
    expect(api.traVe, [(11, 'Ảnh công tơ chưa rõ')]);
  });

  testWidgets('đã duyệt: không còn nút Duyệt / Yêu cầu chụp lại', (t) async {
    await _dung(
      t,
      ct: _chiTiet(trangThai: 'da_duyet', duyetLuc: '2026-09-12T10:02:00'),
    );
    expect(find.byKey(const ValueKey('duyet-chi-so')), findsNothing);
    expect(find.byKey(const ValueKey('yeu-cau-chup-lai')), findsNothing);
    expect(find.text('12/09/2026 10:02'), findsOneWidget);
  });

  testWidgets('tháng chưa ai gửi: nói "chưa", không in số 0', (t) async {
    await _dung(t, ct: _chiTiet(coSo: false));
    expect(find.text('Chưa gửi chỉ số'), findsWidgets);
    expect(find.text('Chưa có tháng trước để so'), findsWidgets);
    expect(find.byKey(const ValueKey('duyet-chi-so')), findsNothing);
    // Mốc cũ vẫn hiện — đó là số đã duyệt tháng trước.
    expect(find.text('732'), findsOneWidget);
    expect(find.text('0 kWh'), findsNothing);
  });

  testWidgets('đã bị trả về: hiện lý do, chỉ còn nút Duyệt', (t) async {
    await _dung(
      t,
      ct: _chiTiet(trangThai: 'can_chup_lai', lyDoTraVe: 'Ảnh công tơ bị mờ'),
    );
    expect(find.textContaining('Ảnh công tơ bị mờ'), findsOneWidget);
    expect(find.byKey(const ValueKey('duyet-chi-so')), findsOneWidget);
    expect(find.byKey(const ValueKey('yeu-cau-chup-lai')), findsNothing);
  });

  testWidgets('chọn "Tất cả phòng" → bảng duyệt cả toà, duyệt được hàng loạt', (t) async {
    final api = await _dung(t, rong: 1200);
    await t.tap(find.byKey(const ValueKey('chon-phong')));
    await t.pumpAndSettle();
    await t.tap(find.text('Tất cả phòng').last);
    await t.pumpAndSettle();

    expect(find.text('Còn 1 phòng chưa gửi'), findsOneWidget);
    expect(find.text('1.935.000đ'), findsOneWidget);
    expect(find.text('P101'), findsOneWidget);
    expect(find.text('Chưa gửi chỉ số tháng này.'), findsOneWidget);

    await t.tap(find.text('Duyệt'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(api.daDuyet, [11]);
  });

  testWidgets('chưa có toà nào → nói rõ, không quay vòng tải mãi', (t) async {
    await _dung(t, toa: const []);
    expect(find.text('Bạn chưa có toà nhà nào.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('vào từ "Lập hoá đơn": có thanh Tiếp tục, nói rõ chỉ số', (t) async {
    await _dung(t, contractIdHoaDon: 9);
    expect(find.text('Bước 1 · Chốt chỉ số'), findsOneWidget);
    // Phòng mở sẵn đang CHỜ duyệt → phải nói thẳng, đừng để chủ nhà bấm tiếp
    // rồi mới biết hoá đơn không có tiền điện.
    expect(find.text('Chưa có chỉ số đã duyệt tháng này'), findsOneWidget);
    final nut = t.widget<FilledButton>(
      find.ancestor(
        of: find.text('Tiếp tục'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(nut.onPressed, isNotNull);
  });

  testWidgets('phòng mở thẳng không có trong bảng tháng: KHÔNG vỡ màn', (t) async {
    // Vào từ Hồ sơ phòng một phòng chưa có hợp đồng tháng này (hoặc bảng tháng
    // tải lỗi): DropdownButton đòi đúng một mục khớp giá trị đang chọn, thiếu
    // là ném assert ngay lúc build — người dùng thấy màn đỏ.
    final api = await _dung(t, roomIdBanDau: 4242);
    expect(t.takeException(), isNull);
    expect(api.phongDaHoi, [4242]);
    // Màn vẫn vẽ được và ô chọn phòng có mục cho phòng đang xem.
    expect(find.text('Điện nước'), findsOneWidget);
    expect(find.byKey(const ValueKey('chon-phong')), findsOneWidget);
  });

  testWidgets('vào xem điện nước bình thường: KHÔNG có thanh Tiếp tục', (t) async {
    await _dung(t);
    expect(find.text('Tiếp tục'), findsNothing);
    expect(find.text('Bước 1 · Chốt chỉ số'), findsNothing);
  });
}
