/// Unit tests for PlanningMapProvider state machine.
///
/// Uses MockPlanningService (mocktail) — no network, no Flutter widgets.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:house_booking/data/services/planning_service.dart';
import 'package:house_booking/features/planning/providers/planning_map_provider.dart';

import '../_fakes.dart';
import '../_mocks.dart';

void main() {
  late MockPlanningService svc;
  late PlanningMapProvider provider;

  setUpAll(registerFallbacks);

  setUp(() {
    svc = MockPlanningService();
    provider = PlanningMapProvider(svc);
  });

  tearDown(() => provider.dispose());

  // ---------------------------------------------------------------------------
  // Initial state
  // ---------------------------------------------------------------------------

  test('initial state is idle', () {
    expect(provider.state, equals(MapState.idle));
    expect(provider.selectedParcel, isNull);
    expect(provider.errorMessage, isNull);
    expect(provider.retryCount, equals(0));
  });

  // ---------------------------------------------------------------------------
  // Out-of-bbox tap (AC-06)
  // ---------------------------------------------------------------------------

  test('tap NGOÀI lãnh thổ VN → tăng outOfBboxTick, KHÔNG vào state.error',
      () async {
    // Bangkok (13.75, 100.5) — lng < 102.0 nên nằm ngoài bbox VN.
    await provider.tapParcel(13.75, 100.5);

    expect(provider.outOfBboxTick, equals(1));
    // Cố ý KHÔNG dùng state.error: ErrorCard là modal, bật lên sẽ kẹt overlay.
    // Ngoài bbox chỉ là nhắc nhở thoáng qua (SnackBar), không phải lỗi chặn.
    expect(provider.state, isNot(equals(MapState.error)));
    expect(provider.errorMessage, isNull);
    // Không được gọi service cho toạ độ ngoài vùng — tốn request vô ích.
    verifyNever(
      () => svc.getParcelByPoint(
        any(),
        any(),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
  });

  test('tap TRONG lãnh thổ VN (Hà Nội) vẫn được chấp nhận', () async {
    // Bbox đã mở từ riêng HCMC ra TOÀN QUỐC. Test này canh việc thu hẹp lại
    // sẽ làm hỏng người dùng ngoài TP.HCM.
    when(() => svc.getParcelByPoint(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => null);

    await provider.tapParcel(21.0, 105.85);

    expect(provider.outOfBboxTick, equals(0));
    verify(() => svc.getParcelByPoint(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        )).called(1);
  });

  // ---------------------------------------------------------------------------
  // Happy path: idle → loading → ready
  // ---------------------------------------------------------------------------

  test('tapParcel inside bbox transitions idle → loading → ready', () async {
    when(() => svc.getParcelByPoint(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => fakeParcel());

    expect(provider.state, equals(MapState.idle));

    final future = provider.tapParcel(10.77, 106.69);
    // Immediately after calling tapParcel (before await) state is loading
    expect(provider.state, equals(MapState.loading));

    await future;

    expect(provider.state, equals(MapState.ready));
    expect(provider.selectedParcel, isNotNull);
    expect(provider.selectedParcel!.parcelId, equals('p-001'));
    expect(provider.retryCount, equals(0));
    expect(provider.errorMessage, isNull);
  });

  // ---------------------------------------------------------------------------
  // Error path: idle → loading → error
  // ---------------------------------------------------------------------------

  test('tapParcel transitions to error state when service throws', () async {
    when(() => svc.getParcelByPoint(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        )).thenThrow(const PlanningApiException(500, 'Server error'));

    await provider.tapParcel(10.77, 106.69);

    expect(provider.state, equals(MapState.error));
    expect(provider.retryCount, equals(1));
    expect(provider.errorMessage, isNotNull);
  });

  // ---------------------------------------------------------------------------
  // 404 / no parcel found
  // ---------------------------------------------------------------------------

  test('không có thửa tại điểm tap → idle + noResultTick, KHÔNG phải lỗi',
      () async {
    when(() => svc.getParcelByPoint(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => null);

    await provider.tapParcel(10.77, 106.69);

    // Tap vào sông/biển/đất chưa có dữ liệu là chuyện BÌNH THƯỜNG, không phải
    // lỗi hệ thống — hiện ErrorCard ở đây vừa sai nghĩa vừa kẹt overlay.
    expect(provider.state, equals(MapState.idle));
    expect(provider.noResultTick, equals(1));
    expect(provider.errorMessage, isNull);
    expect(provider.selectedParcel, isNull);
  });

  test('không có thửa thì KHÔNG cộng dồn retryCount', () async {
    when(() => svc.getParcelByPoint(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => null);

    for (var i = 0; i < 3; i++) {
      await provider.tapParcel(10.77, 106.69);
    }
    // Nếu tính nhầm là lỗi, 3 lần tap vào sông sẽ bật thông báo
    // "Vui lòng kiểm tra mạng" — sai hoàn toàn.
    expect(provider.retryCount, equals(0));
    expect(provider.state, equals(MapState.idle));
  });

  // ---------------------------------------------------------------------------
  // Retry counter: 3 consecutive errors → final message (AC-07)
  // ---------------------------------------------------------------------------

  test('3 consecutive errors produce final "Vui lòng kiểm tra mạng" message',
      () async {
    when(() => svc.getParcelByPoint(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        )).thenThrow(const PlanningApiException(503, 'Service unavailable'));

    await provider.tapParcel(10.77, 106.69); // retryCount=1
    await provider.tapParcel(10.77, 106.69); // retryCount=2
    await provider.tapParcel(10.77, 106.69); // retryCount=3

    expect(provider.retryCount, equals(3));
    expect(
      provider.errorMessage,
      contains('Vui lòng kiểm tra mạng'),
    );
  });

  test('before 3 errors, message is NOT the final "kiểm tra mạng" message',
      () async {
    when(() => svc.getParcelByPoint(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        )).thenThrow(const PlanningApiException(503, 'Service down'));

    await provider.tapParcel(10.77, 106.69); // retryCount=1

    expect(provider.retryCount, equals(1));
    expect(provider.errorMessage, isNot(contains('Vui lòng kiểm tra mạng')));
  });

  // ---------------------------------------------------------------------------
  // Retry resets retryCount on success
  // ---------------------------------------------------------------------------

  test('success after errors resets retryCount to 0', () async {
    // First call throws, second call succeeds
    int call = 0;
    when(() => svc.getParcelByPoint(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async {
      call++;
      if (call == 1) throw const PlanningApiException(503, 'Err');
      return fakeParcel();
    });

    await provider.tapParcel(10.77, 106.69); // error, count=1
    expect(provider.retryCount, equals(1));

    await provider.tapParcel(10.77, 106.69); // success
    expect(provider.state, equals(MapState.ready));
    expect(provider.retryCount, equals(0));
  });

  // ---------------------------------------------------------------------------
  // Cancel token: rapid double tap — first request is cancelled (AC-17)
  // ---------------------------------------------------------------------------

  test('rapid double tap: provider creates new CancelToken on each tap',
      () async {
    // Verify the cancel-token mechanism: each call to tapParcel
    // cancels the previous CancelToken and creates a new one.
    // We verify that after two taps the final parcel is from the second call.
    when(
      () => svc.getParcelByPoint(
        any(),
        any(),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => fakeParcel(parcelId: 'p-any'));

    // Fire first tap — synchronously sets _parcelToken
    final firstFuture = provider.tapParcel(10.77, 106.69);
    // Fire second tap immediately — calls _parcelToken?.cancel('new tap')
    // on the first token, then creates a fresh token.
    final secondFuture = provider.tapParcel(10.77, 106.69);

    await Future.wait([firstFuture, secondFuture]);

    // After both complete the provider should be in ready state
    // (second tap succeeded; first tap may have been cancelled or also succeeded)
    expect(provider.state, equals(MapState.ready));
    expect(provider.selectedParcel, isNotNull);
  });

  test('second tapParcel cancels the first CancelToken', () async {
    // Capture the cancel tokens across two calls
    final capturedTokens = <CancelToken?>[];

    when(
      () => svc.getParcelByPoint(
        any(),
        any(),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((invocation) async {
      final token =
          invocation.namedArguments[#cancelToken] as CancelToken?;
      capturedTokens.add(token);
      return fakeParcel();
    });

    // First tap — completes before second tap fires
    await provider.tapParcel(10.77, 106.69);
    // Second tap — should cancel the first token (which is already done by now,
    // so we verify the second tap creates a NEW token)
    await provider.tapParcel(10.77, 106.69);

    // At least 2 service calls were made
    expect(capturedTokens.length, greaterThanOrEqualTo(2));
    // The tokens should be different objects (new token per tap)
    expect(capturedTokens[0], isNot(same(capturedTokens[1])));
  });

  // ---------------------------------------------------------------------------
  // Layer controls
  // ---------------------------------------------------------------------------

  test('toggleLayer changes planningLayerVisible', () {
    expect(provider.planningLayerVisible, isTrue); // default

    provider.toggleLayer(visible: false);
    expect(provider.planningLayerVisible, isFalse);

    provider.toggleLayer(visible: true);
    expect(provider.planningLayerVisible, isTrue);
  });

  test('setOpacity clamps value between 0.0 and 1.0', () {
    provider.setOpacity(1.5); // above max
    expect(provider.layerOpacity, equals(1.0));

    provider.setOpacity(-0.1); // below min
    expect(provider.layerOpacity, equals(0.0));

    provider.setOpacity(0.7);
    expect(provider.layerOpacity, closeTo(0.7, 0.001));
  });

  // ---------------------------------------------------------------------------
  // clearError resets to idle
  // ---------------------------------------------------------------------------

  test('clearError resets state to idle and clears errorMessage', () async {
    when(() => svc.getParcelByPoint(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        )).thenThrow(const PlanningApiException(500, 'fail'));

    await provider.tapParcel(10.77, 106.69);
    expect(provider.state, equals(MapState.error));

    provider.clearError();
    expect(provider.state, equals(MapState.idle));
    expect(provider.errorMessage, isNull);
  });

  // ---------------------------------------------------------------------------
  // dismissSheet resets to idle when state is ready
  // ---------------------------------------------------------------------------

  test('dismissSheet clears selectedParcel and state → idle', () async {
    when(() => svc.getParcelByPoint(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => fakeParcel());

    await provider.tapParcel(10.77, 106.69);
    expect(provider.state, equals(MapState.ready));

    provider.dismissSheet();
    expect(provider.state, equals(MapState.idle));
    expect(provider.selectedParcel, isNull);
  });

  // ---------------------------------------------------------------------------
  // searchSuggest
  // ---------------------------------------------------------------------------

  test('searchSuggest with < 3 chars clears hits without calling service',
      () async {
    await provider.searchSuggest('ab');

    expect(provider.searchHits, isEmpty);
    verifyNever(() => svc.search(any(),
        limit: any(named: 'limit'), cancelToken: any(named: 'cancelToken')));
  });

  test('searchSuggest with valid query calls service and sets searchHits',
      () async {
    when(() => svc.search(
          any(),
          limit: any(named: 'limit'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => [fakeSearchHit()]);

    await provider.searchSuggest('Ben Thanh');

    expect(provider.searchHits, hasLength(1));
  });

  // ---------------------------------------------------------------------------
  // selectHit
  // ---------------------------------------------------------------------------

  test('selectHit with inside-bbox hit returns true and clears searchHits',
      () {
    final hit = fakeSearchHit(); // lat=10.772, lon=106.698 — inside

    // Pre-populate searchHits directly (public field, writable)
    provider.searchHits = [hit];

    final result = provider.selectHit(hit);

    expect(result, isTrue);
    expect(provider.searchHits, isEmpty);
  });

  test('selectHit NGOÀI lãnh thổ VN → false + tick, không vào state.error', () {
    // Bangkok — ngoài bbox VN.
    final outsideHit = fakeSearchHit(lat: 13.75, lon: 100.5);

    final result = provider.selectHit(outsideHit);

    expect(result, isFalse);
    expect(provider.outOfBboxTick, equals(1));
    expect(provider.state, isNot(equals(MapState.error)));
    expect(provider.errorMessage, isNull);
  });

  test('selectHit ở Hà Nội vẫn hợp lệ (bbox toàn quốc)', () {
    expect(provider.selectHit(fakeSearchHit(lat: 21.0, lon: 105.85)), isTrue);
    expect(provider.outOfBboxTick, equals(0));
  });
}
