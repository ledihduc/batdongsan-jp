/// Bình luận dưới một bài đăng Cộng đồng. Hỗ trợ lồng nhiều cấp qua [parentId].
/// [isDeleted] = tombstone (nội dung ẩn nhưng giữ node để không mất nhánh replies).
class SocialComment {
  final int id;
  final int postId;
  final int userId;
  final int? parentId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final bool isDeleted;
  final int replyCount;
  final DateTime createdAt;

  const SocialComment({
    required this.id,
    required this.postId,
    required this.userId,
    this.parentId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    this.isDeleted = false,
    this.replyCount = 0,
    required this.createdAt,
  });

  factory SocialComment.fromMap(Map<String, dynamic> map) {
    return SocialComment(
      id: map['id'] as int,
      postId: map['post_id'] as int,
      userId: map['user_id'] as int,
      parentId: (map['parent_id'] as num?)?.toInt(),
      authorName: (map['author_name'] as String?) ?? 'Người dùng',
      authorAvatar: map['author_avatar'] as String?,
      content: (map['content'] as String?) ?? '',
      isDeleted: (map['is_deleted'] as bool?) ?? false,
      replyCount: (map['reply_count'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

/// Node cây bình luận: 1 comment + danh sách con (đệ quy nhiều cấp).
class SocialCommentNode {
  final SocialComment comment;
  final List<SocialCommentNode> children;

  const SocialCommentNode(this.comment, this.children);
}

/// Dựng cây từ danh sách phẳng (đã kèm parent_id). Con giữ nguyên thứ tự thời gian.
/// Node mồ côi (parent không có trong danh sách) được nâng lên gốc để không mất bài.
List<SocialCommentNode> buildCommentTree(List<SocialComment> flat) {
  final byId = <int, SocialComment>{for (final c in flat) c.id: c};
  final childrenOf = <int, List<SocialComment>>{};
  final roots = <SocialComment>[];
  for (final c in flat) {
    final pid = c.parentId;
    if (pid != null && byId.containsKey(pid)) {
      childrenOf.putIfAbsent(pid, () => []).add(c);
    } else {
      roots.add(c);
    }
  }

  List<SocialCommentNode> build(List<SocialComment> items) {
    return items
        .map((c) => SocialCommentNode(c, build(childrenOf[c.id] ?? const [])))
        .toList();
  }

  return build(roots);
}
