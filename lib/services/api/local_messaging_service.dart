import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slatereduc/models/message_model.dart';

class LocalMessagingService {
  // Singleton instance so all parts of the app share the same stream/controller
  static final LocalMessagingService _instance = LocalMessagingService._internal();
  factory LocalMessagingService() => _instance;
  LocalMessagingService._internal();

  // Private stream controller and persistence key used by the service
  final StreamController<List<Map<String, dynamic>>> _conversationsController = StreamController<List<Map<String, dynamic>>>.broadcast();
  static const String _convsKey = 'local_messaging_conversations';
  static const String _pairIndexKey = 'local_messaging_pair_index';

  String _normalizePairKey(List<String> participants) {
    final cleaned = participants
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.trim())
        .toList()
      ..sort();
    return cleaned.join('|');
  }

  Future<Map<String, dynamic>> _loadPairIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pairIndexKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(json.decode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _savePairIndex(Map<String, dynamic> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pairIndexKey, json.encode(map));
  }

  Future<String?> findConversationIdForParticipants(List<String> participants) async {
    final key = _normalizePairKey(participants);
    if (key.isEmpty) return null;
    final map = await _loadPairIndex();
    final entry = map[key];
    if (entry == null) return null;
    try {
      if (entry is String) return entry;
      if (entry is Map && entry['conversation_id'] != null) return entry['conversation_id'].toString();
    } catch (_) {}
    return null;
  }

  Future<void> cacheConversationForParticipants({required String conversationId, required List<String> participants, Map<String, dynamic>? meta}) async {
    final key = _normalizePairKey(participants);
    if (key.isEmpty || conversationId.isEmpty) return;
    final map = await _loadPairIndex();
    map[key] = {
      'conversation_id': conversationId,
      'meta': meta ?? {},
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _savePairIndex(map);
  }

  Future<void> _removeFromPairIndex(String conversationId) async {
    final map = await _loadPairIndex();
    final keysToRemove = <String>[];
    map.forEach((key, value) {
      try {
        if (value == conversationId) keysToRemove.add(key);
        if (value is Map && (value['conversation_id']?.toString() ?? '') == conversationId) keysToRemove.add(key);
      } catch (_) {}
    });
    if (keysToRemove.isEmpty) return;
    for (final key in keysToRemove) {
      map.remove(key);
    }
    await _savePairIndex(map);
  }

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

  Future<String> createLocalConversation({required String title, Map<String, dynamic>? meta, List<String>? participants}) async {
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
    if (participants != null && participants.length >= 2) {
      await cacheConversationForParticipants(conversationId: id, participants: participants, meta: meta);
    }
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
    try {
      final participants = <String>[];
      if (apiConv['participants'] is List) {
        for (final p in apiConv['participants']) {
          if (p == null) continue;
          if (p is String && p.isNotEmpty) participants.add(p);
          else if (p is Map) {
            final pid = (p['id'] ?? p['user_id'] ?? p['idUser'] ?? p['participant_id'])?.toString();
            if (pid != null && pid.isNotEmpty) participants.add(pid);
          }
        }
      }
      if (participants.length >= 2) {
        await cacheConversationForParticipants(conversationId: id, participants: participants, meta: apiConv['meta'] as Map<String, dynamic>?);
      }
    } catch (_) {}
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
    await _removeFromPairIndex(conversationId);
    await _emitConversations();
  }

  Future<void> cacheMessages(String conversationId, List<MessageModel> messages) async {
    final mapped = messages
        .map((m) => {
              'id': m.id,
              'content': m.content,
              'sender_id': m.senderId,
              'receiver_id': m.receiverId,
              'id_conversation': m.idConversation,
              'created_at': m.createdAt.toIso8601String(),
              'updated_at': m.updatedAt.toIso8601String(),
              if (m.voiceUrl != null && m.voiceUrl!.isNotEmpty) 'voice_url': m.voiceUrl,
              if (m.voiceDuration != null) 'duration_ms': m.voiceDuration!.inMilliseconds,
            })
        .toList();
    await saveLocalMessages(conversationId, mapped);
  }

  // Close controller when app shuts down (optional)
  void dispose() {
    try {
      _conversationsController.close();
    } catch (_) {}
  }
}
