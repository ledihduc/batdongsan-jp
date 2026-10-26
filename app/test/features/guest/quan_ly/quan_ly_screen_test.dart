import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/data/services/quan_ly_api.dart';
import 'package:house_booking/features/guest/quan_ly/hop_dong_khach_sheet.dart';
import 'package:house_booking/features/guest/quan_ly/phong_dang_thue_screen.dart';
import 'package:house_booking/features/guest/quan_ly/quan_ly_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';

import '../../../helpers/pump_app.dart';

/// Trang "Quản lý" (thay tab "Đã đặt" của sale/khách, 18/09/2026).
///
/// Điều phải giữ:
///   * hai góc "Của tôi" / "Khách thuê" — mỗi góc tải MỘT lần, đổi qua lại
///     không tải lại, và không bao giờ vẽ dữ liệu góc này dưới nhãn góc kia;
///   * bốn thẻ số đọc đúng `dem` server trả; bấm thẻ = lọc danh sách, bấm lại
///     = bỏ lọc;
///   * "Tất cả" không gồm lịch sử; lịch sử vẫn xem được ở chip riêng;
///   * tìm kiếm không phân biệt dấu ("cau giay" ra "Cầu Giấy");
///   * bấm mục / mốc lịch mở đúng mục, kèm đúng góc nhìn.
UserModel _nguoi(int id, String ten) => UserModel(
  id: id,
  name: ten,
  email: 'u$id@ancu365.vn',
  passwordHash: '',
  phone: '',
  avatarPath: '',
  role: 'guest',
  accountType: 'sale',
);

/// Người dùng đổi được giữa chừng — để thử đăng xuất / đổi tài khoản.
class _AuthGia extends AuthProvider {
  _AuthGia([this._u]);

  UserModel? _u;

  @override
  UserModel? get currentUser => _u;

  @override
  bool get isAuthenticated => _u != null;

  void doi(UserModel? u) {
    _u = u;
    notifyListeners();
  }
}

class _ApiGia extends QuanLyApi {
  _ApiGia(this.duLieu, {this.loi = false});

  final Map<GocQuanLy, TongHopQuanLy> duLieu;
  bool loi;
  final goi = <GocQuanLy>[];

  @override
  Future<TongHopQuanLy> tongHop(GocQuanLy goc) async {
    goi.add(goc);
    if (loi) throw Exception('mất mạng');
    return duLieu[goc] ?? const TongHopQuanLy();
  }
}

MucQuanLy _muc(
  String loai,
  int id,
  String tieuDe, {
  String nhom = NhomQuanLy.daDat,
  String nhan = 'Đã đặt',
  String tong = 'do',
  String diaChi = 'Quận 7, TP. Hồ Chí Minh',
  String dong = '',
  String? khach,
  bool canXuLy = false,
  bool nhac = false,
  String? kenh,
}) => MucQuanLy(
  loai: loai,
  id: id,
  tieuDe: tieuDe,
  diaChi: diaChi,
  nhom: nhom,
  nhan: nhan,
  tong: tong,
  dong: dong,
  khach: khach,
  canXuLy: canXuLy,
  nhac: nhac,
  kenh: kenh,
);

final _cuaToi = TongHopQuanLy(
  dem: const DemQuanLy(daDat: 1, dangDat: 1, dangO: 1, sapToi: 2, lichSu: 1),
  lich: [
    SuKienQuanLy(
      loai: 'xem_nha',
      tieuDe: 'Xem nhà',
      noi: 'Căn hộ Sunrise City',
      batDau: DateTime(2026, 9, 19, 14),
      ketThuc: DateTime(2026, 9, 19, 15),
      mucLoai: 'xem_nha',
      mucId: 11,
    ),
    SuKienQuanLy(
      loai: 'tra_phong',
      tieuDe: 'Trả phòng',
      noi: 'Phòng A203',
      batDau: DateTime(2026, 9, 20, 12),
      mucLoai: 'dat_phong',
      mucId: 22,
    ),
  ],
  danhSach: [
    _muc(
      'xem_nha',
      11,
      'Căn hộ Sunrise City',
      kenh: 'dai_han',
      dong: 'Đã đặt lịch xem nhà · 19/09 · 14:00',
    ),
    _muc(
      'xem_nha',
      12,
      'Studio Thảo Điền',
      nhom: NhomQuanLy.dangDat,
      nhan: 'Đang đặt',
      tong: 'cam',
      dong: 'Bên bán bận giờ bạn chọn — chọn giờ mới',
      canXuLy: true,
    ),
    _muc(
      'dat_phong',
      22,
      'Phòng A203',
      nhom: NhomQuanLy.dangO,
      nhan: 'Đang ở',
      tong: 'xanh',
      diaChi: 'Quận Cầu Giấy, Hà Nội',
      kenh: 'ngan_han',
      dong: 'Qua đêm · trả phòng 12:00 20/09 · còn 1 ngày',
    ),
    _muc(
      'dat_phong',
      23,
      'Phòng B105 cũ',
      nhom: NhomQuanLy.lichSu,
      nhan: 'Đã trả phòng',
      tong: 'xam',
      dong: 'Đã trả phòng · 02/09',
    ),
  ],
);

final _khachThue = TongHopQuanLy(
  dem: const DemQuanLy(dangDat: 1, dangO: 1, canXuLy: 1),
  danhSach: [
    _muc(
      'xem_nha',
      31,
      'Căn hộ 3PN Thượng Lý',
      nhom: NhomQuanLy.dangDat,
      nhan: 'Đang đặt',
      tong: 'cam',
      khach: 'Lê Tuấn Anh',
      canXuLy: true,
      dong: 'Chờ bạn xác nhận lịch xem nhà · 20/09 · 15:00',
    ),
    _muc(
      'thue_dai_han',
      41,
      'Phòng A12 · Chung cư Thượng Lý',
      nhom: NhomQuanLy.dangO,
      nhan: 'Đang ở',
      tong: 'xanh',
      kenh: 'dai_han',
      nhac: true,
      dong: 'Hết hạn 08/10/2026 · còn 20 ngày',
    ),
  ],
);

Future<_ApiGia> _mo(
  WidgetTester t, {
  _ApiGia? api,
  List<(GocQuanLy, MucQuanLy)>? daMo,
  AuthProvider? auth,
  bool moThat = false,
  bool cheDoSale = false,
}) async {
  // Màn dài (đầu trang + 4 thẻ + lịch + danh sách): dựng trên màn hình cao để
  // mọi dòng đều được build — ListView chỉ dựng phần gần khung nhìn.
  t.view.physicalSize = const Size(430, 3200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  final a =
      api ??
      _ApiGia({GocQuanLy.cuaToi: _cuaToi, GocQuanLy.khachThue: _khachThue});
  await pumpApp(
    t,
    auth: auth ?? _AuthGia(_nguoi(4, 'Lê Quang Vinh')),
    QuanLyScreen(
      api: a,
      bayGio: DateTime(2026, 9, 18, 9),
      cheDoSale: cheDoSale,
      // `moThat`: đi đường điều hướng THẬT thay vì seam — để bắt lỗi trỏ nhầm màn.
      moMuc: moThat ? null : (goc, m) async => daMo?.add((goc, m)),
    ),
  );
  await t.pump();
  await t.pump();
  return a;
}

void main() {
  testWidgets('Sale có giao diện khách hàng riêng và chỉ tải góc khách thuê', (
    t,
  ) async {
    final api = await _mo(t, cheDoSale: true);

    expect(find.text('SALE'), findsOneWidget);
    expect(find.text('Công việc khách hàng'), findsOneWidget);
    expect(find.text('Khách đang theo dõi'), findsOneWidget);
    expect(find.byKey(const Key('goc-cua_toi')), findsNothing);
    expect(find.byKey(const Key('goc-khach_thue')), findsNothing);
    expect(api.goi, [GocQuanLy.khachThue]);
  });

  testWidgets('đầu trang + hai góc + bốn thẻ số + lịch + danh sách', (t) async {
    await _mo(t);

    expect(find.text('Quản lý'), findsOneWidget);
    expect(find.text('Xin chào,'), findsOneWidget);
    expect(find.text('Của tôi'), findsOneWidget);
    expect(find.text('Khách thuê'), findsOneWidget);

    // Bốn thẻ đọc đúng số server đếm.
    for (final (khoa, so) in [
      ('da_dat', '1'),
      ('dang_dat', '1'),
      ('dang_o', '1'),
      ('sap_toi', '2'),
    ]) {
      expect(
        find.descendant(
          of: find.byKey(Key('the-dem-$khoa')),
          matching: find.text(so),
        ),
        findsOneWidget,
        reason: 'thẻ $khoa phải hiện $so',
      );
    }

    expect(find.text('Lịch sắp tới'), findsOneWidget);
    expect(find.text('19/09'), findsOneWidget);
    expect(find.text('Th 7'), findsOneWidget); // 19/09/2026 là thứ Bảy
    expect(find.text('14:00 - 15:00'), findsOneWidget);

    expect(find.text('Danh sách quản lý'), findsOneWidget);
    expect(find.text('Căn hộ Sunrise City'), findsWidgets);
    // "Tất cả" = việc đang mở; lịch sử KHÔNG lẫn vào.
    expect(find.text('Phòng B105 cũ'), findsNothing);
  });

  testWidgets('bấm thẻ số → lọc danh sách, bấm lại → bỏ lọc', (t) async {
    await _mo(t);

    await t.tap(find.byKey(const Key('the-dem-dang_o')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('muc-dat_phong-22')), findsOneWidget);
    expect(find.byKey(const Key('muc-xem_nha-11')), findsNothing);
    expect(find.byKey(const Key('muc-xem_nha-12')), findsNothing);

    await t.tap(find.byKey(const Key('the-dem-dang_o')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('muc-xem_nha-11')), findsOneWidget);
    expect(find.byKey(const Key('muc-dat_phong-22')), findsOneWidget);
  });

  testWidgets('chip Lịch sử hiện đơn đã xong', (t) async {
    await _mo(t);
    // Chip cuối nằm ngoài mép phải hàng chip cuộn ngang — cuộn tới rồi mới bấm.
    await t.ensureVisible(find.byKey(const Key('loc-lich_su')));
    await t.tap(find.byKey(const Key('loc-lich_su')));
    await t.pump();
    expect(find.byKey(const Key('muc-dat_phong-23')), findsOneWidget);
    expect(find.byKey(const Key('muc-xem_nha-11')), findsNothing);
  });

  testWidgets('tìm kiếm không phân biệt dấu', (t) async {
    await _mo(t);
    await t.enterText(find.byKey(const Key('quan-ly-tim')), 'cau giay');
    await t.pump();
    expect(find.byKey(const Key('muc-dat_phong-22')), findsOneWidget);
    expect(find.byKey(const Key('muc-xem_nha-11')), findsNothing);

    await t.enterText(find.byKey(const Key('quan-ly-tim')), 'khong co gi');
    await t.pump();
    expect(find.text('Không có mục nào'), findsOneWidget);
  });

  testWidgets('thẻ loại thuê: chữ + màu riêng cho ngắn hạn / dài hạn', (
    t,
  ) async {
    await _mo(t);
    Text chu(String k) => t.widget<Text>(
      find.descendant(of: find.byKey(Key(k)), matching: find.byType(Text)),
    );
    Color nen(String k) =>
        (t.widget<Container>(find.byKey(Key(k))).decoration! as BoxDecoration)
            .color!;
    expect(chu('kenh-dat_phong-22').data, 'Ngắn hạn');
    expect(chu('kenh-xem_nha-11').data, 'Dài hạn');
    expect(nen('kenh-dat_phong-22'), HD.pinStayShort);
    expect(nen('kenh-xem_nha-11'), HD.pinStayLong);
    // Không rõ loại (lịch neo thẳng vào phòng) thì không vẽ thẻ đoán mò.
    expect(find.byKey(const Key('kenh-xem_nha-12')), findsNothing);
  });

  testWidgets('tìm "ngan han" ra mục ngắn hạn', (t) async {
    await _mo(t);
    await t.enterText(find.byKey(const Key('quan-ly-tim')), 'ngan han');
    await t.pump();
    expect(find.byKey(const Key('muc-dat_phong-22')), findsOneWidget);
    expect(find.byKey(const Key('muc-xem_nha-11')), findsNothing);
  });

  testWidgets(
    'hợp đồng sắp hết hạn: dòng tô cam nhưng không đậm như việc cần làm',
    (t) async {
      await _mo(t);
      await t.tap(find.byKey(const Key('goc-khach_thue')));
      await t.pump();
      await t.pump();
      final dong = t.widget<Text>(
        find.text('Hết hạn 08/10/2026 · còn 20 ngày'),
      );
      expect(dong.style!.color, HD.svcOrange);
      expect(dong.style!.fontWeight, FontWeight.w400);
      expect(find.text('Dài hạn'), findsOneWidget);
      expect(find.text('Đang cho thuê'), findsNothing);
    },
  );

  testWidgets(
    'Khách thuê bấm hợp đồng → bảng tóm tắt, KHÔNG mở màn của người thuê',
    (t) async {
      await _mo(t, moThat: true);
      await t.tap(find.byKey(const Key('goc-khach_thue')));
      await t.pump();
      await t.pump();
      await t.tap(find.byKey(const Key('muc-thue_dai_han-41')));
      await t.pumpAndSettle();
      expect(find.byType(HopDongKhachSheet), findsOneWidget);
      expect(find.byType(PhongDangThueScreen), findsNothing);
    },
  );

  testWidgets('đổi sang Khách thuê: tải đúng một lần, thấy tên khách', (
    t,
  ) async {
    final api = await _mo(t);
    expect(api.goi, [GocQuanLy.cuaToi]);

    await t.tap(find.byKey(const Key('goc-khach_thue')));
    await t.pump();
    await t.pump();
    expect(api.goi, [GocQuanLy.cuaToi, GocQuanLy.khachThue]);
    expect(find.text('Khách: Lê Tuấn Anh'), findsOneWidget);
    expect(find.byKey(const Key('muc-thue_dai_han-41')), findsOneWidget);
    // Không còn dữ liệu góc kia.
    expect(find.byKey(const Key('muc-xem_nha-11')), findsNothing);
    expect(find.text('Chưa có khách nào hẹn sắp tới.'), findsOneWidget);

    // Quay lại "Của tôi": dùng dữ liệu đã có, không gọi thêm.
    await t.tap(find.byKey(const Key('goc-cua_toi')));
    await t.pump();
    expect(api.goi, [GocQuanLy.cuaToi, GocQuanLy.khachThue]);
    expect(find.byKey(const Key('muc-xem_nha-11')), findsOneWidget);
  });

  testWidgets('bấm mục và mốc lịch mở đúng mục, đúng góc', (t) async {
    final daMo = <(GocQuanLy, MucQuanLy)>[];
    final api = await _mo(t, daMo: daMo);

    await t.tap(find.byKey(const Key('muc-xem_nha-12')));
    await t.pump();
    expect(daMo.single.$1, GocQuanLy.cuaToi);
    expect(daMo.single.$2.id, 12);

    await t.tap(find.byKey(const Key('su-kien-dat_phong-22-tra_phong')));
    await t.pump();
    expect(daMo.last.$2.id, 22);
    // Mở xong phải tải lại — trong màn đích có thể đã huỷ / đổi giờ.
    expect(api.goi.where((g) => g == GocQuanLy.cuaToi).length, greaterThan(1));
  });

  testWidgets('chỉ còn lịch sử: nói rõ và mở được Lịch sử', (t) async {
    // Ca có thật (18/09/2026): đang ở "Tất cả" mà chỉ có đơn đã xong. Bản đầu
    // bảo người dùng "Chọn Tất cả" — trong khi họ đang ở đó rồi.
    final chiLichSu = TongHopQuanLy(
      dem: const DemQuanLy(lichSu: 1),
      danhSach: [
        _muc(
          'xem_nha',
          51,
          'Căn hộ đã xem',
          nhom: NhomQuanLy.lichSu,
          nhan: 'Đã qua giờ hẹn',
          tong: 'xam',
        ),
      ],
    );
    await _mo(t, api: _ApiGia({GocQuanLy.cuaToi: chiLichSu}));
    expect(find.text('Không có việc nào đang mở'), findsOneWidget);
    expect(find.textContaining('Chọn "Tất cả"'), findsNothing);

    await t.tap(find.byKey(const Key('quan-ly-xem-lich-su')));
    await t.pump();
    expect(find.byKey(const Key('muc-xem_nha-51')), findsOneWidget);
  });

  testWidgets('khách thuê rỗng thì nói rõ, không để trang trống', (t) async {
    await _mo(t, api: _ApiGia({GocQuanLy.cuaToi: _cuaToi}));
    await t.tap(find.byKey(const Key('goc-khach_thue')));
    await t.pump();
    await t.pump();
    expect(find.text('Chưa có khách nào'), findsOneWidget);
  });

  testWidgets('chưa đăng nhập: mời đăng nhập, KHÔNG gọi API', (t) async {
    final api = await _mo(t, auth: _AuthGia());
    expect(find.textContaining('Đăng nhập để theo dõi'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
    expect(api.goi, isEmpty);
  });

  testWidgets('đổi tài khoản: bỏ dữ liệu người trước, tải cho người sau', (
    t,
  ) async {
    final auth = _AuthGia(_nguoi(4, 'Lê Quang Vinh'));
    final api = await _mo(t, auth: auth);
    expect(find.byKey(const Key('muc-xem_nha-11')), findsOneWidget);

    // Người sau không có gì — tuyệt đối không được còn thấy mục của người trước.
    api.duLieu[GocQuanLy.cuaToi] = const TongHopQuanLy();
    auth.doi(_nguoi(9, 'Người khác'));
    await t.pump();
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('muc-xem_nha-11')), findsNothing);
    expect(find.text('Chưa có gì để quản lý'), findsOneWidget);
    expect(api.goi.length, 2);

    // Đăng xuất → mời đăng nhập.
    auth.doi(null);
    await t.pump();
    expect(find.textContaining('Đăng nhập để theo dõi'), findsOneWidget);
  });

  testWidgets('tải hỏng → có nút Thử lại, bấm là tải lại', (t) async {
    final api = _ApiGia({GocQuanLy.cuaToi: _cuaToi}, loi: true);
    await _mo(t, api: api);
    expect(find.text('Thử lại'), findsOneWidget);

    api.loi = false;
    await t.tap(find.text('Thử lại'));
    await t.pump();
    await t.pump();
    expect(find.text('Danh sách quản lý'), findsOneWidget);
  });
}
