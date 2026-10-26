import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/features/guest/project/building_claim_screen.dart';

import '../../helpers/pump_app.dart';

/// CHỦ NHÀ nhập mã bàn giao của sale — chiều ngược của mã mời.
///
/// Nút cuối màn hỏi **"Đúng tài sản của tôi"**. Trước đây nó hỏi mà chỉ đưa tên
/// toà, địa chỉ và SỐ phòng để đối chiếu. Ba thứ đó không kiểm được gì: sale gõ
/// nhầm diện tích, đánh thiếu một tầng, hay dựng nhầm sang toà bên cạnh thì chủ
/// nhà cũng chỉ phát hiện SAU khi đã nhận — mà nhận rồi thì gỡ ra là chuyện
/// khác hẳn (đổi `host_id` khi đã có hợp đồng bị chặn).
class _ApiGia extends ApiClient {
  _ApiGia(this.tra);

  final Map<String, dynamic> tra;
  final List<String> daGoi = [];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    daGoi.add(path);
    return tra;
  }
}

Map<String, dynamic> _toa({
  int soPhong = 2,
  List<Map<String, dynamic>>? phong,
  int conLai = 0,
}) => {
  'id': 6,
  'name': 'Toà Hoa Sữa',
  'address': 'Thượng Lý, Hồng Bàng',
  'city': 'Tp Hải Phòng',
  'district': 'Hồng Bàng',
  'so_phong': soPhong,
  'da_nhan': false,
  'nguoi_dang_giu': 'Vũ Đình Văn',
  'phong':
      phong ??
      [
        {
          'ma': 'P01',
          'dien_tich': 25.0,
          'suc_chua': 2,
          'gia': 5500000.0,
          'con_trong': true,
        },
        {
          'ma': 'P02',
          'dien_tich': 82.0,
          'suc_chua': 1,
          'gia': 12000000.0,
          'con_trong': false,
        },
      ],
  'con_lai': conLai,
};

Future<void> _dung(WidgetTester t, _ApiGia api) async {
  t.view.physicalSize = const Size(520, 2000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await pumpApp(t, BuildingClaimScreen(api: api));
  await t.pumpAndSettle();
}

Future<void> _tra(WidgetTester t, String ma) async {
  await t.enterText(find.byType(TextField), ma);
  await t.tap(find.text('Kiểm tra tài sản'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('kiểm tra xong hiện TỪNG phòng, không chỉ con số', (t) async {
    await _dung(t, _ApiGia(_toa()));
    await _tra(t, 'BANGIAO1');
    expect(find.text('P01'), findsOneWidget);
    expect(find.text('P02'), findsOneWidget);
    expect(find.textContaining('25m²'), findsOneWidget);
    expect(find.textContaining('82m²'), findsOneWidget);
  });

  testWidgets('phòng đã có người nhìn ra ngay', (t) async {
    // Đây là thứ chủ nhà đối chiếu kỹ nhất: phòng nào đang có khách.
    await _dung(t, _ApiGia(_toa()));
    await _tra(t, 'BANGIAO1');
    expect(find.text('Đã thuê'), findsOneWidget);
  });

  testWidgets('chưa tra mã thì chưa có gì để nhận', (t) async {
    await _dung(t, _ApiGia(_toa()));
    expect(find.text('Đúng tài sản của tôi'), findsNothing);
    expect(find.text('P01'), findsNothing);
  });

  testWidgets('bỏ trống mà bấm → đòi nhập mã, không gọi API', (t) async {
    final api = _ApiGia(_toa());
    await _dung(t, api);
    await t.tap(find.text('Kiểm tra tài sản'));
    await t.pumpAndSettle();
    expect(find.text('Nhập mã Sale gửi cho bạn'), findsOneWidget);
    expect(api.daGoi, isEmpty);
  });

  testWidgets('mã gõ chữ thường vẫn gửi lên dạng HOA', (t) async {
    final api = _ApiGia(_toa());
    await _dung(t, api);
    await _tra(t, 'bangiao1');
    expect(api.daGoi.single, '/api/buildings/claim/BANGIAO1');
  });

  testWidgets('toà 0 phòng → nói thẳng, vẫn nhận được', (t) async {
    await _dung(t, _ApiGia(_toa(soPhong: 0, phong: const [])));
    await _tra(t, 'BANGIAO1');
    expect(find.text('Toà này chưa có phòng nào.'), findsOneWidget);
    expect(find.text('Đúng tài sản của tôi'), findsOneWidget);
  });

  testWidgets('toà lớn bị cắt bớt → nói còn bao nhiêu', (t) async {
    await _dung(t, _ApiGia(_toa(soPhong: 65, conLai: 5)));
    await _tra(t, 'BANGIAO1');
    expect(find.text('và 5 phòng nữa'), findsOneWidget);
  });
}
