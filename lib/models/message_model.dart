// Model for messages returned by the API
class MessageModel {
  final String id;
  final String content;
  final String senderId;
  final String receiverId;
  final String idConversation;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? voiceUrl;
  final Duration? voiceDuration;

  MessageModel({
    required this.id,
    required this.content,
    required this.senderId,
    required this.receiverId,
    required this.idConversation,
    required this.createdAt,
    required this.updatedAt,
    this.voiceUrl,
    this.voiceDuration,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    Duration? parseDuration(dynamic value) {
      if (value == null) return null;
      if (value is int) return Duration(milliseconds: value);
      if (value is double) return Duration(milliseconds: (value * 1000).round());
      if (value is String) {
        final numeric = double.tryParse(value);
        if (numeric != null) {
          return numeric > 1000
              ? Duration(milliseconds: numeric.round())
              : Duration(milliseconds: (numeric * 1000).round());
        }
      }
      return null;
    }

    return MessageModel(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      receiverId: json['receiver_id'] as String? ?? '',
      idConversation: json['id_conversation'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      voiceUrl: json['voice_url'] as String? ?? json['voice'] as String?,
      voiceDuration: parseDuration(json['duration_ms'] ?? json['duration'] ?? json['voice_duration']),
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
        if (voiceUrl != null) 'voice_url': voiceUrl,
        if (voiceDuration != null) 'duration_ms': voiceDuration!.inMilliseconds,
      };
}
