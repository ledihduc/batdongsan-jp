/// Trạng thái màn `/ai-confirm/:token`: tải xem trước, mời đăng nhập, xác nhận đúng 1 lần (Phase 11, F-2, F-3).
///
/// Trạng thái đăng nhập và ngôn ngữ đổi được sau khi tạo ([setLoggedIn], [setLang]): mở link là tải lại
/// cả trang ⇒ phiên đăng nhập và ngôn ngữ đã lưu được khôi phục bất đồng bộ sau frame đầu (QA C1, M1).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:house_booking/data/models/ai/ai_pending_action_models.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/ai/i_ai_action_repository.dart';

enum AiConfirmStatus { loading, ready, needLogin, submitting, done, error }

enum AiConfirmErrorKind { notFound, used, expired, forbidden, invalid, network }

class AiActionConfirmController extends ChangeNotifier {
  AiActionConfirmController(this._repo, {required this.token, bool? isLoggedIn, String lang = 'ja'})
      : _loggedIn = isLoggedIn,
        _lang = lang;

  final IAiActionRepository _repo;
  final String token;

  /// `null` = chưa biết (phiên đang khôi phục) ⇒ giữ `loading`, không mời đăng nhập vội.
  bool? _loggedIn;
  String _lang;

  AiConfirmStatus _status = AiConfirmStatus.loading;
  AiConfirmErrorKind? _errorKind;
  AiPendingPreview? _preview;
  AiConfirmResult? _result;
  bool _disposed = false;

  AiConfirmStatus get status => _status;
  AiConfirmErrorKind? get errorKind => _errorKind;
  AiPendingPreview? get preview => _preview;
  AiConfirmResult? get result => _result;
  String get lang => _lang;

  /// Cập nhật trạng thái đăng nhập; chỉ đổi màn khi đang chờ người dùng (ready/needLogin/loading).
  void setLoggedIn(bool? value) {
    if (value == _loggedIn) return;
    _loggedIn = value;
    if (_preview != null && _waitingForUser) _settle();
  }

  /// Ngôn ngữ giao diện đổi ⇒ tải lại xem trước (tiêu đề action theo ngôn ngữ). Bỏ qua khi đang gửi / đã xong.
  void setLang(String value) {
    if (value == _lang) return;
    _lang = value;
    if (_status != AiConfirmStatus.submitting && _status != AiConfirmStatus.done && _result == null) load();
  }

  /// Lỗi mạng (timeout, mất kết nối, 5xx/429) ⇒ thử lại: tải lại xem trước rồi người dùng bấm xác nhận lại.
  Future<void> retry() async {
    if (_status != AiConfirmStatus.error || _errorKind != AiConfirmErrorKind.network) return;
    await load();
  }

  bool get _waitingForUser =>
      _status == AiConfirmStatus.ready || _status == AiConfirmStatus.needLogin || _status == AiConfirmStatus.loading;

  void _settle() {
    final v = _loggedIn;
    _set(v == null ? AiConfirmStatus.loading : (v ? AiConfirmStatus.ready : AiConfirmStatus.needLogin));
  }

  /// Chỉ GET — không ghi gì. Chưa đăng nhập vẫn hiện tóm tắt, kèm lời mời đăng nhập.
  Future<void> load() async {
    _errorKind = null;
    _set(AiConfirmStatus.loading);
    final asked = _lang;
    try {
      final p = await _repo.preview(token, lang: asked);
      if (asked != _lang) return; // ngôn ngữ đổi giữa chừng ⇒ lần tải mới sẽ trả kết quả
      _preview = p;
      _settle();
    } catch (e) {
      if (asked != _lang) return;
      _fail(e);
    }
  }

  /// Khoá ngay khi bắt đầu gửi ⇒ bấm nhiều lần chỉ gọi 1 lần (backend vẫn chặn trùng bằng 409).
  Future<void> confirm() async {
    if (_status != AiConfirmStatus.ready) return;
    _set(AiConfirmStatus.submitting);
    try {
      _result = await _repo.confirm(token);
      _set(AiConfirmStatus.done);
    } catch (e) {
      _fail(e);
    }
  }

  void _fail(Object e) {
    if (e is ApiException && e.statusCode == 401) {
      _set(AiConfirmStatus.needLogin); // phiên hết hạn ⇒ đăng nhập lại rồi mở lại link
      return;
    }
    _errorKind = kindOf(e);
    _set(AiConfirmStatus.error);
  }

  void _set(AiConfirmStatus s) {
    _status = s;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Map lỗi HTTP ⇒ loại lỗi hiển thị (F-3). Dùng chung với thẻ xác nhận trong chat.
  static AiConfirmErrorKind kindOf(Object e) {
    if (e is! ApiException) return AiConfirmErrorKind.network; // timeout, mất mạng, parse lỗi
    return switch (e.statusCode) {
      404 => AiConfirmErrorKind.notFound,
      409 => AiConfirmErrorKind.used,
      410 => AiConfirmErrorKind.expired,
      403 => AiConfirmErrorKind.forbidden,
      422 => AiConfirmErrorKind.invalid,
      _ => AiConfirmErrorKind.network,
    };
  }
}
