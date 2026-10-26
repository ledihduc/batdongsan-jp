/// LỊCH PHÒNG TRỐNG — thay cho cờ vacant/occupied một-bit.
///
/// Điều phải giữ bằng test:
///  1. Tải HỎNG phải nói là hỏng. Danh sách rỗng đọc thành "mọi phòng đều
///     trống" — một câu trả lời sai mà chủ nhà sẽ đem đi hứa với khách.
///  2. Khoảng do hợp đồng / đơn đặt sinh ra KHÔNG xoá được ở màn lịch: xoá
///     thẳng là lịch nói một đằng, sổ sách một nẻo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/services/lich_phong_api.dart';
import 'package:house_booking/features/host/lich_phong/lich_phong_screen.dart';

import '../../helpers/pump_app.dart';

class _ApiGia extends LichPhongApi {
  const _ApiGia(this.ds, {this.hong = false});

  final List<PhongCoLich> ds;
  final bool hong;

  @override
  Future<List<PhongCoLich>> cuaToa(
    int buildingId, {
    DateTime? tu,
    DateTime? den,
  }) async {
    if (hong) throw Exception('mất mạng');
    return ds;
  }
}

KhoangBan _khoang({
  required String nguon,
  required bool goDuoc,
  int tu = 1,
  int den = 10,
}) => KhoangBan(
  id: 1,
  roomId: 1,
  tuNgay: DateTime(2026, 10, tu),
  denNgay: DateTime(2026, 10, den),
  kenh: 'dai_han',
  nguon: nguon,
  goDuoc: goDuoc,
);

Future<void> _dung(WidgetTester t, LichPhongApi api) async {
  t.view.physicalSize = const Size(520, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await pumpApp(t, LichPhongScreen(api: api, buildingId: 5));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('phòng không có khoảng nào → "Trống"', (t) async {
    await _dung(
      t,
      const _ApiGia([PhongCoLich(roomId: 1, ma: 'P01', khoang: [])]),
    );
    expect(find.text('P01'), findsOneWidget);
    expect(find.text('Trống'), findsOneWidget);
    expect(find.textContaining('1/1 phòng trống'), findsOneWidget);
  });

  testWidgets('phòng đang bận → hiện NGÀY trống trở lại, không phải cờ', (
    t,
  ) async {
    await _dung(
      t,
      _ApiGia([
        PhongCoLich(
          roomId: 1,
          ma: 'P01',
          khoang: [_khoang(nguon: 'contract', goDuoc: false)],
        ),
      ]),
    );
    // Đây là toàn bộ lý do màn này tồn tại: "trống từ ngày nào", chứ không
    // phải "hôm nay có ai ở không".
    expect(find.textContaining('Bận đến 10/10'), findsOneWidget);
  });

  testWidgets('tải hỏng → báo lỗi + nút thử lại, KHÔNG hiện "đều trống"', (
    t,
  ) async {
    await _dung(t, const _ApiGia([], hong: true));
    expect(find.text('Không tải được lịch phòng.'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.textContaining('phòng trống suốt'), findsNothing);
  });

  testWidgets('khoảng của HỢP ĐỒNG không có nút xoá', (t) async {
    await _dung(
      t,
      _ApiGia([
        PhongCoLich(
          roomId: 1,
          ma: 'P01',
          khoang: [_khoang(nguon: 'contract', goDuoc: false)],
        ),
      ]),
    );
    await t.tap(find.text('P01'));
    await t.pumpAndSettle();
    expect(find.text('Hợp đồng thuê'), findsOneWidget);
    expect(find.byTooltip('Bỏ chặn'), findsNothing);
  });

  testWidgets('khoảng TỰ CHẶN thì gỡ được ngay tại chỗ', (t) async {
    await _dung(
      t,
      _ApiGia([
        PhongCoLich(
          roomId: 1,
          ma: 'P01',
          khoang: [_khoang(nguon: 'thu_cong', goDuoc: true)],
        ),
      ]),
    );
    await t.tap(find.text('P01'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Bỏ chặn'), findsOneWidget);
  });

  testWidgets('den_ngay là ngày TRẢ, không tính → 1→10 là 9 ngày', (t) async {
    // Lệch một ngày ở đây là mở bán đúng hôm phòng còn đang sửa.
    final k = _khoang(nguon: 'thu_cong', goDuoc: true);
    expect(k.soNgay, 9);
  });
}
