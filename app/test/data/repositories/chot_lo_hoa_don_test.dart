import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/repositories/api_invoice_repository.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Chốt lô hoá đơn: hai ô đơn giá để TRỐNG thì **không được gửi khoá nào cả**.
///
/// Trước migration 0104 đơn giá điện/nước chỉ tồn tại như tham số của lô, mặc
/// định cứng 3500/15000, và app LUÔN gửi. Nay giá lưu được ở phòng và ở toà —
/// nhưng nếu app vẫn gửi hai số kia thì mọi lô tiếp tục ghi đè, và giá khai ở
/// phòng có cũng như không. Đây là bước dễ quên nhất của cả thay đổi.
class _ClientGia extends ApiClient {
  _ClientGia();

  Map<String, dynamic>? daGui;

  @override
  Future<List<dynamic>> postList(String path, {Object? body}) async {
    daGui = Map<String, dynamic>.from(body as Map);
    return const [];
  }
}

void main() {
  test('không điền gì → payload KHÔNG có đơn giá, server hỏi từng phòng', () async {
    final c = _ClientGia();
    await ApiInvoiceRepository(client: c).generateBatch(
      buildingId: 5,
      month: '2026-09',
    );
    expect(c.daGui!['building_id'], 5);
    expect(c.daGui!.containsKey('electricity_unit_price'), isFalse);
    expect(c.daGui!.containsKey('water_unit_price'), isFalse);
  });

  test('điền MỘT ô → chỉ khoá đó được gửi', () async {
    final c = _ClientGia();
    await ApiInvoiceRepository(client: c).generateBatch(
      buildingId: 5,
      month: '2026-09',
      electricityUnitPrice: 4200,
    );
    expect(c.daGui!['electricity_unit_price'], 4200);
    expect(c.daGui!.containsKey('water_unit_price'), isFalse);
  });

  test('điền cả hai → ghi đè cả lô, y như trước', () async {
    final c = _ClientGia();
    await ApiInvoiceRepository(client: c).generateBatch(
      buildingId: 5,
      month: '2026-09',
      electricityUnitPrice: 3500,
      waterUnitPrice: 15000,
    );
    expect(c.daGui!['electricity_unit_price'], 3500);
    expect(c.daGui!['water_unit_price'], 15000);
  });
}
