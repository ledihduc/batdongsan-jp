/// Bài đăng Cộng đồng (mạng xã hội kiểu Facebook), gắn với 1 khối chức năng.
///
/// like_count/comment_count được backend denormalize nên client chỉ đọc, không
/// tự COUNT. [likedByMe] null-safe false khi khách chưa đăng nhập. [category]
/// là 1 trong 6 khối (rent|lease|industrial|design|build|interior), bất biến.
class SocialPost {
  final int id;
  final int userId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final List<String> images;
  final String category;
  final String categoryName;
  final String? provinceCode;
  final String? districtCode;
  final String? wardSlug;
  final String? locationText;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final DateTime? editedAt;
  final int editCount;
  final DateTime createdAt;

  const SocialPost({
    required this.id,
    required this.userId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    this.images = const [],
    this.category = 'lease',
    this.categoryName = 'Cho thuê',
    this.provinceCode,
    this.districtCode,
    this.wardSlug,
    this.locationText,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
    this.editedAt,
    this.editCount = 0,
    required this.createdAt,
  });

  bool get isEdited => editCount > 0 || editedAt != null;

  /// Copy bất biến — dùng cho cập nhật lạc quan (thích/bình luận) và sửa bài.
  SocialPost copyWith({
    String? content,
    List<String>? images,
    int? likeCount,
    int? commentCount,
    bool? likedByMe,
    DateTime? editedAt,
    int? editCount,
  }) {
    return SocialPost(
      id: id,
      userId: userId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content ?? this.content,
      images: images ?? this.images,
      category: category,
      categoryName: categoryName,
      provinceCode: provinceCode,
      districtCode: districtCode,
      wardSlug: wardSlug,
      locationText: locationText,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedByMe: likedByMe ?? this.likedByMe,
      editedAt: editedAt ?? this.editedAt,
      editCount: editCount ?? this.editCount,
      createdAt: createdAt,
    );
  }

  factory SocialPost.fromMap(Map<String, dynamic> map) {
    return SocialPost(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      authorName: (map['author_name'] as String?) ?? 'Người dùng',
      authorAvatar: map['author_avatar'] as String?,
      content: (map['content'] as String?) ?? '',
      images:
          (map['images'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      category: (map['category'] as String?) ?? 'lease',
      categoryName: (map['category_name'] as String?) ?? 'Cho thuê',
      provinceCode: map['province_code'] as String?,
      districtCode: map['district_code'] as String?,
      wardSlug: map['ward_slug'] as String?,
      locationText: map['location_text'] as String?,
      likeCount: (map['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (map['comment_count'] as num?)?.toInt() ?? 0,
      likedByMe: (map['liked_by_me'] as bool?) ?? false,
      editedAt: DateTime.tryParse((map['edited_at'] as String?) ?? ''),
      editCount: (map['edit_count'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
