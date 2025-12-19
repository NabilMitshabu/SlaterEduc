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

  /// Crée une conversation locale de manière idempotente pour une paire de participants.
  /// Si une conversation existe déjà dans l'index de paire, elle est retournée.
  Future<String> createOrReuseLocalConversationForParticipants({
    required String title,
    required List<String> participants,
    Map<String, dynamic>? meta,
  }) async {
    final normalized = participants.where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList();
    if (normalized.length < 2) {
      return createLocalConversation(title: title, meta: meta, participants: participants);
    }

    final existing = await findConversationIdForParticipants(normalized);
    if (existing != null && existing.isNotEmpty) {
      // Met à jour le meta/titre si nécessaire (best effort)
      try {
        if (meta != null) {
          final convs = await getConversations();
          final idx = convs.indexWhere((c) => (c['id']?.toString() ?? '') == existing);
          if (idx >= 0) {
            final updated = Map<String, dynamic>.from(convs[idx]);
            updated['title'] ??= title;
            final mergedMeta = Map<String, dynamic>.from((updated['meta'] as Map?) ?? {});
            mergedMeta.addAll(meta);
            updated['meta'] = mergedMeta;
            convs[idx] = updated;
            await saveConversations(convs);
          }
        }
      } catch (_) {}
      return existing;
    }

    return createLocalConversation(title: title, meta: meta, participants: participants);
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

  /// - Fusionne les messages locaux (local_messages:<id>) et les messages inclus dans conv['messages']
  Future<void> mergeDuplicateConversationsByPeer({required Set<String> familyIds}) async {
    if (familyIds.isEmpty) return;

    String peerKey(Map<String, dynamic> conv) {
      String? other;
      try {
        if (conv['participants'] is List) {
          for (final p in (conv['participants'] as List)) {
            if (p == null) continue;
            final pid = p is String
                ? p
                : (p is Map ? (p['id'] ?? p['user_id'] ?? p['participant_id'] ?? p['idUser'])?.toString() : null);
            if (pid == null || pid.isEmpty) continue;
            if (!familyIds.contains(pid)) {
              other = pid;
              break;
            }
          }
        }
        if ((other == null || other.isEmpty) && conv['messages'] is List && (conv['messages'] as List).isNotEmpty) {
          final last = Map<String, dynamic>.from(((conv['messages'] as List).last) as Map);
          final s = (last['sender_id'] ?? last['senderId'])?.toString();
          final r = (last['receiver_id'] ?? last['receiverId'])?.toString();
          if (s != null && s.isNotEmpty && !familyIds.contains(s)) other = s;
          if ((other == null || other.isEmpty) && r != null && r.isNotEmpty && !familyIds.contains(r)) other = r;
        }
        if ((other == null || other.isEmpty) && conv['meta'] is Map) {
          final meta = conv['meta'] as Map;
          for (final k in ['participant', 'participant_id', 'user_id', 'remote_participant']) {
            final v = meta[k]?.toString();
            if (v != null && v.isNotEmpty && !familyIds.contains(v)) {
              other = v;
              break;
            }
          }
        }
      } catch (_) {}
      if (other != null && other.isNotEmpty) return 'peer:$other';
      final id = (conv['id'] ?? conv['meta']?['remote_id'] ?? '').toString();
      return id.isNotEmpty ? 'id:$id' : 'unknown';
    }

    DateTime updatedAt(Map<String, dynamic> conv) {
      try {
        DateTime fromIso(String? s) => DateTime.tryParse(s ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        // Prefer last message
        if (conv['messages'] is List && (conv['messages'] as List).isNotEmpty) {
          final msgs = List<Map<String, dynamic>>.from((conv['messages'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
          msgs.sort((a, b) => fromIso((a['updated_at'] ?? a['created_at'])?.toString()).compareTo(fromIso((b['updated_at'] ?? b['created_at'])?.toString())));
          final last = msgs.last;
          return fromIso((last['updated_at'] ?? last['created_at'])?.toString());
        }
        return fromIso((conv['updated_at'] ?? conv['created_at'])?.toString());
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    final convs = await getConversations();
    if (convs.length <= 1) return;

    // group
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final c in convs) {
      final key = peerKey(c);
      groups.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(c);
    }

    bool changed = false;
    final List<Map<String, dynamic>> result = [];

    for (final entry in groups.entries) {
      final list = entry.value;
      if (list.length == 1) {
        result.add(list.first);
        continue;
      }

      // choose keeper
      list.sort((a, b) => updatedAt(b).compareTo(updatedAt(a)));
      final keeper = Map<String, dynamic>.from(list.first);
      final keeperId = keeper['id']?.toString() ?? '';

      // merge messages from all into keeper
      final Map<String, Map<String, dynamic>> byMsgId = {};
      Future<void> absorbMessagesFromConv(Map<String, dynamic> c) async {
        // 1) embedded messages
        try {
          if (c['messages'] is List) {
            for (final raw in (c['messages'] as List)) {
              if (raw == null || raw is! Map) continue;
              final m = Map<String, dynamic>.from(raw);
              final key = (m['id'] ?? m['local_id'] ?? '${m['created_at']}-${m['content']}')?.toString();
              if (key == null || key.isEmpty) continue;
              byMsgId[key] = m;
            }
          }
        } catch (_) {}
        // 2) local messages store
        try {
          final cid = c['id']?.toString() ?? '';
          if (cid.isEmpty) return;
          final localMsgs = await getLocalMessages(cid);
          for (final m in localMsgs) {
            final key = (m['id'] ?? m['local_id'] ?? '${m['created_at']}-${m['content']}')?.toString();
            if (key == null || key.isEmpty) continue;
            byMsgId[key] = Map<String, dynamic>.from(m);
          }
        } catch (_) {}
      }

      for (final c in list) {
        await absorbMessagesFromConv(c);
      }

      final merged = byMsgId.values.toList();
      merged.sort((a, b) {
        final da = DateTime.tryParse((a['updated_at'] ?? a['created_at'])?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse((b['updated_at'] ?? b['created_at'])?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return da.compareTo(db);
      });
      keeper['messages'] = merged;
      if (merged.isNotEmpty) {
        keeper['created_at'] ??= merged.first['created_at']?.toString();
        keeper['updated_at'] = (merged.last['updated_at'] ?? merged.last['created_at'])?.toString();
      }

      result.add(keeper);

      // delete extras and their local messages
      for (final extra in list.skip(1)) {
        final extraId = extra['id']?.toString() ?? '';
        if (extraId.isEmpty) continue;
        changed = true;
        if (extraId != keeperId) {
          await deleteLocalMessages(extraId);
          await _removeFromPairIndex(extraId);
        }
      }

      // persist merged messages for keeper
      if (keeperId.isNotEmpty) {
        try {
          await saveLocalMessages(keeperId, merged);
        } catch (_) {}
      }
    }

    if (changed) {
      await saveConversations(result);
    }
  }

  // Close controller when app shuts down (optional)
  void dispose() {
    try {
      _conversationsController.close();
    } catch (_) {}
  }
}
