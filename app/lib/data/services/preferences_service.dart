import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:house_booking/data/models/user_preferences.dart';
import 'package:house_booking/data/services/api_client.dart';
// Dùng CHUNG backend lưu trữ với SessionService/UserPrefsService (localStorage
// trên web, secure storage trên mobile) — không thêm package deps mới.
import '_session_storage_io.dart'
    if (dart.library.html) '_session_storage_web.dart'
    as store;

/// Tăng mỗi khi `defaultWorld` đổi (khảo sát hoặc chỉnh trong Profile).
/// `GuestShell` lắng nghe để đảo thứ tự 2 tab đầu NGAY, không cần mở lại app.
final ValueNotifier<int> defaultWorldRevision = ValueNotifier<int>(0);

/// Lưu & đồng bộ sở thích người dùng (redesign v2 P1).
/// - Khách: lưu client (key→String, JSON cho list).
/// - Đăng nhập: đồng bộ backend (`/api/me/preferences`); [mergeOnLogin] hợp nhất
///   prefs khách vào tài khoản (union) lần đầu sau khi đăng nhập.
class PreferencesService {
  PreferencesService._();
  static final PreferencesService instance = PreferencesService._();

  static const _kInterests = 'pref_interests';
  static const _kProvinces = 'pref_provinces';
  static const _kServices = 'pref_service_slugs';
  static const _kWorld = 'pref_default_world';
  static const _kPrompted = 'pref_survey_prompted';
  static const _kWorldExplicit = 'pref_world_explicit';
  static const _kProviderIntent = 'pref_provider_intent';
  // Chủ sở hữu của prefs local hiện tại: '<uid>' nếu đã đăng nhập, vắng/null nếu
  // do KHÁCH vô danh tạo. Dùng để mergeOnLogin KHÔNG trộn nhầm prefs của tài
  // khoản khác vào người vừa đăng nhập trên trình duyệt DÙNG CHUNG.
  static const _kOwner = 'pref_owner';

  ApiClient _api = const ApiClient();

  /// Chỉ dùng trong TEST để bơm ApiClient giả (MockClient).
  @visibleForTesting
  set apiClientForTest(ApiClient client) => _api = client;

  Future<List<String>> _readList(String key) async {
    try {
      final raw = await store.readToken(key);
      if (raw == null || raw.isEmpty) return const [];
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return const [];
    }
  }

  Future<UserPreferences> getLocal() async {
    return UserPreferences(
      interests: await _readList(_kInterests),
      provinces: await _readList(_kProvinces),
      serviceSlugs: await _readList(_kServices),
      defaultWorld: (await store.readToken(_kWorld)) ?? 'realestate',
    );
  }

  Future<void> saveLocal(UserPreferences prefs) async {
    final prevWorld = await store.readToken(_kWorld);
    await store.writeToken(_kInterests, jsonEncode(prefs.interests));
    await store.writeToken(_kProvinces, jsonEncode(prefs.provinces));
    await store.writeToken(_kServices, jsonEncode(prefs.serviceSlugs));
    await store.writeToken(_kWorld, prefs.defaultWorld);
    if (prevWorld != prefs.defaultWorld) defaultWorldRevision.value++;
  }

  /// Xoá prefs local — gọi khi ĐĂNG XUẤT. Trên trình duyệt DÙNG CHUNG (rất phổ
  /// biến ở VN), không xoá thì prefs của tài khoản vừa thoát còn nguyên trong
  /// localStorage; người/tài khoản kế tiếp sẽ thừa hưởng (tab order, gợi ý) và
  /// [mergeOnLogin] có thể trộn chúng vào tài khoản mới. Giữ [_kPrompted] để
  /// không hỏi lại khảo sát mỗi lần đăng xuất.
  Future<void> clearLocal() async {
    for (final k in const [
      _kInterests,
      _kProvinces,
      _kServices,
      _kWorld,
      _kWorldExplicit,
      _kProviderIntent,
      _kOwner,
    ]) {
      try {
        await store.deleteToken(k);
      } catch (_) {}
    }
    defaultWorldRevision.value++;
  }

  /// Đổi RIÊNG "thế giới mặc định" (thứ tự tab + màn hình mở đầu) từ Profile,
  /// giữ nguyên các lựa chọn khảo sát khác. Best-effort đồng bộ backend.
  Future<void> setDefaultWorld(String world) async {
    final current = await getLocal();
    // Đánh dấu người dùng đã TỰ CHỌN — kể cả khi trùng giá trị đang có, vì ý
    // nghĩa là "tôi cố ý muốn thế này", khác hẳn giá trị do khảo sát suy ra.
    // Nhờ cờ này, cá nhân hoá tự động (vd đơn vị thi công mở vào tab Thi công)
    // biết đường KHÔNG ghi đè lựa chọn tường minh của người dùng.
    try {
      await store.writeToken(_kWorldExplicit, '1');
    } catch (_) {
      /* cá nhân hoá là tiện ích, hỏng thì bỏ qua */
    }
    if (current.defaultWorld == world) return;
    final next = current.copyWith(defaultWorld: world);
    await saveLocal(next);
    try {
      await _api.put('/api/me/preferences', body: next.toMap());
    } catch (_) {
      // Khách chưa login / lỗi mạng → giữ local, merge lại khi đăng nhập.
    }
  }

  /// GỢI Ý thế giới mặc định từ một tín hiệu của người dùng (vd bấm "Tôi là
  /// đơn vị" ở màn chọn vai sau khi đăng ký) — KHÁC [setDefaultWorld] ở chỗ
  /// KHÔNG đánh dấu "tự chọn", nên lần sau nếu hồ sơ đơn vị thật xuất hiện thì
  /// cá nhân hoá tự động vẫn được quyền quyết định lại.
  ///
  /// Không ghi đè khi người dùng ĐÃ tự chọn trong Profile — lựa chọn tường minh
  /// luôn thắng.
  Future<void> suggestDefaultWorld(String world) async {
    if (await isDefaultWorldExplicit()) return;
    final current = await getLocal();
    if (current.defaultWorld == world) return;
    await saveLocal(current.copyWith(defaultWorld: world));
  }

  /// Người dùng TỰ KHAI ở khảo sát rằng mình là đơn vị thi công/thiết kế.
  ///
  /// Đây CHỈ là tín hiệu định tuyến giao diện (mở vào thế giới Thi công, ưu tiên
  /// thẻ "Tôi là đơn vị" ở màn chọn vai sau khi đăng ký) — KHÔNG phải danh tính.
  /// Danh tính thật vẫn là hồ sơ đơn vị + admin duyệt (xem [ContractorIdentity]);
  /// không có chỗ nào cấp quyền dựa trên cờ này.
  ///
  /// Lưu client vì khảo sát chạy TRƯỚC khi đăng nhập. Hệ quả đã biết: đổi thiết
  /// bị hoặc xoá dữ liệu trình duyệt thì mất — chấp nhận được vì mất chỉ làm
  /// hỏng phần gợi ý, không hỏng chức năng.
  Future<void> setProviderIntent(bool value) async {
    try {
      await store.writeToken(_kProviderIntent, value ? '1' : '0');
    } catch (_) {
      /* gợi ý hỏng thì bỏ qua */
    }
  }

  Future<bool> hasProviderIntent() async {
    try {
      return (await store.readToken(_kProviderIntent)) == '1';
    } catch (_) {
      return false;
    }
  }

  /// Người dùng đã TỰ chọn "Màn hình mặc định" trong Profile chưa?
  /// `false` = giá trị hiện tại chỉ do khảo sát suy ra (hoặc mặc định) → cá
  /// nhân hoá theo danh tính tài khoản được phép quyết định thay.
  Future<bool> isDefaultWorldExplicit() async {
    try {
      return (await store.readToken(_kWorldExplicit)) == '1';
    } catch (_) {
      return false;
    }
  }

  /// Đã hiện khảo sát cho user này chưa (client-side, 1 lần).
  Future<bool> hasBeenPrompted() async {
    try {
      return (await store.readToken(_kPrompted)) == '1';
    } catch (_) {
      return false;
    }
  }

  Future<void> markPrompted() async {
    try {
      await store.writeToken(_kPrompted, '1');
    } catch (_) {}
  }

  /// Lưu kết quả khảo sát: local + (best-effort) đồng bộ backend nếu đã đăng nhập.
  Future<void> saveSurvey(UserPreferences prefs) async {
    await saveLocal(prefs);
    await markPrompted();
    try {
      await _api.put('/api/me/preferences', body: prefs.toMap());
    } catch (_) {
      // Khách chưa login (401) hoặc lỗi mạng → chỉ giữ local; merge khi login.
    }
  }

  /// Lần đầu sau đăng nhập ([uid] = id tài khoản vừa vào): hợp nhất prefs KHÁCH
  /// vào tài khoản (union) rồi kéo bản hợp nhất về local. Không throw.
  ///
  /// CHỈ đẩy prefs local lên khi chúng do khách vô danh tạo (owner vắng/'guest').
  /// Nếu owner là uid KHÁC (prefs sót của tài khoản trước chưa xoá trên trình
  /// duyệt dùng chung), KHÔNG merge — chỉ kéo prefs server của [uid] về, tránh
  /// trộn dữ liệu người khác. Sau cùng đóng dấu owner = uid.
  Future<void> mergeOnLogin(int uid) async {
    try {
      final owner = await store.readToken(_kOwner);
      final isGuestOwned = owner == null || owner.isEmpty || owner == 'guest';
      final local = await getLocal();
      if (isGuestOwned && !local.isEmpty) {
        final body = local.toMap()..['merge'] = true;
        await _api.put('/api/me/preferences', body: body);
      }
      final res = await _api.get('/api/me/preferences');
      final server = UserPreferences.fromMap(
        (res['preferences'] as Map).cast<String, dynamic>(),
      );
      await saveLocal(server);
      await store.writeToken(_kOwner, '$uid');
    } catch (_) {}
  }
}
