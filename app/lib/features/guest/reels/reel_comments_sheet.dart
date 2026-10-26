import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/binh_luan_sheet.dart';
import 'package:house_booking/data/services/reel_api.dart';

/// Bình luận REEL. Thân giao diện nằm ở [BinhLuanSheet] — dùng chung với tin
/// nhà, vì hai bên cùng một cây bình luận (`social_comments`, khác nhau đúng
/// `target_type`).
class ReelCommentsSheet extends StatelessWidget {
  const ReelCommentsSheet({
    super.key,
    this.api = const ReelApi(),
    required this.reelId,
    this.onCountChanged,
  });

  /// Cho phép bơm ReelApi giả trong test. Mặc định là bản thật nên mã sản
  /// phẩm không đổi hành vi — chỉ mở một khe để test không cần mạng.
  final ReelApi api;

  final int reelId;
  final ValueChanged<int>? onCountChanged;

  @override
  Widget build(BuildContext context) => BinhLuanSheet(
    nap: () => api.comments(reelId),
    gui: (noiDung, {int? parentId}) =>
        api.addComment(reelId, noiDung, parentId: parentId),
    xoa: api.deleteComment,
    onCountChanged: onCountChanged,
  );
}
