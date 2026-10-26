import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:house_booking/core/permissions/fcm_service.dart';
import 'package:house_booking/core/permissions/permission_analytics_uploader.dart';
import 'package:house_booking/data/models/notification_model.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/features/permissions/helpers/notification_tap_router.dart';

class NotificationProvider with ChangeNotifier, WidgetsBindingObserver {
  /// [api] chỉ để TEST bơm client giả — mặc định là bản thật nên mã sản phẩm
  /// không đổi hành vi.
  NotificationProvider({ApiClient? api}) : _api = api ?? const ApiClient();

  final ApiClient _api;

  List<NotificationModel> _items = [];
  int _unread = 0;
  bool _loading = false;
  int? _userId;
  Timer? _poller;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  StreamSubscription<Map<String, dynamic>>? _notificationSub;

  // ── FCM extension (Phase 4) ─────────────────────────────────────────────────
  StreamSubscription<RemoteMessage>? _fgSub;
  StreamSubscription<RemoteMessage>? _tapSub;
  StreamSubscription<String>? _tokenRefreshSub;

  List<NotificationModel> get items => _items;
  int get unread => _unread;
  bool get loading => _loading;

  Future<void> fetch(int userId) async {
    _userId = userId;
    _loading = true;
    notifyListeners();
    try {
      // Backend lấy user_id từ JWT sub (chặn IDOR) — không cần truyền userId.
      final res = await _api.get('/api/notifications');
      final list = List<Map<String, dynamic>>.from(
        res['notifications'] as List? ?? const [],
      );
      _items = list.map(NotificationModel.fromMap).toList();
      _unread = (res['unread'] as int?) ?? 0;
    } catch (e) {
      debugPrint('fetch notifications error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Nhịp hỏi thông báo — giữ làm fallback khi app mất WS hoặc backend đang
  /// khởi động lại. Khi có `status:changed`, danh sách được refresh ngay.
  static const _pollInterval = Duration(seconds: 30);

  /// Polling 30s — chỉ chạy khi có user VÀ ứng dụng đang hiển thị.
  ///
  /// Trước đây timer chạy bất kể tab có được nhìn hay không: một tab để quên
  /// vẫn gọi `/api/notifications` mỗi 30 giây suốt ngày. Đo trên log NPM ngày
  /// 19/07/2026 thấy `/api/notifications` là endpoint bị gọi nhiều thứ nhì
  /// (844 lượt) trong khi chưa có người dùng thật nào.
  void startPolling(int userId) {
    _userId = userId;
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);
    _resumePolling();
  }

  void stopPolling() {
    WidgetsBinding.instance.removeObserver(this);
    _poller?.cancel();
    _poller = null;
    // Xoá luôn user: nếu còn sót một callback vòng đời (observer chưa kịp gỡ,
    // hoặc sự kiện đã xếp hàng) thì nó sẽ nạp thông báo của TÀI KHOẢN VỪA
    // ĐĂNG XUẤT. Test "sau stopPolling, vòng đời đổi cũng không hồi sinh
    // polling" bắt đúng trường hợp này.
    _userId = null;
  }

  /// Nối vào kênh WS dùng chung với ChatProvider. Event không mang dữ liệu
  /// riêng tư; REST vẫn là nguồn dữ liệu chuẩn để dựng trạng thái mới.
  void attachStatusRealtime(Stream<Map<String, dynamic>> events) {
    _statusSub?.cancel();
    _statusSub = events.listen((_) {
      final userId = _userId;
      if (userId != null) fetch(userId);
    });
  }

  /// Inserts a notification delivered over the authenticated WebSocket.
  /// The id guard keeps this safe alongside REST/FCM refreshes.
  void attachNotificationRealtime(Stream<Map<String, dynamic>> events) {
    _notificationSub?.cancel();
    _notificationSub = events.listen((payload) {
      final userId = _userId;
      if (userId == null || payload['user_id'] != userId) return;
      try {
        final item = NotificationModel.fromMap(payload);
        if (_items.any((existing) => existing.id == item.id)) return;
        _items = [item, ..._items];
        if (!item.read) _unread++;
        notifyListeners();
      } catch (e) {
        debugPrint('parse realtime notification error: $e');
        fetch(userId);
      }
    });
  }

  void _resumePolling() {
    _poller?.cancel();
    _poller = Timer.periodic(_pollInterval, (_) {
      if (_userId != null) fetch(_userId!);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed;
    if (!visible) {
      // Ẩn tab / thu nhỏ app → ngừng hỏi. Không mất thông báo nào: lúc quay
      // lại ta nạp ngay một lần bên dưới.
      _poller?.cancel();
      _poller = null;
      return;
    }
    if (_poller == null && _userId != null) {
      fetch(_userId!); // bù ngay khoảng thời gian vừa ngừng
      _resumePolling();
    }
  }

  Future<void> markRead(int id) async {
    // Optimistic
    final i = _items.indexWhere((n) => n.id == id);
    if (i >= 0 && !_items[i].read) {
      final old = _items[i];
      _items[i] = NotificationModel(
        id: old.id,
        userId: old.userId,
        type: old.type,
        title: old.title,
        body: old.body,
        relatedId: old.relatedId,
        read: true,
        createdAt: old.createdAt,
      );
      _unread = (_unread - 1).clamp(0, 9999);
      notifyListeners();
    }
    try {
      await _api.patch('/api/notifications/$id/read');
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    if (_userId == null) return;
    _items = _items
        .map(
          (n) => NotificationModel(
            id: n.id,
            userId: n.userId,
            type: n.type,
            title: n.title,
            body: n.body,
            relatedId: n.relatedId,
            read: true,
            createdAt: n.createdAt,
          ),
        )
        .toList();
    _unread = 0;
    notifyListeners();
    try {
      await _api.patch('/api/notifications/read-all');
    } catch (_) {}
  }

  void clear() {
    stopPolling();
    _statusSub?.cancel();
    _statusSub = null;
    _notificationSub?.cancel();
    _notificationSub = null;
    detachFcm();
    _items = [];
    _unread = 0;
    _userId = null;
    notifyListeners();
  }

  // ── FCM integration (Phase 4) ───────────────────────────────────────────────

  /// Injects [FcmService] for token refresh and message routing.
  /// Retained for external callers that prefer setter injection over [attachFcm].
  /// [attachFcm] is the preferred method as it also wires the GoRouter.
  // ignore: unused_element — may be called by future callers outside _RootGate.
  void setFcm(FcmService fcm) {
    // No-op field store: use attachFcm(fcm, router) for full wiring.
    // Kept for API symmetry with AuthProvider.setPermissionService pattern.
  }

  /// Subscribes to FCM foreground messages, notification taps, and token refresh.
  ///
  /// - Foreground message → refresh in-app notification list immediately.
  /// - Notification tap → route via [NotificationTapRouter].
  /// - Token refresh → handled by [FcmService.attachUserContext] (Phase 6).
  /// - [uploader] (optional) — if provided, triggers an immediate analytics flush
  ///   after login so any events captured during a previous session are uploaded
  ///   without waiting for the next app foreground event.
  ///
  /// Safe to call multiple times — [detachFcm] cancels previous subscriptions
  /// before creating new ones.
  void attachFcm(
    FcmService fcm,
    GoRouter router, {
    PermissionAnalyticsUploader? uploader,
  }) {
    // Cancel any stale subscriptions first.
    detachFcm();

    // Foreground messages: refresh list so user sees badge update immediately.
    _fgSub = fcm.foregroundMessages.listen((RemoteMessage message) {
      if (_userId != null) {
        fetch(_userId!);
      }
    });

    // Notification taps (app was in background/terminated).
    _tapSub = fcm.notificationTaps.listen((RemoteMessage message) {
      NotificationTapRouter.route(message, router);
    });

    // Token refresh: FcmService.attachUserContext now owns re-registration.
    // We keep the subscription here only for observable logging in debug.
    _tokenRefreshSub = fcm.onTokenRefresh.listen((String newToken) {
      // Re-registration is handled by FcmService.attachUserContext listener.
      // Token is semi-sensitive — never log in production.
      assert(() {
        debugPrint('[NotificationProvider] FCM token refresh received.');
        return true;
      }());
    });

    // Flush any pending analytics events immediately after login (fire-and-forget).
    // This uploads events captured in a previous session that weren't flushed
    // because the app was backgrounded before a resumed lifecycle event fired.
    uploader?.flush();
  }

  /// Cancels all FCM stream subscriptions.
  /// Called on logout (via [clear]) and when attaching a new set of subscriptions.
  void detachFcm() {
    _fgSub?.cancel();
    _tapSub?.cancel();
    _tokenRefreshSub?.cancel();
    _fgSub = null;
    _tapSub = null;
    _tokenRefreshSub = null;
  }

  @override
  void dispose() {
    _poller?.cancel();
    _statusSub?.cancel();
    _notificationSub?.cancel();
    detachFcm();
    super.dispose();
  }
}
