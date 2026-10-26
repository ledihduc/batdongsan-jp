import 'package:flutter/material.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/services/api_client.dart';

class WishlistProvider with ChangeNotifier {
  final ApiClient _api = const ApiClient();

  final Set<int> _favoritedIds = {};
  List<HouseModel> _items = [];
  bool _isLoading = false;

  Set<int> get favoritedIds => _favoritedIds;
  List<HouseModel> get items => _items;
  bool get isLoading => _isLoading;

  bool isFavorited(int houseId) => _favoritedIds.contains(houseId);

  Future<void> fetch(int userId) async {
    // userId param giữ lại trong signature để callers không phải đổi, nhưng
    // backend lấy user_id từ JWT sub (chặn IDOR — xem wishlists router).
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get('/api/wishlists');
      final list = List<Map<String, dynamic>>.from(
          res['wishlists'] as List? ?? const []);
      _items = list
          .map((m) => HouseModel.fromMap(
                m,
                images: List<String>.from(m['images'] as List? ?? const []),
                amenities:
                    List<String>.from(m['amenities'] as List? ?? const []),
              ))
          .toList();
      _favoritedIds
        ..clear()
        ..addAll(_items.map((h) => h.id!));
    } catch (e) {
      debugPrint('Fetch wishlist error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggle(int userId, HouseModel house) async {
    final id = house.id!;
    final wasFav = _favoritedIds.contains(id);

    // Optimistic update
    if (wasFav) {
      _favoritedIds.remove(id);
      _items.removeWhere((h) => h.id == id);
    } else {
      _favoritedIds.add(id);
      _items.insert(0, house);
    }
    notifyListeners();

    try {
      if (wasFav) {
        await _api.delete('/api/wishlists', queryParameters: {'houseId': id});
      } else {
        // Backend lấy user_id từ JWT sub — chỉ cần house_id.
        await _api.post('/api/wishlists', body: {'house_id': id});
      }
    } catch (e) {
      // Revert on failure
      if (wasFav) {
        _favoritedIds.add(id);
        _items.insert(0, house);
      } else {
        _favoritedIds.remove(id);
        _items.removeWhere((h) => h.id == id);
      }
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    _favoritedIds.clear();
    _items = [];
    notifyListeners();
  }
}
