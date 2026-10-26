/// Chọn địa giới hành chính — thứ dễ hỏng nhất là ĐỂ LỌT ĐƯỜNG NHẬP TAY.
///
/// Cả widget này tồn tại chỉ vì một lý do: chặn "TP.HCM" / "Tp Hồ Chí Minh" /
/// "Sài Gòn" cùng tồn tại trong một cột. Nên hai điều phải giữ bằng test:
///
///  1. KHÔNG có ô "Quận/Huyện". Cấp đó bị bãi bỏ 01/07/2025; ai đó thấy form
///     "trống" mà thêm lại vào là dựng lại một cấp không còn danh mục.
///  2. API hỏng thì BÁO LỖI, tuyệt đối không âm thầm rơi về `TextField` —
///     đó chính là cửa dữ liệu bẩn mà widget sinh ra để đóng.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/core/widgets/chon_dia_ban.dart';
import 'package:house_booking/data/services/location_input_service.dart';

import '../../helpers/pump_app.dart';

const _hcm = AdminUnit(code: '79', name: 'Tp Hồ Chí Minh');
const _hue = AdminUnit(code: '46', name: 'Thành phố Huế');

/// Dịch vụ giả — không chạm mạng, và đếm số lần hỏi phường/xã.
class _SvcGia extends LocationInputService {
  _SvcGia({this.loiTinh = false});

  final bool loiTinh;
  final List<String> daHoiPhuong = [];

  @override
  Future<List<AdminUnit>> provinces() async {
    if (loiTinh) throw Exception('mạng hỏng');
    return const [_hcm, _hue];
  }

  @override
  Future<List<AdminUnit>> wards(String provinceCode) async {
    daHoiPhuong.add(provinceCode);
    if (provinceCode == '79') {
      return const [
        AdminUnit(code: '7901', name: 'Phường An Khánh'),
        AdminUnit(code: '7902', name: 'Phường Bến Thành'),
      ];
    }
    return const [AdminUnit(code: '4601', name: 'Phường Thuận Hoá')];
  }
}

Future<_SvcGia> _dung(
  WidgetTester t, {
  bool hienPhuongXa = true,
  bool loiTinh = false,
  void Function(AdminUnit?, AdminUnit?)? onChanged,
}) async {
  final svc = _SvcGia(loiTinh: loiTinh);
  await pumpApp(
    t,
    Scaffold(
      body: ChonDiaBan(
        service: svc,
        hienPhuongXa: hienPhuongXa,
        onChanged: onChanged ?? (_, _) {},
      ),
    ),
  );
  await t.pumpAndSettle();
  return svc;
}

/// Chạm vào Ô thứ [i] (0 = tỉnh, 1 = phường/xã).
///
/// Cố ý KHÔNG `tap(find.text('Tỉnh/Thành phố'))`: khi đã chọn giá trị thì nhãn
/// nổi lên viền và nằm ngoài vùng chạm của ô — test vẫn xanh nhưng đang chạm
/// nhờ hit-test rơi vào nền, một thay đổi bố cục nhỏ là gãy.
Future<void> _moO(WidgetTester t, int i) async {
  await t.tap(find.byType(InputDecorator).at(i));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('KHÔNG có ô Quận/Huyện — cấp này đã bị bãi bỏ 01/07/2025', (
    t,
  ) async {
    await _dung(t);
    expect(find.text('Quận/Huyện'), findsNothing);
    expect(find.text('Quận'), findsNothing);
    expect(find.text('Huyện'), findsNothing);
    // Đúng hai cấp, không hơn.
    expect(find.text('Tỉnh/Thành phố'), findsOneWidget);
    expect(find.text('Phường/Xã'), findsOneWidget);
  });

  testWidgets('chưa chọn tỉnh thì ô phường/xã bị khoá và nói rõ vì sao', (
    t,
  ) async {
    final svc = await _dung(t);
    expect(find.text('Chọn tỉnh/thành trước'), findsOneWidget);
    // Chưa có tỉnh thì không được đi hỏi danh sách phường — hỏi cũng rỗng.
    expect(svc.daHoiPhuong, isEmpty);
  });

  testWidgets('chọn tỉnh → mở được khay phường/xã của ĐÚNG tỉnh đó', (t) async {
    final svc = await _dung(t);

    await _moO(t, 0);
    await t.tap(find.text('Tp Hồ Chí Minh'));
    await t.pumpAndSettle();

    expect(svc.daHoiPhuong, ['79']);

    await _moO(t, 1);
    expect(find.text('Phường An Khánh'), findsOneWidget);
    expect(find.text('Phường Bến Thành'), findsOneWidget);
    // Phường của tỉnh khác tuyệt đối không được lọt vào.
    expect(find.text('Phường Thuận Hoá'), findsNothing);
  });

  testWidgets('đổi tỉnh thì XOÁ phường đã chọn, không để nó nằm lại', (
    t,
  ) async {
    AdminUnit? tinh;
    AdminUnit? phuong;
    await _dung(
      t,
      onChanged: (a, b) {
        tinh = a;
        phuong = b;
      },
    );

    await _moO(t, 0);
    await t.tap(find.text('Tp Hồ Chí Minh'));
    await t.pumpAndSettle();
    await _moO(t, 1);
    await t.tap(find.text('Phường Bến Thành'));
    await t.pumpAndSettle();
    expect(phuong?.name, 'Phường Bến Thành');

    await _moO(t, 0);
    await t.tap(find.text('Thành phố Huế'));
    await t.pumpAndSettle();

    expect(tinh?.name, 'Thành phố Huế');
    // Nếu chỗ này còn "Phường Bến Thành" thì bản ghi ra một địa chỉ có thật
    // trong hai tỉnh khác nhau.
    expect(phuong, isNull);
    expect(find.text('Phường Bến Thành'), findsNothing);
  });

  testWidgets('tìm không dấu vẫn ra — gõ có dấu trên điện thoại tốn gấp đôi', (
    t,
  ) async {
    await _dung(t);
    await _moO(t, 0);

    await t.enterText(find.byType(TextField).first, 'ho chi minh');
    await t.pumpAndSettle();

    expect(find.text('Tp Hồ Chí Minh'), findsOneWidget);
    expect(find.text('Thành phố Huế'), findsNothing);
  });

  testWidgets('API hỏng → báo lỗi + cho thử lại, KHÔNG rơi về ô nhập tay', (
    t,
  ) async {
    await _dung(t, loiTinh: true);
    expect(find.text('Không tải được danh mục tỉnh/thành'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    // Đây là điều quan trọng nhất: không có ô gõ tự do nào mọc ra thay thế.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('hienPhuongXa=false thì chỉ còn cấp tỉnh', (t) async {
    await _dung(t, hienPhuongXa: false);
    expect(find.text('Tỉnh/Thành phố'), findsOneWidget);
    expect(find.text('Phường/Xã'), findsNothing);
  });
}
