class ReviewModel {
  final int? id;
  final int userId;
  final int houseId;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final String? userName;
  final String? userAvatar;

  ReviewModel({
    this.id,
    required this.userId,
    required this.houseId,
    required this.rating,
    required this.comment,
    DateTime? createdAt,
    this.userName,
    this.userAvatar,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ReviewModel.fromMap(Map<String, dynamic> m) {
    return ReviewModel(
      id: m['id'] as int?,
      userId: m['user_id'] as int,
      houseId: m['house_id'] as int,
      rating: m['rating'] as int,
      comment: (m['comment'] as String?) ?? '',
      createdAt: DateTime.parse(m['created_at'] as String),
      userName: m['user_name'] as String?,
      userAvatar: m['user_avatar'] as String?,
    );
  }
}
