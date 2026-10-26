/// Video reel ngắn (kiểu Facebook Reels).
///
/// `category` dùng chung taxonomy với SocialPost + 'all' (reel hiện ở MỌI phần).
class Reel {
  const Reel({
    required this.id,
    required this.userId,
    required this.authorName,
    this.authorAvatar,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.caption,
    required this.category,
    required this.likeCount,
    required this.viewCount,
    this.commentCount = 0,
    required this.likedByMe,
    this.createdAt,
  });

  final int id;
  final int userId;
  final String authorName;
  final String? authorAvatar;
  final String videoUrl;
  final String? thumbnailUrl;
  final String caption;
  final String category;
  final int likeCount;
  final int viewCount;
  final int commentCount;
  final bool likedByMe;
  final DateTime? createdAt;

  factory Reel.fromMap(Map<String, dynamic> m) => Reel(
    id: (m['id'] as num).toInt(),
    userId: (m['user_id'] as num?)?.toInt() ?? 0,
    authorName: (m['author_name'] as String?) ?? 'Người dùng',
    authorAvatar: m['author_avatar'] as String?,
    videoUrl: (m['video_url'] as String?) ?? '',
    thumbnailUrl: m['thumbnail_url'] as String?,
    caption: (m['caption'] as String?) ?? '',
    category: (m['category'] as String?) ?? 'all',
    likeCount: (m['like_count'] as num?)?.toInt() ?? 0,
    viewCount: (m['view_count'] as num?)?.toInt() ?? 0,
    commentCount: (m['comment_count'] as num?)?.toInt() ?? 0,
    likedByMe: (m['liked_by_me'] as bool?) ?? false,
    createdAt: DateTime.tryParse((m['created_at'] as String?) ?? ''),
  );

  Reel copyWith({int? likeCount, bool? likedByMe, int? commentCount}) => Reel(
    id: id,
    userId: userId,
    authorName: authorName,
    authorAvatar: authorAvatar,
    videoUrl: videoUrl,
    thumbnailUrl: thumbnailUrl,
    caption: caption,
    category: category,
    likeCount: likeCount ?? this.likeCount,
    viewCount: viewCount,
    commentCount: commentCount ?? this.commentCount,
    likedByMe: likedByMe ?? this.likedByMe,
    createdAt: createdAt,
  );
}
