import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/features/guest/broker/broker_deal_map.dart';

import '../helpers/pump_app.dart';

/// Bản đồ điểm chốt.
///
/// Test canh đúng thứ vừa hỏng thật: khi tách cụm nút +/− ra khỏi widget bản đồ
/// (bắt buộc, vì bọc thêm lớp trong map làm camera lệch kích thước), màn TOÀN
/// MÀN HÌNH bị quên gắn lại nút → trên máy tính không còn cách phóng to.
HouseModel _nha(int id, double lat, double lng, {String tx = 'rent'}) =>
    HouseModel(
      id: id,
      hostId: 1,
      title: 'Nhà $id',
      description: '',
      categoryId: 1,
      price: 1,
      area: 1,
      address: 'a',
      city: 'Thanh Hóa',
      district: 'q1',
      latitude: lat,
      longitude: lng,
      bedrooms: 1,
      bathrooms: 1,
      transactionType: tx,
    );

void main() {
  testWidgets('nhúng: nút +/− có sẵn NGAY build đầu (GlobalKey đã gắn)',
      (tester) async {
    await pumpApp(
      tester,
      BrokerDealMapScreen(
        houses: [_nha(1, 19.8, 105.8), _nha(2, 20.1, 105.6)],
        hostName: 'A',
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
  });

  testWidgets('không có tin nào có toạ độ → không dựng bản đồ', (tester) async {
    await pumpApp(
      tester,
      BrokerDealMap(
        houses: [
          HouseModel(
            id: 9,
            hostId: 1,
            title: 'Không toạ độ',
            description: '',
            categoryId: 1,
            price: 1,
            area: 1,
            address: 'a',
            city: 'x',
            district: 'y',
            bedrooms: 1,
            bathrooms: 1,
          ),
        ],
        hostName: 'A',
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('một ghim duy nhất vẫn dựng được (không chia cho 0)',
      (tester) async {
    await pumpApp(
      tester,
      BrokerDealMap(houses: [_nha(1, 19.8, 105.8)], hostName: 'A'),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('nhiều ghim TRÙNG toạ độ không làm vỡ phép tính zoom',
      (tester) async {
    await pumpApp(
      tester,
      BrokerDealMap(
        houses: [_nha(1, 19.8, 105.8), _nha(2, 19.8, 105.8)],
        hostName: 'A',
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
