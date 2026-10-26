import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/dien_nuoc_api.dart';
import 'package:house_booking/features/host/dien_nuoc/chup_cong_to_sheet.dart';
import 'package:image/image.dart' as img;

import '../../../helpers/pump_app.dart';

/// Chủ nhà TỰ chụp công tơ.
///
/// Điều phải giữ bằng test:
///   * ảnh gửi lên là ảnh VỪA CHỤP, kèm giờ máy chụp và toạ độ — đó là toàn bộ
///     lý do màn này tồn tại thay vì cho chọn ảnh trong thư viện.
///   * công tơ không chạy lùi: chặn ngay tại chỗ, không phiền server.
///   * ảnh sau khi đóng dấu vẫn là ảnh đọc được (đừng gửi lên một mớ byte hỏng).
///   * ô chỉ số LUÔN có mặt, kể cả trước khi chụp và khi camera hỏng — chủ nhà
///     bấm "Chụp lại" phải thấy ngay chỗ ghi số (chủ dự án báo 18/09/2026).
class _ApiGia extends DienNuocApi {
  Map<String, Object?>? guiLen;

  @override
  Future<void> chuNhaChup(
    int roomId, {
    required String loai,
    required double chiSo,
    required String anh,
    required String chupLuc,
    double? lat,
    double? lng,
  }) async {
    guiLen = {
      'room': roomId,
      'loai': loai,
      'chi_so': chiSo,
      'anh': anh,
      'chup_luc': chupLuc,
      'lat': lat,
      'lng': lng,
    };
  }
}

Uint8List _anhGia() {
  final im = img.Image(width: 400, height: 300);
  img.fill(im, color: img.ColorRgb8(200, 200, 200));
  return Uint8List.fromList(img.encodeJpg(im));
}

Future<_ApiGia> _mo(
  WidgetTester t, {
  double? chiSoCu = 732,
  double? chiSoDangGhi,
  ({double lat, double lng})? viTri = (lat: 21.028511, lng: 105.804817),
  bool coCamera = true,
}) async {
  // Sheet cao 90% màn. Khung test mặc định 800x600 đẩy nút "Chụp ảnh" ra ngoài
  // vùng bấm được — tap() chỉ kêu một dòng cảnh báo rồi bấm vào chỗ trống, nên
  // ảnh không bao giờ chụp và ô chỉ số không hiện. Nới khung cho vừa cả sheet.
  t.view.physicalSize = const Size(1000, 2200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final api = _ApiGia();
  await pumpApp(
    t,
    Scaffold(
      body: ChupCongToSheet(
        roomId: 111,
        maPhong: 'P101',
        loai: 'dien',
        chiSoCu: chiSoCu,
        chiSoDangGhi: chiSoDangGhi,
        nguonDangGhi: 'Người thuê gửi',
        api: api,
        uploadFn: (bytes, ten) async => 'https://anh.test/$ten',
        chupThu: coCamera ? () async => _anhGia() : null,
        // Máy không có camera nào (máy tính để bàn).
        dsCameraThu: coCamera ? null : () async => const [],
        viTriThu: () async => viTri,
      ),
    ),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  return api;
}

void main() {
  testWidgets('chụp xong nhập số → gửi ảnh, giờ chụp và toạ độ', (t) async {
    final api = await _mo(t);
    expect(find.textContaining('21.028511'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('chup-anh')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    await t.enterText(find.byKey(const ValueKey('chi-so-moi')), '852');
    await t.tap(find.byKey(const ValueKey('luu-chi-so')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    final g = api.guiLen!;
    expect(g['room'], 111);
    expect(g['loai'], 'dien');
    expect(g['chi_so'], 852.0);
    expect(g['lat'], 21.028511);
    expect(g['lng'], 105.804817);
    expect(g['anh'], 'https://anh.test/cong-to-dien-P101.jpg');
    expect((g['chup_luc'] as String).isNotEmpty, isTrue);
  });

  testWidgets('không lấy được vị trí: vẫn chụp và gửi được, nói rõ là thiếu', (t) async {
    final api = await _mo(t, viTri: null);
    expect(find.textContaining('Chưa lấy được vị trí'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('chup-anh')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    await t.enterText(find.byKey(const ValueKey('chi-so-moi')), '900');
    await t.tap(find.byKey(const ValueKey('luu-chi-so')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.guiLen!['lat'], isNull);
    expect(api.guiLen!['chi_so'], 900.0);
  });

  testWidgets('số nhỏ hơn tháng trước → báo tại chỗ, KHÔNG gọi server', (t) async {
    final api = await _mo(t);
    await t.tap(find.byKey(const ValueKey('chup-anh')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    await t.enterText(find.byKey(const ValueKey('chi-so-moi')), '700');
    await t.tap(find.byKey(const ValueKey('luu-chi-so')));
    await t.pump();
    expect(find.textContaining('nhỏ hơn tháng trước'), findsOneWidget);
    expect(api.guiLen, isNull);
  });

  testWidgets('ô chỉ số có sẵn TRƯỚC khi chụp, kèm số tháng trước + số người thuê gửi', (t) async {
    await _mo(t, chiSoCu: 1379, chiSoDangGhi: 1428);
    expect(find.byKey(const ValueKey('anh-vua-chup')), findsNothing);
    expect(find.byKey(const ValueKey('chi-so-moi')), findsOneWidget);
    expect(find.text('Tháng trước: 1379 · Người thuê gửi: 1428'), findsOneWidget);
    // Không điền sẵn số người thuê — phải nhìn đồng hồ mà gõ.
    final o = t.widget<TextField>(find.byKey(const ValueKey('chi-so-moi')));
    expect(o.controller!.text, isEmpty);
  });

  testWidgets('gõ số trước rồi mới chụp → vẫn gửi đúng số đó', (t) async {
    final api = await _mo(t);
    await t.enterText(find.byKey(const ValueKey('chi-so-moi')), '861');
    await t.tap(find.byKey(const ValueKey('chup-anh')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.byKey(const ValueKey('luu-chi-so')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.guiLen!['chi_so'], 861.0);
  });

  testWidgets('camera không mở được: vẫn thấy ô số + nút mở lại, không có nút chụp chết', (t) async {
    final api = await _mo(t, coCamera: false);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Thiết bị này không có camera.'), findsOneWidget);
    expect(find.byKey(const ValueKey('chi-so-moi')), findsOneWidget);
    expect(find.byKey(const ValueKey('mo-lai-camera')), findsOneWidget);
    expect(find.byKey(const ValueKey('chup-anh')), findsNothing);
    // Chưa có ảnh thì không có đường lưu — ảnh là bằng chứng của con số.
    expect(find.byKey(const ValueKey('luu-chi-so')), findsNothing);
    expect(api.guiLen, isNull);
  });

  test('đóng dấu: ảnh vẫn đọc được, giữ kích thước, có dải chữ dưới đáy', () {
    final ra = dongDauCongTo(
      _anhGia(),
      maPhong: 'P101',
      loai: 'dien',
      luc: DateTime(2026, 9, 12, 10, 45, 12),
      viTri: (lat: 21.028511, lng: 105.804817),
    );
    final im = img.decodeImage(ra)!;
    expect(im.width, 400);
    expect(im.height, 300);
    // Nền gốc xám 200; dải đóng dấu phải sẫm hẳn đi.
    expect(im.getPixel(10, 295).r < 150, isTrue);
    // Phần trên ảnh không bị đụng tới.
    expect(im.getPixel(10, 20).r > 150, isTrue);
  });

  test('bỏ dấu tiếng Việt cho bộ chữ bitmap', () {
    expect(khongDau('Phòng P101'), 'PHONG P101');
    expect(khongDau('Đồng hồ nước'), 'DONG HO NUOC');
  });
}
