import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/ekyc_api.dart';
import 'package:house_booking/features/host/ekyc/ekyc_chu_nha_screen.dart';

import '../../../helpers/pump_app.dart';

/// eKYC CHỦ NHÀ — điều phải giữ:
///   * thiếu ảnh / thông tin thì nút Nộp tắt và nói còn thiếu mấy mục;
///   * chụp từng ảnh gửi đúng loại; đủ thì Nộp được;
///   * mở từ LINK (có token) thì không có nút tạo link (đang ở máy thứ hai);
///   * đã nộp / đã duyệt thì không sửa được; bị từ chối thì hiện lý do.
class _EkycGia extends EkycApi {
  _EkycGia({this.trangThai = 'nhap', this.lyDo});

  String trangThai;
  String? lyDo;
  final anh = <String>{};
  var coThongTin = false;
  final goi = <String>[];

  HoSoEkyc get _hs {
    final thieu = [
      for (final a in cacAnhEkyc)
        if (a.$1 != 'gpkd' && !anh.contains(a.$1)) a.$2,
      if (!coThongTin) 'Họ tên',
    ];
    return HoSoEkyc(
      trangThai: trangThai,
      hoTen: coThongTin ? 'Nguyễn Văn An' : '',
      soCccdCuoi: coThongTin ? '7890' : '',
      tenKinhDoanh: '',
      soGpkd: '',
      anh: {for (final a in cacAnhEkyc) a.$1: anh.contains(a.$1)},
      thieu: thieu,
      suaDuoc: trangThai == 'nhap' || trangThai == 'tu_choi',
      lyDoTuChoi: lyDo,
      canhBao: [if (!anh.contains('gpkd')) 'Chưa có ảnh giấy phép kinh doanh'],
    );
  }

  @override
  Future<HoSoEkyc> xem() async => _hs;

  @override
  Future<HoSoEkyc> luuThongTin({
    required String hoTen,
    required String soCccd,
    required String tenKinhDoanh,
    required String soGpkd,
  }) async {
    goi.add('thong_tin:$hoTen');
    coThongTin = true;
    return _hs;
  }

  @override
  Future<HoSoEkyc> guiAnh(String loai, List<int> bytes) async {
    goi.add('anh:$loai');
    anh.add(loai);
    return _hs;
  }

  @override
  Future<HoSoEkyc> nop() async {
    goi.add('nop');
    trangThai = 'cho_duyet';
    return _hs;
  }
}

Future<List<int>?> _anhGia(BuildContext context, {required bool cameraTruoc}) async => [1, 2, 3];

Future<void> _dung(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(500, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await pumpApp(t, w);
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets('không có ô chân dung; chỉ cần CCCD hai mặt + thông tin là nộp được', (t) async {
    final api = _EkycGia();
    await _dung(t, EkycChuNhaScreen(api: api, chonAnh: _anhGia));
    expect(find.byKey(const Key('ekyc-chup-chan_dung')), findsNothing);
    expect(find.text('Chưa nộp'), findsOneWidget);
    expect(find.text('Còn thiếu 3 mục'), findsOneWidget);
    expect(find.byKey(const Key('ekyc-canh-bao')), findsOneWidget);
    expect(t.widget<FilledButton>(find.byKey(const Key('ekyc-nop'))).onPressed, isNull);

    await t.enterText(find.byKey(const Key('ekyc-ho-ten')), 'Nguyễn Văn An');
    await t.tap(find.byKey(const Key('ekyc-luu-thong-tin')));
    await t.pump();
    // Bỏ trống giấy phép kinh doanh — vẫn nộp được (chỉ cảnh báo).
    for (final loai in ['cccd_truoc', 'cccd_sau']) {
      await t.tap(find.byKey(Key('ekyc-chup-$loai')));
      await t.pump();
      await t.pump();
    }
    expect(api.goi.where((g) => g.startsWith('anh:')).length, 2);
    expect(find.byKey(const Key('ekyc-canh-bao')), findsOneWidget);
    await t.tap(find.byKey(const Key('ekyc-nop')));
    await t.pump();
    await t.pump();
    expect(api.goi.last, 'nop');
    expect(find.text('Đã nộp · chờ admin duyệt'), findsOneWidget);
    expect(find.byKey(const Key('ekyc-nop')), findsNothing);
  });

  testWidgets('mở từ link (có token): không có nút tạo link', (t) async {
    await _dung(t, EkycChuNhaScreen(token: 'abc', api: _EkycGia(), chonAnh: _anhGia));
    expect(find.byKey(const Key('ekyc-tao-link')), findsNothing);
    expect(find.byKey(const Key('ekyc-chup-cccd_truoc')), findsOneWidget);
  });

  testWidgets('đăng nhập trong app: có nút làm trên điện thoại', (t) async {
    await _dung(t, EkycChuNhaScreen(api: _EkycGia(), chonAnh: _anhGia));
    expect(find.byKey(const Key('ekyc-tao-link')), findsOneWidget);
  });

  testWidgets('bị từ chối: hiện lý do và sửa được', (t) async {
    await _dung(t, EkycChuNhaScreen(api: _EkycGia(trangThai: 'tu_choi', lyDo: 'Ảnh CCCD bị mờ'), chonAnh: _anhGia));
    expect(find.text('Cần bổ sung'), findsOneWidget);
    expect(find.text('Ảnh CCCD bị mờ'), findsOneWidget);
    expect(find.byKey(const Key('ekyc-chup-gpkd')), findsOneWidget);
  });

  testWidgets('đã duyệt: không còn nút chụp / nộp', (t) async {
    await _dung(t, EkycChuNhaScreen(api: _EkycGia(trangThai: 'da_duyet'), chonAnh: _anhGia));
    expect(find.text('Đã xác minh'), findsOneWidget);
    expect(find.byKey(const Key('ekyc-chup-gpkd')), findsNothing);
    expect(find.byKey(const Key('ekyc-nop')), findsNothing);
  });
}
