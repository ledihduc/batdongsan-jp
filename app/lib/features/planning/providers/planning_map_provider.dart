import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:house_booking/data/models/planning_parcel_model.dart';
import 'package:house_booking/data/models/planning_search_hit_model.dart';
import 'package:house_booking/data/models/province_model.dart';
import 'package:house_booking/data/services/planning_service.dart';
import 'package:house_booking/features/planning/utils/bbox_guard.dart';

/// Trạng thái bản đồ quy hoạch (state machine đơn giản).
enum MapState { idle, loading, ready, error }

/// Provider quản lý toàn bộ state của PlanningMapScreen.
/// Tách biệt logic khỏi UI — UI chỉ đọc state và gọi method.
class PlanningMapProvider extends ChangeNotifier {
  PlanningMapProvider(this._svc);

  final PlanningService _svc;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  MapState state = MapState.idle;
  ParcelDetail? selectedParcel;
  String? errorMessage;

  /// Counter tăng mỗi lần tap rơi vào "không có parcel".
  /// Map screen listen counter này để show transient SnackBar.
  /// Tách khỏi state.error để tránh ErrorCard modal kẹt overlay.
  int noResultTick = 0;

  /// Counter tăng mỗi lần tap/search rơi ra ngoài bbox VN.
  /// Cùng pattern noResultTick — transient SnackBar, không kẹt overlay.
  int outOfBboxTick = 0;

  /// Số lần retry liên tiếp cho getParcelByPoint.
  int retryCount = 0;

  /// Hiển thị lớp quy hoạch vector tile.
  bool planningLayerVisible = true;

  /// Độ trong suốt lớp quy hoạch (0.0 – 1.0).
  double layerOpacity = 0.5;

  /// Kết quả gợi ý tìm kiếm địa chỉ (Nominatim).
  List<SearchHit> searchHits = [];

  /// Kết quả gợi ý tìm kiếm tỉnh (provinces local).
  List<Province> provinceHits = [];

  /// Tỉnh đang được chọn — driver cho raster TileLayer overlay.
  /// null = không hiện overlay quy hoạch (chỉ base map).
  Province? selectedProvince;

  CancelToken? _parcelToken;
  CancelToken? _searchToken;
  CancelToken? _bboxToken;

  /// FeatureCollection của parcels trong viewport hiện tại (web fallback).
  /// Trên native, để rỗng — vector tile layer tự lo render.
  List<Map<String, dynamic>> bboxFeatures = const [];

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Tap vào bản đồ tại [lat], [lng] để lấy thông tin thửa đất (AC-02, AC-06, AC-17).
  Future<void> tapParcel(double lat, double lng) async {
    // Cancel request trước — tránh race condition khi tap nhanh (AC-17).
    _parcelToken?.cancel('new tap');
    _parcelToken = CancelToken();

    // Kiểm tra ngoài bbox VN (AC-06) — transient, không block UI.
    if (!BboxGuard.isInsideVN(lat, lng)) {
      outOfBboxTick++;
      notifyListeners();
      return;
    }

    state = MapState.loading;
    selectedParcel = null;
    notifyListeners();

    try {
      final parcel = await _svc.getParcelByPoint(
        lat,
        lng,
        cancelToken: _parcelToken,
      );

      if (parcel == null) {
        // Không có thửa tại điểm này — KHÔNG phải lỗi, là kết quả bình thường.
        // Reset về idle + tăng tick để UI hiển thị SnackBar transient.
        state = MapState.idle;
        errorMessage = null;
        retryCount = 0;
        noResultTick++;
      } else {
        selectedParcel = parcel;
        state = MapState.ready;
        retryCount = 0;
        errorMessage = null;
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return; // bị cancel — không cần update UI
      retryCount++;
      errorMessage = retryCount >= 3
          ? 'Vui lòng kiểm tra mạng hoặc thử lại sau.'
          : (e.message ?? 'Lỗi mạng. Thử lại?');
      state = MapState.error;
    } on PlanningApiException catch (e) {
      retryCount++;
      errorMessage = retryCount >= 3
          ? 'Vui lòng kiểm tra mạng hoặc thử lại sau.'
          : e.message;
      state = MapState.error;
    } catch (e) {
      retryCount++;
      errorMessage = retryCount >= 3
          ? 'Vui lòng kiểm tra mạng hoặc thử lại sau.'
          : 'Lỗi không xác định.';
      state = MapState.error;
    }

    notifyListeners();
  }

  /// Tìm kiếm địa điểm — debounce & cancel xử lý ở ProvincePicker bottom sheet.
  /// Bỏ qua query ngắn hơn 3 ký tự.
  Future<void> searchSuggest(String q) async {
    if (q.length < 3) {
      searchHits = [];
      notifyListeners();
      return;
    }

    // Cancel request search trước.
    _searchToken?.cancel('new search');
    _searchToken = CancelToken();

    try {
      // Không log q kèm user_id — privacy.
      final hits = await _svc.search(q, cancelToken: _searchToken);
      searchHits = hits;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      searchHits = [];
    } on PlanningApiException catch (_) {
      searchHits = [];
    } catch (_) {
      searchHits = [];
    }

    notifyListeners();
  }

  /// Reverse geocode 1 điểm -> địa chỉ.
  Future<SearchHit?> reverseGeocode(double lat, double lng) async {
    try {
      return await _svc.reverseGeocode(lat, lng);
    } catch (_) {
      return null;
    }
  }

  /// Chọn một kết quả tìm kiếm — bbox check trước khi chấp nhận (AC-06).
  /// Trả về true nếu hợp lệ, false nếu ngoài bbox.
  bool selectHit(SearchHit hit) {
    searchHits = [];
    notifyListeners();

    if (!BboxGuard.isInsideVN(hit.lat, hit.lon)) {
      outOfBboxTick++;
      notifyListeners();
      return false;
    }
    return true;
  }

  /// Fetch parcels theo bbox cho web fallback (PolygonLayer).
  /// Map screen gọi sau khi viewport ổn định (debounced).
  Future<void> fetchParcelsInBbox({
    required double west,
    required double south,
    required double east,
    required double north,
  }) async {
    _bboxToken?.cancel('new bbox');
    _bboxToken = CancelToken();
    try {
      final fc = await _svc.getParcelsInBbox(
        west: west,
        south: south,
        east: east,
        north: north,
        cancelToken: _bboxToken,
      );
      final feats = (fc['features'] as List?) ?? const [];
      bboxFeatures = feats
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      notifyListeners();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      // Bbox fetch lỗi không phải critical — giữ list cũ.
    } catch (_) {
      // ignore — overlay là best-effort
    }
  }

  /// Search tỉnh local (qua backend cache JSON 63 tỉnh).
  /// Min 1 ký tự, trả tỉnh match prefix trước contains.
  /// Empty query → load full 63 tỉnh để picker hiển thị danh sách đầy đủ.
  Future<void> searchProvinces(String q) async {
    final trimmed = q.trim();
    try {
      provinceHits = trimmed.isEmpty
          ? await _svc.listProvinces()
          : await _svc.searchProvinces(trimmed, limit: 8);
    } catch (_) {
      provinceHits = [];
    }
    notifyListeners();
  }

  /// Cache danh sách tỉnh (dùng lại khi dò tỉnh theo tâm bản đồ mỗi lần lăn —
  /// tránh gọi mạng lặp lại).
  List<Province>? _provinceCache;

  Future<List<Province>> _allProvinces() async =>
      _provinceCache ??= await _svc.listProvinces();

  /// Tìm tỉnh có bbox bao [lat,lng], ưu tiên tỉnh `has_tiles=true`.
  Province? _provinceAt(double lat, double lng, List<Province> all) {
    Province? bestWithTiles;
    Province? bestAny;
    for (final p in all) {
      final inside =
          lat >= p.latSw && lat <= p.latNe && lng >= p.lngSw && lng <= p.lngNe;
      if (!inside) continue;
      bestAny ??= p;
      if (p.hasTiles) {
        bestWithTiles = p;
        break;
      }
    }
    return bestWithTiles ?? bestAny;
  }

  /// Auto-pick tỉnh có bbox bao [lat,lng]. Ưu tiên tỉnh `has_tiles=true`.
  /// Dùng khi mở map mà chưa có province nào được chọn → overlay hiện
  /// luôn thay vì chờ user pick thủ công.
  Future<void> autoSelectProvinceForPoint(double lat, double lng) async {
    if (selectedProvince != null) return;
    try {
      final pick = _provinceAt(lat, lng, await _allProvinces());
      if (pick != null) {
        selectedProvince = pick;
        notifyListeners();
      }
    } catch (_) {
      // Best-effort — không có default cũng không sao.
    }
  }

  /// Dò lại tỉnh theo TÂM bản đồ mỗi khi lăn/di chuyển → tự đổi overlay sang
  /// tỉnh đang xem (thay cho việc bấm chọn thủ công). Giữ nguyên nếu tâm vẫn
  /// nằm trong bbox tỉnh hiện tại (chống nháy ở vùng bbox chồng lấn).
  Future<void> updateProvinceForCenter(double lat, double lng) async {
    final cur = selectedProvince;
    if (cur != null &&
        cur.hasTiles &&
        lat >= cur.latSw &&
        lat <= cur.latNe &&
        lng >= cur.lngSw &&
        lng <= cur.lngNe) {
      return; // vẫn trong tỉnh cũ → khỏi đổi
    }
    try {
      final pick = _provinceAt(lat, lng, await _allProvinces());
      if (pick != null && pick.slug != selectedProvince?.slug) {
        selectedProvince = pick;
        notifyListeners();
      }
    } catch (_) {
      // Best-effort.
    }
  }

  /// Set tỉnh active → raster TileLayer URL đổi theo.
  /// [province] = null để tắt overlay.
  void setSelectedProvince(Province? province) {
    selectedProvince = province;
    provinceHits = [];
    notifyListeners();
  }

  /// Toggle hiển thị lớp quy hoạch (AC-05).
  void toggleLayer({required bool visible}) {
    planningLayerVisible = visible;
    notifyListeners();
  }

  /// Thay đổi opacity lớp quy hoạch (AC-05).
  void setOpacity(double v) {
    layerOpacity = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Đóng bottom sheet detail.
  void dismissSheet() {
    selectedParcel = null;
    if (state == MapState.ready) state = MapState.idle;
    notifyListeners();
  }

  /// Thử lại sau lỗi (AC-07).
  void retry(double lat, double lng) {
    tapParcel(lat, lng);
  }

  /// Xóa trạng thái lỗi sau khi user đóng ErrorCard hoặc retry.
  void clearError() {
    errorMessage = null;
    state = MapState.idle;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Cache (AC-14) — defer to P08 settings screen
  // ---------------------------------------------------------------------------
  // TODO(P08): expose clearTileCache() để gọi từ settings screen.
  // vector_map_tiles internal cache: xem StorageCachingTileProvider.

  @override
  void dispose() {
    _parcelToken?.cancel('provider disposed');
    _searchToken?.cancel('provider disposed');
    _bboxToken?.cancel('provider disposed');
    super.dispose();
  }
}
