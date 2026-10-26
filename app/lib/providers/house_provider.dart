import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/core/permissions/role_guard.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/data/repositories/api_house_repository.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/geo_location_service.dart';
import 'package:house_booking/domain/repositories/i_house_repository.dart';

/// Chế độ tìm kiếm — quyết định endpoint fetch: duyệt thường (text),
/// tìm theo địa danh (geocode), hoặc quanh vị trí GPS.
enum SearchMode { browse, place, nearby }

class HouseProvider with ChangeNotifier implements UserScoped {
  final IHouseRepository _houseRepository = ApiHouseRepository();
  // Repo cụ thể cho các truy vấn geo (ngoài interface IHouseRepository).
  final ApiHouseRepository _geoRepo = ApiHouseRepository();
  final ApiClient _client = const ApiClient();
  final GeoLocationService _geo = const GeoLocationService();
  // Đã tự động lấy vị trí cho phiên này chưa (chỉ thử 1 lần khi mở feed).
  bool _autoLocateTried = false;

  List<HouseModel> _houses = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _amenities = [];
  
  bool _isLoading = false;
  HouseModel? _selectedHouse;

  // Filter States
  String _searchQuery = '';
  int? _selectedCategoryId;
  double _minPrice = 0.0;
  double _maxPrice = 50000000.0; // 50M
  double _minArea = 0.0;
  double _maxArea = 500.0;

  // Transaction-type + ward filters (D1, D10)
  String? _transactionType; // null = both; 'rent' | 'sale'
  String? _wardSlug; // canonical ward slug; null = no filter (D10)

  // ── Tìm kiếm nâng cao (0071) ────────────────────────────────────────────
  List<int> _selectedCategoryIds = const []; // F1: nhiều loại hình
  List<String> _directions = const [];       // F2: hướng nhà (slug)
  int _minBedrooms = 0;                       // số phòng ngủ tối thiểu (0 = mọi)
  double _minRating = 0;                      // F3: điểm đánh giá tối thiểu
  int _minQualityStar = 0;                    // F3: sao chất lượng tối thiểu
  List<String> _selectedAmenities = const []; // F3: tiện ích bắt buộc
  bool _trustedOnly = false;                  // F3: chỉ nhà Uy tín
  String _sort = '';                          // '' | rating | trust | price_asc | price_desc

  // Geo-search state — gộp từ màn Bộ lọc (địa danh / quanh đây + bán kính).
  SearchMode _mode = SearchMode.browse;
  double _radiusKm = 3.0;
  double? _nearLat;
  double? _nearLng;
  String _placeQuery = '';
  String? _placeDisplayName;

  // Trạng thái lỗi tải danh sách — để UI phân biệt "lỗi mạng" vs "rỗng thật".
  bool _loadError = false;

  List<HouseModel> get houses => _houses;
  List<Map<String, dynamic>> get categories => _categories;

  /// Nhóm master đang lọc (rỗng = tất cả). Lọc theo NHÓM là bộ lọc thô nhất mà
  /// người dùng hiểu ngay ("tôi cần chỗ ở dài hạn" / "thuê ngắn ngày" / "mặt
  /// bằng kinh doanh"), nên đứng TRƯỚC bộ lọc loại hình.
  String _selectedGroup = '';
  String get selectedGroup => _selectedGroup;

  /// Loại hình thuộc nhóm đang lọc (rỗng = mọi loại). Danh mục chưa có nhóm
  /// (backend cũ) coi như dài hạn để không biến mất khỏi danh sách.
  List<Map<String, dynamic>> get categoriesInSelectedGroup {
    if (_selectedGroup.isEmpty) return _categories;
    return _categories.where((c) {
      final g = (c['group_key'] as String?) ?? '';
      return g.isEmpty ? _selectedGroup == 'stay_long' : g == _selectedGroup;
    }).toList();
  }

  /// CHỈ dùng cho test: bơm danh mục mà không đi mạng. Không gọi trong code
  /// sản phẩm (nạp thật đi qua [fetchInitialData]).
  @visibleForTesting
  void debugSetCategories(List<Map<String, dynamic>> cats) {
    _categories = List<Map<String, dynamic>>.from(cats);
  }

  void selectGroup(String groupKey) {
    // Chạm lại nhóm đang chọn = bỏ lọc (giống hành vi chip ở các màn khác).
    _selectedGroup = _selectedGroup == groupKey ? '' : groupKey;
    // Loại hình cũ có thể không thuộc nhóm mới → bỏ, tránh lọc ra rỗng mà
    // người dùng không hiểu vì sao.
    _selectedCategoryId = null;
    fetchHouses();
    notifyListeners();
  }
  List<Map<String, dynamic>> get amenities => _amenities;
  bool get isLoading => _isLoading;
  bool get loadError => _loadError;
  HouseModel? get selectedHouse => _selectedHouse;

  // Filter getters
  String get searchQuery => _searchQuery;
  int? get selectedCategoryId => _selectedCategoryId;
  double get minPrice => _minPrice;
  double get maxPrice => _maxPrice;
  double get minArea => _minArea;
  double get maxArea => _maxArea;
  String? get transactionType => _transactionType;
  String? get wardSlug => _wardSlug;
  List<int> get selectedCategoryIds => _selectedCategoryIds;
  List<String> get directions => _directions;
  int get minBedrooms => _minBedrooms;
  double get minRating => _minRating;
  int get minQualityStar => _minQualityStar;
  List<String> get selectedAmenities => _selectedAmenities;
  bool get trustedOnly => _trustedOnly;
  String get sort => _sort;
  SearchMode get searchMode => _mode;
  double get radiusKm => _radiusKm;
  String get placeQuery => _placeQuery;
  String? get placeDisplayName => _placeDisplayName;
  bool get isGeoMode => _mode != SearchMode.browse;
  double? get nearLat => _nearLat;
  double? get nearLng => _nearLng;

  Future<void> fetchInitialData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _categories = await _houseRepository.getCategories();
      _amenities = await _houseRepository.getAmenities();
      await _tryAutoLocate();
      await fetchHouses();
    } catch (e) {
      print('Fetch initial data error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// LUÔN thử lấy vị trí khi mở feed → chuyển sang chế độ "quanh đây" để backend
  /// xếp GẦN + UY TÍN (sort=near_trust). Nếu từ chối/không có GPS → giữ duyệt
  /// thường nhưng ưu tiên chủ uy tín (sort=rating). Chỉ thử 1 lần / phiên và chỉ
  /// khi người dùng chưa tự chọn chế độ tìm kiếm nào khác.
  Future<void> _tryAutoLocate() async {
    if (_autoLocateTried || _mode != SearchMode.browse) return;
    _autoLocateTried = true;
    try {
      final r = await _geo.getCurrentLocation();
      if (r.isOk && r.lat != null && r.lng != null) {
        _nearLat = r.lat;
        _nearLng = r.lng;
        _radiusKm = 25.0; // rộng để feed quanh đây không bị rỗng
        _mode = SearchMode.nearby;
      } else {
        _sort = 'rating'; // không định vị được → đề xuất theo uy tín chủ
      }
    } catch (_) {
      _sort = 'rating';
    }
  }

  static const int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> fetchHouses() async {
    _loadError = false;
    try {
      if (_mode == SearchMode.nearby && _nearLat != null && _nearLng != null) {
        _houses = await _geoRepo.getHousesNearby(
          lat: _nearLat!,
          lng: _nearLng!,
          radiusKm: _radiusKm,
          transactionType: _transactionType,
          categoryId: _selectedCategoryId,
          minPrice: _minPrice,
          maxPrice: _maxPrice,
          minArea: _minArea,
          maxArea: _maxArea,
          limit: _pageSize,
          offset: 0,
        );
      } else if (_mode == SearchMode.place && _placeQuery.isNotEmpty) {
        final res = await _geoRepo.searchHousesNearPlace(
          place: _placeQuery,
          radiusKm: _radiusKm,
          transactionType: _transactionType,
          categoryId: _selectedCategoryId,
          minPrice: _minPrice,
          maxPrice: _maxPrice,
          minArea: _minArea,
          maxArea: _maxArea,
          limit: _pageSize,
          offset: 0,
        );
        _placeDisplayName = res.place?['display_name'] as String?;
        // Lưu toạ độ tâm để loadMore không phải geocode lại.
        _nearLat = (res.place?['lat'] as num?)?.toDouble();
        _nearLng = (res.place?['lng'] as num?)?.toDouble();
        _houses = res.houses;
      } else {
        _houses = await _houseRepository.getHouses(
          query: _searchQuery,
          categoryId: _selectedCategoryId,
          minPrice: _minPrice,
          maxPrice: _maxPrice,
          minArea: _minArea,
          maxArea: _maxArea,
          transactionType: _transactionType,
          group: _selectedGroup,
          wardSlug: _wardSlug,
          categoryIds: _selectedCategoryIds,
          directions: _directions,
          minBedrooms: _minBedrooms,
          minRating: _minRating,
          minQualityStar: _minQualityStar,
          amenities: _selectedAmenities,
          isTrusted: _trustedOnly ? true : null,
          sort: _sort,
          limit: _pageSize,
          offset: 0,
        );
      }
      _hasMore = _houses.length >= _pageSize;
    } catch (e) {
      _loadError = true;
      print('Fetch houses error: $e');
    }
    notifyListeners();
  }

  Future<void> loadMoreHouses() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final List<HouseModel> more;
      if (_mode != SearchMode.browse && _nearLat != null && _nearLng != null) {
        more = await _geoRepo.getHousesNearby(
          lat: _nearLat!,
          lng: _nearLng!,
          radiusKm: _radiusKm,
          transactionType: _transactionType,
          categoryId: _selectedCategoryId,
          minPrice: _minPrice,
          maxPrice: _maxPrice,
          minArea: _minArea,
          maxArea: _maxArea,
          limit: _pageSize,
          offset: _houses.length,
        );
      } else {
        more = await _houseRepository.getHouses(
          query: _searchQuery,
          categoryId: _selectedCategoryId,
          minPrice: _minPrice,
          maxPrice: _maxPrice,
          minArea: _minArea,
          maxArea: _maxArea,
          transactionType: _transactionType,
          group: _selectedGroup,
          wardSlug: _wardSlug,
          categoryIds: _selectedCategoryIds,
          directions: _directions,
          minBedrooms: _minBedrooms,
          minRating: _minRating,
          minQualityStar: _minQualityStar,
          amenities: _selectedAmenities,
          isTrusted: _trustedOnly ? true : null,
          sort: _sort,
          limit: _pageSize,
          offset: _houses.length,
        );
      }
      if (more.isEmpty || more.length < _pageSize) {
        _hasMore = false;
      }
      _houses.addAll(more);
    } catch (e) {
      print('Load more error: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> selectHouse(int id) async {
    _isLoading = true;
    _selectedHouse = null;
    notifyListeners();

    try {
      _selectedHouse = await _houseRepository.getHouseById(id);
    } catch (e) {
      print('Select house error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Filter setters
  void setSearchQuery(String query) {
    _searchQuery = query;
    _mode = SearchMode.browse; // gõ tìm tự do → thoát chế độ geo
    fetchHouses();
  }

  void selectCategory(int? categoryId) {
    if (_selectedCategoryId == categoryId) {
      _selectedCategoryId = null; // Toggle off
    } else {
      _selectedCategoryId = categoryId;
    }
    fetchHouses();
  }

  void updateFilters({
    required double minPrice,
    required double maxPrice,
    required double minArea,
    required double maxArea,
  }) {
    _minPrice = minPrice;
    _maxPrice = maxPrice;
    _minArea = minArea;
    _maxArea = maxArea;
    fetchHouses();
  }

  /// Áp dụng đồng thời bộ lọc + chế độ tìm theo vị trí (gọi từ màn Bộ lọc).
  /// [nearLat]/[nearLng] cần cho mode nearby; [placeQuery] cho mode place.
  Future<void> applySearch({
    required double minPrice,
    required double maxPrice,
    required double minArea,
    required double maxArea,
    int? categoryId,
    SearchMode mode = SearchMode.browse,
    double? nearLat,
    double? nearLng,
    String placeQuery = '',
    double radiusKm = 3.0,
    // Tìm kiếm nâng cao (0071)
    List<int>? categoryIds,
    List<String>? directions,
    int? minBedrooms,
    double? minRating,
    int? minQualityStar,
    List<String>? amenities,
    bool? trustedOnly,
    String? sort,
  }) async {
    _minPrice = minPrice;
    _maxPrice = maxPrice;
    _minArea = minArea;
    _maxArea = maxArea;
    _selectedCategoryId = categoryId;
    _selectedCategoryIds = categoryIds ?? const [];
    _directions = directions ?? const [];
    _minBedrooms = minBedrooms ?? 0;
    _minRating = minRating ?? 0;
    _minQualityStar = minQualityStar ?? 0;
    _selectedAmenities = amenities ?? const [];
    _trustedOnly = trustedOnly ?? false;
    _sort = sort ?? '';
    _mode = mode;
    _radiusKm = radiusKm;
    _nearLat = nearLat;
    _nearLng = nearLng;
    _placeQuery = placeQuery;
    _placeDisplayName = null;
    _isLoading = true;
    notifyListeners();
    await fetchHouses();
    _isLoading = false;
    notifyListeners();
  }

  /// Sets transaction-type filter ('rent' | 'sale' | null = both).
  void setTransactionType(String? value) {
    _transactionType = value;
    notifyListeners();
    fetchHouses();
  }

  /// Sets ward-slug filter for Phase-2 ward-level search (D10).
  void setWardSlug(String? slug) {
    _wardSlug = slug;
    notifyListeners();
    fetchHouses();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategoryId = null;
    _minPrice = 0.0;
    _maxPrice = 50000000.0;
    _minArea = 0.0;
    _maxArea = 500.0;
    _mode = SearchMode.browse;
    _radiusKm = 3.0;
    _nearLat = null;
    _nearLng = null;
    _placeQuery = '';
    _placeDisplayName = null;
    _transactionType = null;
    _wardSlug = null;
    // Nhóm filter nâng cao (0071) trước đây KHÔNG được xoá ở đây — bấm "Xoá
    // lọc" xong danh sách vẫn bị lọc ngầm theo hướng nhà/rating/tiện ích.
    _selectedCategoryIds = const [];
    _directions = const [];
    _minBedrooms = 0;
    _minRating = 0;
    _minQualityStar = 0;
    _selectedAmenities = const [];
    _trustedOnly = false;
    _sort = '';
    fetchHouses();
  }

  /// Result of a house registration attempt.
  /// [ok] tells the UI whether the post succeeded.
  /// [newToken] is set when the backend auto-upgraded the caller to host on
  /// their first listing — UI should save it and refresh the auth session.
  /// [status] là trạng thái tin server gán (`published`/`pending_review`) →
  /// UI báo đúng: tin lên ngay vs tin đang chờ duyệt (không báo "thành công" giả).
  Future<({bool ok, String? newToken, String? status})> registerNewHouse(
      HouseModel house) async {
    try {
      final res = await _houseRepository.createHouse(house);
      await fetchHouses();
      return (ok: true, newToken: res.token, status: res.status);
    } catch (e) {
      print('Register new house error: $e');
      return (ok: false, newToken: null, status: null);
    }
  }

  /// "Đóng 1 phòng" — host cho thuê ngoài app, giảm available_units đi 1.
  /// Backend tự lo: notify guest đang chờ + đánh dấu booking thành lost.
  Future<bool> closeOneUnit(int houseId) async {
    try {
      await _client.post('/api/houses/$houseId/close-unit');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void resetUserScope() {
    _houses = [];
    _categories = [];
    _amenities = [];
    _isLoading = false;
    _selectedHouse = null;
    _searchQuery = '';
    _selectedCategoryId = null;
    _minPrice = 0.0;
    _maxPrice = 50000000.0;
    _minArea = 0.0;
    _maxArea = 500.0;
    _mode = SearchMode.browse;
    _radiusKm = 3.0;
    _nearLat = null;
    _nearLng = null;
    _placeQuery = '';
    _placeDisplayName = null;
    _transactionType = null;
    _wardSlug = null;
    _hasMore = true;
    _isLoadingMore = false;
    _myHouses = [];
    _myHousesLoading = false;
    _adminHouses = [];
    _adminLoading = false;
    notifyListeners();
  }

  Future<bool> deleteHouse(int id, {UserModel? actor}) async {
    if (actor != null && !RoleGuard.canHost(actor)) {
      throw const PermissionDeniedException(
        action: 'deleteHouse',
        requiredRole: 'host',
      );
    }
    final ok = await _houseRepository.deleteHouse(id);
    if (ok) {
      _houses.removeWhere((h) => h.id == id);
      notifyListeners();
    }
    return ok;
  }

  // Tin của chính chủ nhà — bất kể status (pending/approved/rejected)
  List<HouseModel> _myHouses = [];
  bool _myHousesLoading = false;
  List<HouseModel> get myHouses => _myHouses;
  bool get myHousesLoading => _myHousesLoading;

  Future<void> fetchMyHouses(int hostId) async {
    _myHousesLoading = true;
    notifyListeners();
    try {
      _myHouses = await _houseRepository.getHouses(
        hostId: hostId,
        status: 'all',
      );
    } catch (_) {} finally {
      _myHousesLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateHouse(HouseModel updated) async {
    final ok = await _houseRepository.updateHouse(updated);
    if (ok) {
      final i = _myHouses.indexWhere((h) => h.id == updated.id);
      if (i >= 0) _myHouses[i] = updated;
      final j = _houses.indexWhere((h) => h.id == updated.id);
      if (j >= 0) _houses[j] = updated;
      notifyListeners();
    }
    return ok;
  }

  // Admin-only: load houses by status (pending/approved/rejected/all)
  List<HouseModel> _adminHouses = [];
  bool _adminLoading = false;
  List<HouseModel> get adminHouses => _adminHouses;
  bool get adminLoading => _adminLoading;

  Future<void> fetchHousesByStatus(String status) async {
    _adminLoading = true;
    notifyListeners();
    try {
      _adminHouses = await _geoRepo.getAdminHouses(status);
    } catch (e) {
      // ignore
    } finally {
      _adminLoading = false;
      notifyListeners();
    }
  }

  /// Admin duyệt/từ chối tin qua endpoint moderation.
  /// [status] 'approved' → approve; 'rejected' → reject (cần [reason]).
  Future<bool> setHouseStatus(int id, String status, {String? reason}) async {
    final action = status == 'approved' ? 'approve' : 'reject';
    try {
      await _geoRepo.moderateHouse(id, action, reason: reason);
      _adminHouses.removeWhere((h) => h.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      print('Moderate house error: $e');
      return false;
    }
  }
}
