class NotificationModel {
  final int id;
  final int userId;
  final String type;
  final String title;
  final String body;
  final int? relatedId;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.relatedId,
    required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> m) {
    return NotificationModel(
      id: m['id'] as int,
      userId: m['user_id'] as int,
      type: m['type'] as String,
      title: m['title'] as String,
      body: m['body'] as String,
      relatedId: m['related_id'] as int?,
      read: m['read'] == true || m['read'] == 1,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }
}
