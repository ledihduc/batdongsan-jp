class ChatMessageModel {
  final int id;
  final int senderId;
  final int receiverId;
  final int? houseId;
  final String body;
  final bool read;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.houseId,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> m) {
    return ChatMessageModel(
      id: m['id'] as int,
      senderId: m['sender_id'] as int,
      receiverId: m['receiver_id'] as int,
      houseId: m['house_id'] as int?,
      body: m['body'] as String,
      read: m['read'] == true || m['read'] == 1,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }
}

class ConversationModel {
  final int peerId;
  final String peerName;
  final String peerAvatar;
  final String lastBody;
  final DateTime lastAt;
  final int unread;
  final bool online;

  ConversationModel({
    required this.peerId,
    required this.peerName,
    required this.peerAvatar,
    required this.lastBody,
    required this.lastAt,
    required this.unread,
    required this.online,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> m) {
    return ConversationModel(
      peerId: m['peer_id'] as int,
      peerName: m['peer_name'] as String,
      peerAvatar: (m['peer_avatar'] as String?) ?? '',
      lastBody: (m['last_body'] as String?) ?? '',
      lastAt: DateTime.parse(m['last_at'] as String),
      unread: (m['unread'] as int?) ?? 0,
      online: m['online'] == true,
    );
  }
}
