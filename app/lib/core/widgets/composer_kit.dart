import 'package:flutter/material.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/core/widgets/fb_post_card.dart' show FbAvatar;

// Bộ phần dùng chung cho CÁC MÀN SOẠN (bài cộng đồng · bài thi công · reel).
//
// Vì sao gom lại: ba màn này trước đây mỗi màn tự vẽ một kiểu — avatar chỗ thì
// ảnh thật chỗ thì chữ cái, thanh đính kèm chỗ thì thẻ chỗ thì hàng phẳng, nút
// đăng thì mỗi nơi một màu. Người dùng đi qua ba màn thấy như ba ứng dụng.
//
// Bố cục chuẩn (theo composer "Bài viết mới" của Facebook):
//   [✕  Tiêu đề]
//   avatar + tên
//   hàng chip thuộc tính
//   vùng viết (nhân vật chính)
//   ─────────────
//   hàng thẻ đính kèm  +  NÚT CHÍNH ở đáy
/// Hàng "ai đang đăng". Dùng [FbAvatar] để avatar ở màn soạn TRÙNG KHỚP với
/// avatar khi bài lên feed.
class ComposerAuthorRow extends StatelessWidget {
  const ComposerAuthorRow({super.key, required this.ten, this.avatarUrl});

  final String ten;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FbAvatar(url: avatarUrl, ten: ten, kichThuoc: 44),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Text(
            ten,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: HD.ink),
          ),
        ),
      ],
    );
  }
}

/// Một thẻ đính kèm ở thanh đáy (Ảnh, Video…).
class ComposerAction {
  const ComposerAction({
    required this.icon,
    required this.mau,
    required this.nhan,
    this.phu,
    this.onTap,
  });

  final IconData icon;
  final Color mau;
  final String nhan;

  /// Dòng phụ, ví dụ "3/10 ảnh". Đặt TRONG thẻ chứ không để ở chú thích mờ —
  /// người dùng cần biết còn thêm được bao nhiêu TRƯỚC khi bấm.
  final String? phu;

  /// null = tắt (hết chỗ / không dùng được).
  final VoidCallback? onTap;
}

/// Thanh đáy: hàng thẻ đính kèm + NÚT CHÍNH.
///
/// Nút chính đặt ở ĐÁY (không phải app bar) vì đây là web mobile — ngón cái ở
/// dưới, và đó cũng là bố cục của composer Facebook.
class ComposerActionBar extends StatelessWidget {
  const ComposerActionBar({
    super.key,
    required this.actions,
    required this.nhanNutChinh,
    required this.onSubmit,
    this.dangGui = false,
  });

  final List<ComposerAction> actions;
  final String nhanNutChinh;

  /// null = chưa đủ điều kiện đăng (nút ở trạng thái tắt).
  final VoidCallback? onSubmit;
  final bool dangGui;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: HD.paperRaised,
        border: Border(top: BorderSide(color: HD.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(HD.s12, HD.s12, HD.s12, HD.s8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (actions.isNotEmpty)
              Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: HD.s8),
                    Expanded(child: _The(action: actions[i])),
                  ],
                  // Một thẻ đơn độc mà Expanded sẽ kéo dài hết chiều ngang,
                  // thành cái băng chữ nhật, mất hẳn nhịp "hàng thẻ" của FB.
                  // Chèn ô trống để thẻ giữ tỉ lệ hợp lý.
                  if (actions.length == 1) const Spacer(),
                ],
              ),
            const SizedBox(height: HD.s12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: dangGui ? null : onSubmit,
                style: FilledButton.styleFrom(
                  // accentDeep: token quy định nút chữ trắng phải dùng màu này
                  // (accent chỉ đạt 3.6:1 với chữ trắng).
                  backgroundColor: HD.accentDeep,
                  disabledBackgroundColor: HD.paperSunken,
                  // Thiếu dòng này thì Material lấy chữ mờ 38% -> nhìn không ra
                  // là nút đã tắt.
                  disabledForegroundColor: HD.inkSoft,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(HD.r8)),
                ),
                child: dangGui
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: HD.inkSoft),
                      )
                    : Text(nhanNutChinh,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _The extends StatelessWidget {
  const _The({required this.action});

  final ComposerAction action;

  @override
  Widget build(BuildContext context) {
    final tat = action.onTap == null;
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(HD.r12),
      child: Container(
        // 44px trở lên = ngưỡng vùng chạm tối thiểu.
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(vertical: HD.s8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: HD.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Không bọc Opacity: nó làm mờ CẢ dòng phụ — mà dòng phụ ("10/10")
            // chính là lý do thẻ bị tắt, thứ cần đọc rõ nhất.
            Icon(action.icon,
                color: tat ? HD.hairlineStrong : action.mau, size: 22),
            const SizedBox(height: HD.s4),
            Text(action.nhan,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tat ? HD.inkSoft : HD.ink)),
            if (action.phu != null)
              Text(action.phu!,
                  style: TextStyle(
                      fontSize: 11,
                      color: tat ? HD.warning : HD.inkSoft,
                      fontWeight: tat ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
