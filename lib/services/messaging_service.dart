import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:slatereduc/models/message_model.dart';

class MessagingService {
  final String baseUrl;
  final Map<String, String> defaultHeaders;

  MessagingService({
    this.baseUrl = 'http://192.168.1.70:8000',
    Map<String, String>? headers,
  }) : defaultHeaders = headers ?? {'Content-Type': 'application/json'};

  Future<List<MessageModel>> getMessagesByConversationId(String conversationId) async {
    final url = Uri.parse('$baseUrl/messaging/conversations/$conversationId/messages');
    final resp = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) {
      final List<dynamic> data = json.decode(resp.body) as List<dynamic>;
      return data.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load messages: ${resp.statusCode} ${resp.body}');
  }

  Future<MessageModel> sendMessage({
    required String content,
    required String senderId,
    required String receiverId,
    required String idConversation,
  }) async {
    final url = Uri.parse('$baseUrl/messaging/messages');
    final body = json.encode({
      'content': content,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'id_conversation': idConversation,
    });
    final resp = await http.post(url, headers: defaultHeaders, body: body).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final Map<String, dynamic> data = json.decode(resp.body) as Map<String, dynamic>;
      return MessageModel.fromJson(data);
    }
    // include response body to help debug 422 validation errors
    throw Exception('Failed to send message: ${resp.statusCode} ${resp.body}');
  }

  /// Create a conversation. Optionally include [participants] as a list of user/person ids.
  Future<String> createConversation({required String title, List<String>? participants}) async {
    final url = Uri.parse('$baseUrl/messaging/conversations');
    final Map<String, dynamic> payload = {'title': title};
    if (participants != null && participants.isNotEmpty) payload['participants'] = participants;
    final resp = await http.post(url, headers: defaultHeaders, body: json.encode(payload)).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final Map<String, dynamic> data = json.decode(resp.body) as Map<String, dynamic>;
      return data['id']?.toString() ?? '';
    }
    throw Exception('Failed to create conversation: ${resp.statusCode} ${resp.body}');
  }

  Future<List<MessageModel>> getReceivedMessagesByUserId(String userId) async {
    final url = Uri.parse('$baseUrl/messaging/received/$userId');
    final resp = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 10));
    // debug log
    print('[MessagingService] GET $url -> status=${resp.statusCode} body=${resp.body}');
    if (resp.statusCode == 200) {
      final List<dynamic> data = json.decode(resp.body) as List<dynamic>;
      return data.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load received messages: ${resp.statusCode} ${resp.body}');
  }

  Future<List<dynamic>> getConversations() async {
    final url = Uri.parse('$baseUrl/messaging/conversations');
    final resp = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 10));
    // debug log
    print('[MessagingService] GET $url -> status=${resp.statusCode} body=${resp.body}');
    if (resp.statusCode == 200) {
      final body = resp.body.trim();
      if (body.isEmpty) return <dynamic>[];
      return json.decode(body) as List<dynamic>;
    }
    throw Exception('Failed to fetch conversations: ${resp.statusCode} ${resp.body}');
  }

  Future<void> deleteConversationRemote(String conversationId) async {
    final url = Uri.parse('$baseUrl/messaging/conversations/$conversationId');
    final resp = await http.delete(url, headers: defaultHeaders).timeout(const Duration(seconds: 10));
    print('[MessagingService] DELETE $url -> status=${resp.statusCode} body=${resp.body}');
    if (resp.statusCode == 200 || resp.statusCode == 204) return;
    throw Exception('Failed to delete conversation: ${resp.statusCode} ${resp.body}');
  }
}
