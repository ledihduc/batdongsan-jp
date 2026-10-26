import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:house_booking/core/config/env.dart';
import 'package:house_booking/data/models/planning_district_model.dart';
import 'package:house_booking/data/models/planning_layer_model.dart';
import 'package:house_booking/data/models/planning_parcel_model.dart';
import 'package:house_booking/data/models/planning_report_model.dart';
import 'package:house_booking/data/models/planning_search_hit_model.dart';
import 'package:house_booking/data/models/province_model.dart';
import 'package:house_booking/data/models/risky_house_model.dart';
import 'package:house_booking/data/services/session_service.dart';

/// Exception rõ ràng cho planning API — tránh leak DioException ra UI.
class PlanningApiException implements Exception {
  final int statusCode;
  final String message;

  /// true khi server trả 429 Too Many Requests.
  final bool isRateLimited;

  const PlanningApiException(
    this.statusCode,
    this.message, {
    this.isRateLimited = false,
  });

  @override
  String toString() => 'PlanningApiException($statusCode): $message';
}

/// Service giao tiếp với backend planning API (/api/planning/*).
/// Dùng Dio để hỗ trợ CancelToken (tránh race condition tap nhanh — AC-17).
class PlanningService {
  PlanningService() : _dio = _buildDio();

  final Dio _dio;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Lấy thông tin thửa đất theo tọa độ.
  /// Trả về null nếu không có thửa tại điểm đó (404) hoặc bị cancel.
  Future<ParcelDetail?> getParcelByPoint(
    double lat,
    double lng, {
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _dio.get(
        '/api/planning/parcels',
        queryParameters: {'lat': lat, 'lng': lng},
        cancelToken: cancelToken,
      );
      if (res.data == null) return null;
      return ParcelDetail.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return null;
      if (e.response?.statusCode == 404) return null;
      throw _toAppException(e);
    }
  }

  /// Danh sách 63 tỉnh/thành VN. Set [onlyWithTiles] = true để filter 17 tỉnh
  /// có raster overlay.
  Future<List<Province>> listProvinces({bool onlyWithTiles = false}) async {
    try {
      final res = await _dio.get(
        '/api/planning/provinces',
        queryParameters: onlyWithTiles ? {'has_tiles': true} : null,
      );
      final list = res.data as List<dynamic>;
      return list
          .map((e) => Province.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _toAppException(e);
    }
  }

  /// Fuzzy search tỉnh theo tên (có/không dấu) hoặc slug.
  Future<List<Province>> searchProvinces(
    String q, {
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _dio.get(
        '/api/planning/provinces/search',
        queryParameters: {'q': q, 'limit': limit},
        cancelToken: cancelToken,
      );
      final list = res.data as List<dynamic>;
      return list
          .map((e) => Province.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return const [];
      throw _toAppException(e);
    }
  }

  /// Fetch parcels intersecting bbox (web fallback — không có vector tiles).
  /// Trả về GeoJSON FeatureCollection raw dạng Map.
  Future<Map<String, dynamic>> getParcelsInBbox({
    required double west,
    required double south,
    required double east,
    required double north,
    int limit = 2000,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _dio.get(
        '/api/planning/parcels/bbox',
        queryParameters: {'bbox': '$west,$south,$east,$north', 'limit': limit},
        cancelToken: cancelToken,
      );
      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return const {'type': 'FeatureCollection', 'features': []};
      }
      throw _toAppException(e);
    }
  }

  /// Lấy chi tiết thửa đất theo ID.
  Future<ParcelDetail> getParcelById(String id) async {
    try {
      final res = await _dio.get('/api/planning/parcels/$id');
      return ParcelDetail.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toAppException(e);
    }
  }

  /// Danh sách quận/huyện có dữ liệu quy hoạch.
  Future<List<DistrictItem>> listDistricts() async {
    try {
      final res = await _dio.get('/api/planning/districts');
      final list = res.data as List<dynamic>;
      return list
          .map((e) => DistrictItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _toAppException(e);
    }
  }

  /// Danh sách layer vector tile có sẵn.
  Future<List<PlanningLayer>> listLayers() async {
    try {
      final res = await _dio.get('/api/planning/layers');
      final list = res.data as List<dynamic>;
      return list
          .map((e) => PlanningLayer.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _toAppException(e);
    }
  }

  /// Tìm kiếm địa điểm qua Nominatim proxy.
  /// [cancelToken] cho phép hủy khi user gõ tiếp (debounce + cancel).
  Future<List<SearchHit>> search(
    String q, {
    int limit = 10,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _dio.get(
        '/api/planning/search',
        queryParameters: {'q': q, 'limit': limit},
        cancelToken: cancelToken,
      );
      final list = res.data as List<dynamic>;
      return list
          .map((e) => SearchHit.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return [];
      throw _toAppException(e);
    }
  }

  /// Reverse geocode 1 điểm -> địa chỉ.
  Future<SearchHit?> reverseGeocode(double lat, double lng) async {
    try {
      final res = await _dio.get(
        '/api/geo/reverse',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      final data = res.data;
      if (data == null || data['display_name'] == null) return null;
      return SearchHit(
        displayName: data['display_name'] as String,
        lat: lat,
        lon: lng,
        importance: 1.0,
      );
    } on DioException catch (e) {
      throw _toAppException(e);
    }
  }

  /// Gửi báo cáo lỗi dữ liệu thửa đất (dùng model [ParcelReport]).
  /// Giữ backward-compat với P04. Dùng [reportParcelError] cho named params.
  Future<void> reportError(ParcelReport report) async {
    try {
      await _dio.post('/api/planning/report-error', data: report.toJson());
    } on DioException catch (e) {
      throw _toAppException(e);
    }
  }

  /// Gửi báo cáo lỗi dữ liệu thửa đất với named params (US-08).
  /// Convenience wrapper để ReportErrorScreen không phải khởi tạo ParcelReport.
  Future<void> reportParcelError({
    required String parcelId,
    required String reason,
    String? imageUrl,
  }) => reportError(
    ParcelReport(parcelId: parcelId, reason: reason, imageUrl: imageUrl),
  );

  /// Danh sách BDS rủi ro có kiểu dữ liệu (admin only — US-06).
  /// Endpoint trả `{"items": [...]}` hoặc list trực tiếp; handle cả hai.
  /// Throws [PlanningApiException] với statusCode 403 nếu không có quyền admin.
  Future<List<RiskyHouse>> getRiskyHouses() async {
    try {
      final res = await _dio.get('/api/planning/admin/risky-listings');
      final data = res.data;
      // Backend có thể trả list trực tiếp hoặc wrap trong {items: [...]}.
      final List<dynamic> list = (data is Map && data.containsKey('items'))
          ? data['items'] as List<dynamic>
          : data as List<dynamic>;
      return list
          .map((e) => RiskyHouse.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw const PlanningApiException(403, 'Yêu cầu quyền admin');
      }
      throw _toAppException(e);
    }
  }

  /// Danh sách BDS rủi ro (admin only) — raw map, giữ cho backward-compat.
  Future<List<Map<String, dynamic>>> adminRiskyListings() async {
    try {
      final res = await _dio.get('/api/planning/admin/risky-listings');
      final list = res.data as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw _toAppException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static Dio _buildDio() {
    // Browser cấm set `User-Agent` (forbidden header per fetch spec) — chỉ
    // gắn ở native (Android/iOS/desktop) để giữ tracing, web bỏ qua.
    final dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          if (!kIsWeb) 'User-Agent': 'ancu365-flutter/1.0',
        },
      ),
    );

    // Interceptor: inject Bearer token từ SessionService.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SessionService.instance.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

    return dio;
  }

  PlanningApiException _toAppException(DioException e) {
    final statusCode = e.response?.statusCode ?? 0;
    final data = e.response?.data;
    return PlanningApiException(
      statusCode,
      _extractMessage(data) ?? (e.message ?? 'Lỗi không xác định'),
      isRateLimited: statusCode == 429,
    );
  }

  /// Backend trả 3 dạng error body:
  ///   1. FastAPI HTTPException(detail=str) → {"detail": "msg"}
  ///   2. FastAPI HTTPException(detail={code,message}) → {"detail": {"code": "...", "message": "..."}}
  ///   3. unhandled_exception_handler → {"error": {"code": "...", "message": "..."}}
  static String? _extractMessage(dynamic data) {
    if (data is! Map) return null;
    final detail = data['detail'];
    if (detail is String) return detail;
    if (detail is Map && detail['message'] is String) {
      return detail['message'] as String;
    }
    final error = data['error'];
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
    final message = data['message'];
    if (message is String) return message;
    return null;
  }
}
