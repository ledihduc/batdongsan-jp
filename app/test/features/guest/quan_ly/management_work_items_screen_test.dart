import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/services/management_read_model_api.dart';
import 'package:house_booking/features/guest/quan_ly/management_work_items_screen.dart';

import '../../../helpers/pump_app.dart';

class _ManagementApiGia extends ManagementReadModelApi {
  @override
  Future<ManagementWorkItems> workItems({
    required ManagementMode mode,
    ManagementBucket? bucket,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (bucket == ManagementBucket.history) {
      return const ManagementWorkItems(
        items: [],
        totalItems: 0,
        page: 1,
        totalPages: 0,
      );
    }
    return const ManagementWorkItems(
      items: [
        ManagementWorkItem(
          id: 'rental_journey:15',
          kind: 'RENTAL_JOURNEY',
          title: 'Hồ sơ thuê dài hạn',
          subtitle: 'Hồ sơ #15',
          bucket: ManagementBucket.actionRequired,
          needsAction: true,
          allowedActions: ['SUBMIT_CONTRACT'],
          detailRoute: '/rental-journeys/15',
        ),
      ],
      totalItems: 1,
      page: 1,
      totalPages: 1,
    );
  }
}

class _ManagementPhanTrangGia extends ManagementReadModelApi {
  @override
  Future<ManagementWorkItems> workItems({
    required ManagementMode mode,
    ManagementBucket? bucket,
    int page = 1,
    int pageSize = 20,
  }) async => ManagementWorkItems(
    items: [
      ManagementWorkItem(
        id: 'invoice:$page',
        kind: 'INVOICE',
        title: 'Hóa đơn trang $page',
        subtitle: 'Hạn thanh toán',
        bucket: bucket,
        needsAction: false,
        allowedActions: const [],
        detailRoute: '/invoices/$page',
      ),
    ],
    totalItems: 2,
    page: page,
    totalPages: 2,
  );
}

void main() {
  testWidgets('hiển thị work-item read-only và empty state theo bucket', (
    t,
  ) async {
    ManagementWorkItem? opened;
    await pumpApp(
      t,
      ManagementWorkItemsScreen(
        mode: ManagementMode.owner,
        api: _ManagementApiGia(),
        onOpenItem: (item) async => opened = item,
      ),
    );
    await t.pump();

    expect(find.text('Công việc hoạt động'), findsOneWidget);
    expect(find.text('Hồ sơ thuê dài hạn'), findsOneWidget);
    expect(find.text('Có 1 thao tác theo quyền của bạn'), findsOneWidget);

    await t.tap(find.byKey(const Key('management-v2-open-rental_journey:15')));
    await t.pump();
    expect(opened?.detailRoute, '/rental-journeys/15');

    await t.tap(find.byKey(const Key('management-v2-bucket-HISTORY')));
    await t.pump();

    expect(find.text('Chưa có công việc'), findsOneWidget);
    expect(
      find.text('Lịch sử đã hoàn tất hoặc đã hủy sẽ xuất hiện tại đây.'),
      findsOneWidget,
    );
  });

  testWidgets('nối trang tiếp theo mà không làm mất trang đang xem', (t) async {
    await pumpApp(
      t,
      ManagementWorkItemsScreen(
        mode: ManagementMode.owner,
        api: _ManagementPhanTrangGia(),
      ),
    );
    await t.pump();

    expect(find.text('Hóa đơn trang 1'), findsOneWidget);
    await t.tap(find.byKey(const Key('management-v2-load-more')));
    await t.pump();

    expect(find.text('Hóa đơn trang 1'), findsOneWidget);
    expect(find.text('Hóa đơn trang 2'), findsOneWidget);
    expect(find.byKey(const Key('management-v2-load-more')), findsNothing);
  });
}
