import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/data/models/chat_message_model.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/session_service.dart';

class ChatProvider with ChangeNotifier {
  final ApiClient _api = const ApiClient();

  List<ConversationModel> _conversations = [];
  final Map<int, List<ChatMessageModel>> _history = {}; // peerId → list
  int? _myUserId;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  bool _connecting = false;
  final StreamController<Map<String, dynamic>> _statusEvents =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _notificationEvents =
      StreamController<Map<String, dynamic>>.broadcast();

  List<ConversationModel> get conversations => _conversations;
  bool get isConnected => _channel != null;

  /// Committed reservation/viewing/rental-journey transitions received from
  /// the shared authenticated WebSocket. Consumers should re-fetch their
  /// authoritative REST projection using entity + entity_id.
  Stream<Map<String, dynamic>> get statusEvents => _statusEvents.stream;
  Stream<Map<String, dynamic>> get notificationEvents =>
      _notificationEvents.stream;

  List<ChatMessageModel> messagesWith(int peerId) =>
      List.unmodifiable(_history[peerId] ?? const []);

  int get totalUnread => _conversations.fold(0, (sum, c) => sum + c.unread);

  // ───────── REST ─────────

  Future<void> fetchConversations(int userId) async {
    _myUserId = userId;
    try {
      // Backend lấy actor từ JWT sub — không cần truyền userId.
      final res = await _api.get('/api/chats');
      final list = List<Map<String, dynamic>>.from(
        res['conversations'] as List? ?? const [],
      );
      _conversations = list.map(ConversationModel.fromMap).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('fetch conversations error: $e');
    }
  }

  Future<void> loadHistory(int peerId) async {
    if (_myUserId == null) return;
    try {
      final res = await _api.get(
        '/api/chats/$peerId/messages',
        queryParameters: {'limit': 100},
      );
      final list = List<Map<String, dynamic>>.from(
        res['messages'] as List? ?? const [],
      );
      _history[peerId] = list.map(ChatMessageModel.fromMap).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('load history error: $e');
    }
  }

  Future<void> sendMessage({
    required int peerId,
    required String body,
    int? houseId,
  }) async {
    if (_myUserId == null || body.trim().isEmpty) return;
    try {
      // sender_id derived from JWT sub server-side — không cần truyền.
      await _api.post(
        '/api/chats/$peerId/messages',
        body: {'body': body.trim(), if (houseId != null) 'house_id': houseId},
      );
      // Backend đã echo qua WS, không cần append local — WS sẽ làm.
      // Fallback nếu WS chưa connect:
      if (!isConnected) {
        await loadHistory(peerId);
        await fetchConversations(_myUserId!);
      }
    } catch (e) {
      debugPrint('send error: $e');
      rethrow;
    }
  }

  Future<void> markRead(int peerId) async {
    if (_myUserId == null) return;
    try {
      await _api.patch('/api/chats/$peerId/read');
      // Cập nhật unread locally
      final i = _conversations.indexWhere((c) => c.peerId == peerId);
      if (i >= 0 && _conversations[i].unread > 0) {
        final c = _conversations[i];
        _conversations[i] = ConversationModel(
          peerId: c.peerId,
          peerName: c.peerName,
          peerAvatar: c.peerAvatar,
          lastBody: c.lastBody,
          lastAt: c.lastAt,
          unread: 0,
          online: c.online,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  // ───────── WebSocket ─────────

  /// Ping `/healthz` để chắc backend còn sống trước khi mở WS.
  ///
  /// Lý do: browser WS chỉ báo "handshake timeout" sau 20-30s nếu backend
  /// half-dead (TCP accept nhưng không respond). Pre-flight HTTP GET với
  /// timeout 2s cho phép fail fast và đẩy retry sang `_scheduleReconnect`
  /// thay vì user thấy stack trace đỏ trong console.
  Future<bool> _checkHealth() async {
    try {
      final res = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/healthz'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('healthz check failed: $e');
      return false;
    }
  }

  /// Đổi JWT lấy vé WebSocket dùng-một-lần (hạn 30s). Trả null nếu thất bại —
  /// nơi gọi sẽ hẹn kết nối lại thay vì mở kênh không xác thực được.
  Future<String?> _fetchWsTicket(String token) async {
    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/ws-ticket'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) {
        debugPrint('ws-ticket failed: ${res.statusCode}');
        return null;
      }
      final t = (jsonDecode(res.body) as Map)['ticket'] as String?;
      return (t != null && t.isNotEmpty) ? t : null;
    } catch (e) {
      debugPrint('ws-ticket error: $e');
      return null;
    }
  }

  Future<void> connect(int userId) async {
    _myUserId = userId;
    if (_connecting || _channel != null) return;
    _connecting = true;

    try {
      final token = await SessionService.instance.getToken();
      if (token == null || token.isEmpty) {
        _connecting = false;
        return;
      }

      // Pre-flight health check — tránh WS handshake timeout 20-30s khi
      // backend half-dead. Fail → schedule reconnect và return early.
      if (!await _checkHealth()) {
        debugPrint('Backend unhealthy — skip WS connect, retry in 5s');
        _scheduleReconnect();
        return;
      }

      // Đổi JWT lấy vé ngắn hạn. KHÔNG đặt JWT vào URL: query string bị nginx
      // ghi vào access log, token đăng nhập nằm đó là lộ tài khoản.
      final ticket = await _fetchWsTicket(token);
      if (ticket == null) {
        _scheduleReconnect();
        return;
      }

      final base = ApiConfig.baseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');
      final uri = Uri.parse('$base/ws?ticket=$ticket');
      _channel = WebSocketChannel.connect(uri);

      _sub = _channel!.stream.listen(
        _onEvent,
        onError: (e) {
          debugPrint('WS error: $e');
          _disconnect();
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('WS closed');
          _disconnect();
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('WS connect failed: $e');
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _onEvent(dynamic raw) {
    try {
      final m = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = m['type'] as String?;
      if (type == 'chat:new') {
        final payload = Map<String, dynamic>.from(m['payload'] as Map);
        final msg = ChatMessageModel.fromMap(payload);
        final peer = msg.senderId == _myUserId ? msg.receiverId : msg.senderId;
        _history.putIfAbsent(peer, () => []).add(msg);
        // Refresh conversation list nhanh
        if (_myUserId != null) fetchConversations(_myUserId!);
        notifyListeners();
      } else if (type == 'chat:read') {
        // peer đã đọc → cập nhật trạng thái nếu cần (TODO: hiển thị tick xanh)
      } else if (type == 'status:changed') {
        final rawPayload = m['payload'];
        if (rawPayload is Map) {
          _statusEvents.add(Map<String, dynamic>.from(rawPayload));
        }
      } else if (type == 'notification:new') {
        final rawPayload = m['payload'];
        if (rawPayload is Map) {
          _notificationEvents.add(Map<String, dynamic>.from(rawPayload));
        }
      }
    } catch (e) {
      debugPrint('parse WS event error: $e');
    }
  }

  void _disconnect() {
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    notifyListeners();
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectTimer = null;
      if (_myUserId != null) connect(_myUserId!);
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _disconnect();
  }

  void clear() {
    disconnect();
    _conversations = [];
    _history.clear();
    _myUserId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _statusEvents.close();
    _notificationEvents.close();
    super.dispose();
  }
}
