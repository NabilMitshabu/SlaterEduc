import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class LocalMessagingService {
  static const String _convsKey = 'local_conversations';

  // broadcast stream to notify UI when local conversations/messages change
  final StreamController<List<Map<String, dynamic>>> _conversationsController = StreamController.broadcast();

  Stream<List<Map<String, dynamic>>> get conversationsStream => _conversationsController.stream;

  Future<void> _emitConversations() async {
    try {
      final convs = await getConversations();
      if (!_conversationsController.isClosed) _conversationsController.add(convs);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_convsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> data = json.decode(raw) as List<dynamic>;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveConversations(List<Map<String, dynamic>> convs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_convsKey, json.encode(convs));
    await _emitConversations();
  }

  Future<String> createLocalConversation({required String title, Map<String, dynamic>? meta}) async {
    final convs = await getConversations();
    final id = 'local-${DateTime.now().millisecondsSinceEpoch}';
    final conv = {
      'id': id,
      'title': title,
      'status': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'messages': [],
      'meta': meta ?? {},
    };
    convs.insert(0, conv);
    await saveConversations(convs);
    return id;
  }

  Future<List<Map<String, dynamic>>> getLocalMessages(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'local_messages:$conversationId';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> data = json.decode(raw) as List<dynamic>;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveLocalMessages(String conversationId, List<Map<String, dynamic>> msgs) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'local_messages:$conversationId';
    await prefs.setString(key, json.encode(msgs));
  }

  Future<void> addLocalMessage(String conversationId, Map<String, dynamic> msg) async {
    final msgs = await getLocalMessages(conversationId);
    msgs.add(msg);
    await saveLocalMessages(conversationId, msgs);
  }

  Future<void> updateLocalMessage(String conversationId, String localId, Map<String, dynamic> updated) async {
    final msgs = await getLocalMessages(conversationId);
    final idx = msgs.indexWhere((m) => (m['local_id'] ?? '') == localId || (m['id'] ?? '') == localId);
    if (idx >= 0) {
      msgs[idx] = {...msgs[idx], ...updated};
      await saveLocalMessages(conversationId, msgs);
    }
  }

  Future<void> mergeAndSaveConversationFromApi(Map<String, dynamic> apiConv) async {
    final convs = await getConversations();
    final id = apiConv['id']?.toString();
    if (id == null) return;
    final idx = convs.indexWhere((c) => c['id'] == id || (c['meta']?['remote_id'] == id));
    final toSave = Map<String, dynamic>.from(apiConv);
    // ensure messages is list
    if (!toSave.containsKey('messages') || toSave['messages'] == null) toSave['messages'] = [];
    if (idx >= 0) {
      convs[idx] = toSave;
    } else {
      convs.insert(0, toSave);
    }
    await saveConversations(convs);
    await _emitConversations();
  }

  Future<void> deleteLocalMessages(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'local_messages:$conversationId';
    await prefs.remove(key);
  }

  Future<void> deleteConversation(String conversationId) async {
    final convs = await getConversations();
    convs.removeWhere((c) => (c['id']?.toString() ?? '') == conversationId || (c['meta']?['remote_id']?.toString() ?? '') == conversationId);
    await saveConversations(convs);
    await deleteLocalMessages(conversationId);
    await _emitConversations();
  }

  // Close controller when app shuts down (optional)
  void dispose() {
    try {
      _conversationsController.close();
    } catch (_) {}
  }
}
