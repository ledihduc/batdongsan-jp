import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/tenant_model.dart';
import 'package:house_booking/data/repositories/api_tenant_repository.dart';
import 'package:house_booking/features/host/khach_thue/khach_thue_screen.dart';

import '../../../helpers/pump_app.dart';

class _RepoGia extends ApiTenantRepository {
  _RepoGia(this.ds);

  final List<TenantModel> ds;

  @override
  Future<List<TenantModel>> fetchTenants({String? query}) async => ds;
}

TenantModel _khach(int id, String ten, String sdt, {bool cccd = false}) =>
    TenantModel(
      id: id,
      hostId: 1,
      fullName: ten,
      phone: sdt,
      cccdFrontUploaded: cccd,
      cccdBackUploaded: cccd,
      createdAt: DateTime(2026, 9, 1),
    );

Future<void> _dung(WidgetTester t, List<TenantModel> ds) async {
  await pumpApp(t, KhachThueScreen(repo: _RepoGia(ds)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  final hai = [
    _khach(1, 'Nguyễn Văn An', '0912345678', cccd: true),
    _khach(2, 'Trần Thị Bình', '0987654321'),
  ];

  testWidgets('liệt kê khách thuê kèm tình trạng CCCD', (t) async {
    await _dung(t, hai);
    expect(find.text('2 khách thuê'), findsOneWidget);
    expect(find.text('Đủ CCCD'), findsOneWidget);
    expect(find.text('Thiếu CCCD'), findsOneWidget);
  });

  testWidgets('tìm theo số điện thoại', (t) async {
    await _dung(t, hai);
    await t.enterText(find.byType(TextField), '0987');
    await t.pump();
    expect(find.text('Trần Thị Bình'), findsOneWidget);
    expect(find.text('Nguyễn Văn An'), findsNothing);
  });

  testWidgets('sổ trống → nói rõ, không quay vòng tải', (t) async {
    await _dung(t, const []);
    expect(find.text('Chưa có khách thuê nào trong sổ.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
