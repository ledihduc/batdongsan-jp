// Web: xử lý version-skew của deferred chunk (DeferredLoadException) sau deploy.
// Reload full trang để nạp index.html mới → service worker cập nhật → hết lệch.
//
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

const _kFlag = 'ancu365_deferred_reloaded';

/// True nếu ĐƯỢC PHÉP tự reload (chưa reload lần nào trong phiên tab này).
/// Dùng sessionStorage để chống vòng lặp reload vô hạn: chỉ auto-reload 1 lần,
/// nếu vẫn lỗi sau reload thì trả về nút "Tải lại" thủ công.
bool shouldAutoReload() {
  try {
    final s = html.window.sessionStorage;
    if (s[_kFlag] == '1') return false;
    s[_kFlag] = '1';
    return true;
  } catch (_) {
    return false;
  }
}

void reloadApp() {
  try {
    // Xoá cờ để lần reload sau (do người dùng bấm) lại được phép auto 1 lần nữa
    // nếu cần — nhưng chỉ sau khi thực sự reload.
    html.window.location.reload();
  } catch (_) {}
}
