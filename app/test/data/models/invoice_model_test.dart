/// Unit test cho InvoiceModel — hoá đơn, nơi sai một con số là sai tiền thật.
///
/// Hai nhóm bất biến:
///  1. **Số tiền** phải đọc đúng kể cả khi backend gửi int thay vì double
///     (JSON không phân biệt 1000 và 1000.0 — gửi int là chuyện thường).
///  2. **Trường bắt buộc thiếu thì PHẢI nổ ngay**, không được âm thầm cho 0.
///     Hoá đơn thiếu `total_amount` mà hiển thị 0 đồng thì tệ hơn nhiều so với
///     việc báo lỗi tải.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/invoice_model.dart';

Map<String, dynamic> _lineItem({Map<String, dynamic> them = const {}}) => {
      'id': 1,
      'invoice_id': 10,
      'category': 'rent',
      'description': 'Tiền thuê tháng 7',
      'quantity': 1,
      'unit_price': 3000000,
      'amount': 3000000,
      'sort_order': 0,
      ...them,
    };

Map<String, dynamic> _invoice({Map<String, dynamic> them = const {}}) => {
      'id': 10,
      'host_id': 2,
      'contract_id': 5,
      'invoice_number': 'HD-2026-07-001',
      'period_start': '2026-07-01',
      'period_end': '2026-07-31',
      'issued_date': '2026-07-01',
      'due_date': '2026-07-10',
      'status': 'unpaid',
      'total_amount': 3500000,
      'created_at': '2026-07-01T00:00:00',
      'updated_at': '2026-07-01T00:00:00',
      ...them,
    };

void main() {
  group('InvoiceLineItem', () {
    test('đọc đủ trường', () {
      final li = InvoiceLineItem.fromJson(_lineItem());
      expect(li.id, 1);
      expect(li.category, 'rent');
      expect(li.description, 'Tiền thuê tháng 7');
      expect(li.amount, 3000000);
      expect(li.sortOrder, 0);
    });

    test('số nguyên từ JSON đọc thành double đúng giá trị', () {
      // Backend gửi 3000000 (int) chứ không phải 3000000.0 — ép `as double`
      // sẽ nổ, nên model phải dùng `as num`.
      final li = InvoiceLineItem.fromJson(_lineItem(them: {'amount': 250000}));
      expect(li.amount, 250000.0);
      expect(li.amount, isA<double>());
    });

    test('mô tả thiếu → chuỗi rỗng, không null', () {
      final j = Map<String, dynamic>.from(_lineItem())..remove('description');
      expect(InvoiceLineItem.fromJson(j).description, '');
    });

    test('số lượng/đơn giá thiếu → 0', () {
      final j = Map<String, dynamic>.from(_lineItem())
        ..remove('quantity')
        ..remove('unit_price');
      final li = InvoiceLineItem.fromJson(j);
      expect(li.quantity, 0);
      expect(li.unitPrice, 0);
    });

    test('sort_order thiếu → 0 (giữ nguyên thứ tự backend trả)', () {
      final j = Map<String, dynamic>.from(_lineItem())..remove('sort_order');
      expect(InvoiceLineItem.fromJson(j).sortOrder, 0);
    });

    test('THIẾU amount thì NỔ — cố ý, không được âm thầm cho 0', () {
      // Dòng hoá đơn không có số tiền là dữ liệu hỏng. Hiển thị 0 đồng sẽ khiến
      // chủ nhà và khách thuê tranh cãi vì con số sai.
      final j = Map<String, dynamic>.from(_lineItem())..remove('amount');
      expect(() => InvoiceLineItem.fromJson(j), throwsA(anything));
    });
  });

  group('InvoiceModel — trường bắt buộc', () {
    test('đọc đủ trường chính', () {
      final inv = InvoiceModel.fromJson(_invoice());
      expect(inv.id, 10);
      expect(inv.invoiceNumber, 'HD-2026-07-001');
      expect(inv.status, 'unpaid');
      expect(inv.totalAmount, 3500000);
      expect(inv.periodStart, '2026-07-01');
      expect(inv.dueDate, '2026-07-10');
    });

    test('total_amount là số nguyên vẫn đọc được', () {
      expect(
        InvoiceModel.fromJson(_invoice(them: {'total_amount': 12000})).totalAmount,
        12000.0,
      );
    });

    test('created_at/updated_at phân tích thành DateTime', () {
      final inv = InvoiceModel.fromJson(_invoice());
      expect(inv.createdAt, DateTime.parse('2026-07-01T00:00:00'));
      expect(inv.updatedAt, DateTime.parse('2026-07-01T00:00:00'));
    });
  });

  group('InvoiceModel — trường tuỳ chọn', () {
    test('paid_amount thiếu → 0 (hoá đơn chưa trả đồng nào)', () {
      expect(InvoiceModel.fromJson(_invoice()).paidAmount, 0);
    });

    test('paid_at null → null, không phải epoch', () {
      // Nếu lỡ mặc định thành 1970 thì UI sẽ hiện "đã thanh toán 1/1/1970".
      expect(InvoiceModel.fromJson(_invoice(them: {'paid_at': null})).paidAt,
          isNull);
    });

    test('paid_at có giá trị → phân tích đúng', () {
      final inv = InvoiceModel.fromJson(
          _invoice(them: {'paid_at': '2026-07-05T14:30:00'}));
      expect(inv.paidAt, DateTime.parse('2026-07-05T14:30:00'));
    });

    test('public_token vắng → null (hoá đơn chưa chia sẻ công khai)', () {
      final inv = InvoiceModel.fromJson(_invoice());
      expect(inv.publicToken, isNull);
      expect(inv.publicTokenExpiresAt, isNull);
    });

    test('public_token kèm hạn dùng', () {
      final inv = InvoiceModel.fromJson(_invoice(them: {
        'public_token': 'abc123',
        'public_token_expires_at': '2026-08-01T00:00:00',
      }));
      expect(inv.publicToken, 'abc123');
      expect(inv.publicTokenExpiresAt, DateTime.parse('2026-08-01T00:00:00'));
    });

    test('ghi chú vắng → null', () {
      expect(InvoiceModel.fromJson(_invoice()).note, isNull);
    });
  });

  group('InvoiceModel — dòng hoá đơn', () {
    test('không có line_items → danh sách RỖNG, không null', () {
      // UI duyệt danh sách này; null sẽ nổ ngay lúc dựng màn.
      expect(InvoiceModel.fromJson(_invoice()).lineItems, isEmpty);
    });

    test('line_items null → cũng rỗng', () {
      expect(
        InvoiceModel.fromJson(_invoice(them: {'line_items': null})).lineItems,
        isEmpty,
      );
    });

    test('đọc nhiều dòng, giữ đúng thứ tự', () {
      final inv = InvoiceModel.fromJson(_invoice(them: {
        'line_items': [
          _lineItem(them: {'id': 1, 'category': 'rent', 'amount': 3000000}),
          _lineItem(them: {'id': 2, 'category': 'electricity', 'amount': 500000}),
        ],
      }));
      expect(inv.lineItems.length, 2);
      expect(inv.lineItems[0].category, 'rent');
      expect(inv.lineItems[1].amount, 500000);
    });

    test('tổng các dòng khớp tổng hoá đơn (dữ liệu mẫu nhất quán)', () {
      final inv = InvoiceModel.fromJson(_invoice(them: {
        'total_amount': 3500000,
        'line_items': [
          _lineItem(them: {'id': 1, 'amount': 3000000}),
          _lineItem(them: {'id': 2, 'amount': 500000}),
        ],
      }));
      final sum = inv.lineItems.fold<double>(0, (a, e) => a + e.amount);
      expect(sum, inv.totalAmount);
    });
  });
}
