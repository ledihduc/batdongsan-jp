import 'dart:convert';

// Dùng chung backend lưu trữ với SessionService (web: localStorage, native:
// secure storage) — không thêm dependency mới.
import '_session_storage_io.dart'
    if (dart.library.html) '_session_storage_web.dart'
    as backend;

/// Lịch sử tìm kiếm gần đây (cục bộ, chưa đồng bộ server). Mới nhất lên đầu,
/// khử trùng, giới hạn [_cap].
class RecentSearchService {
  RecentSearchService._();
  static final RecentSearchService instance = RecentSearchService._();

  static const _key = 'recent_searches';
  static const _cap = 10;

  Future<List<String>> getAll() async {
    try {
      final raw = await backend.readToken(_key);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw);
      if (list is List) return list.whereType<String>().toList();
    } catch (_) {}
    return [];
  }

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final list = await getAll();
    list.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    list.insert(0, q);
    await _save(list.take(_cap).toList());
  }

  Future<void> remove(String query) async {
    final list = await getAll();
    list.removeWhere((e) => e.toLowerCase() == query.trim().toLowerCase());
    await _save(list);
  }

  Future<void> clear() async {
    try {
      await backend.deleteToken(_key);
    } catch (_) {}
  }

  Future<void> _save(List<String> list) async {
    try {
      await backend.writeToken(_key, jsonEncode(list));
    } catch (_) {}
  }
}
