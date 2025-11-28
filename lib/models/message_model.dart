// Model for messages returned by the API
class MessageModel {
  final String id;
  final String content;
  final String senderId;
  final String receiverId;
  final String idConversation;
  final DateTime createdAt;
  final DateTime updatedAt;

  MessageModel({
    required this.id,
    required this.content,
    required this.senderId,
    required this.receiverId,
    required this.idConversation,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      receiverId: json['receiver_id'] as String? ?? '',
      idConversation: json['id_conversation'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'id_conversation': idConversation,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

