import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:slatereduc/models/message_model.dart';
import 'api_config.dart';
import 'school_service.dart';
import 'local_messaging_service.dart';
import 'user_directory_service.dart';

class MessagingService {
  final String baseUrl;
  final Map<String, String> defaultHeaders;
  final LocalMessagingService _localService = LocalMessagingService();
  final UserDirectoryService _userDirectory = UserDirectoryService();

  MessagingService({
    this.baseUrl = apiBaseUrl,
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
    String? clientMessageId,
  }) async {
    print('[sendMessage] senderId=$senderId, receiverId=$receiverId, idConversation=$idConversation, content=$content');
    if (receiverId.isEmpty) {
      throw Exception('receiverId ne doit pas être vide');
    }
    final url = Uri.parse('$baseUrl/messaging/messages');
    final Map<String, dynamic> payload = {
      'content': content,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'id_conversation': idConversation,
    };
    if (clientMessageId != null && clientMessageId.isNotEmpty) payload['client_message_id'] = clientMessageId;
    final body = json.encode(payload);
    final resp = await http.post(url, headers: defaultHeaders, body: body).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final Map<String, dynamic> data = json.decode(resp.body) as Map<String, dynamic>;
      return MessageModel.fromJson(data);
    }
    // include response body to help debug 422 validation errors
    throw Exception('Failed to send message: ${resp.statusCode} ${resp.body}');
  }

  /// Create a conversation. Optionally include [participants] as a list of user/person ids.
  /// If [idempotencyKey] is provided, it will be sent as header 'Idempotency-Key' to help server dedupe.
  Future<String> createConversation({required String title, List<String>? participants, String? idempotencyKey}) async {
    final url = Uri.parse('$baseUrl/messaging/conversations');
    final Map<String, dynamic> payload = {'title': title};
    if (participants != null && participants.isNotEmpty) payload['participants'] = participants;
    final headers = Map<String, String>.from(defaultHeaders);
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) headers['Idempotency-Key'] = idempotencyKey;
    final resp = await http.post(url, headers: headers, body: json.encode(payload)).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final Map<String, dynamic> data = json.decode(resp.body) as Map<String, dynamic>;
      return data['id']?.toString() ?? data['conversation_id']?.toString() ?? '';
    }
    throw Exception('Failed to create conversation: ${resp.statusCode} ${resp.body}');
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

    if (resp.statusCode == 204 || resp.statusCode == 404 || resp.statusCode == 405) {
      print('[MessagingService] conversations endpoint returned ${resp.statusCode} — returning empty list instead of throwing');
      return <dynamic>[];
    }

    print('[MessagingService] Unexpected status ${resp.statusCode} when fetching conversations: ${resp.body}');
    return <dynamic>[];
  }

  Future<String?> _localFindConversationByParticipants(List<String> participants) async {
    try {
      return await _localService.findConversationIdForParticipants(participants);
    } catch (_) {
      return null;
    }
  }

  Future<void> _localCacheConversation(String convId, List<String> participants, {Map<String, dynamic>? meta}) async {
    try {
      await _localService.cacheConversationForParticipants(conversationId: convId, participants: participants, meta: meta);
    } catch (_) {}
  }

  /// Try to find an existing conversation remotely by matching participant ids in conversations list.
  /// Returns the conversation id if found, otherwise null.
  Future<String?> findConversationByParticipants(List<String> participants) async {
    final normalized = participants.where((e) => e.isNotEmpty).toList();
    if (normalized.length < 2) return null;

    final local = await _localFindConversationByParticipants(normalized);
    if (local != null && local.isNotEmpty) return local;

    try {
      final convs = await getConversations();
      final target = normalized.toSet();
      for (final raw in convs) {
        try {
          final Map<String, dynamic> c = Map<String, dynamic>.from(raw as Map);
          final parts = <String>{};
          if (c['participants'] is List) {
            for (final p in c['participants']) {
              if (p == null) continue;
              if (p is String && p.isNotEmpty) parts.add(p);
              else if (p is Map) {
                final pid = (p['id'] ?? p['user_id'] ?? p['idUser'] ?? p['participant_id'])?.toString();
                if (pid != null && pid.isNotEmpty) parts.add(pid);
              }
            }
          }
          if (parts.isEmpty && c['messages'] is List) {
            for (final m in c['messages']) {
              try {
                final msg = Map<String, dynamic>.from(m as Map);
                final s = (msg['sender_id'] ?? msg['senderId'])?.toString();
                final r = (msg['receiver_id'] ?? msg['receiverId'])?.toString();
                if (s != null && s.isNotEmpty) parts.add(s);
                if (r != null && r.isNotEmpty) parts.add(r);
              } catch (_) {}
            }
          }
          if (parts.isEmpty && c['meta'] is Map) {
            final meta = c['meta'] as Map;
            for (final key in ['participant', 'participant_id', 'user_id', 'remote_participant']) {
              final val = meta[key]?.toString();
              if (val != null && val.isNotEmpty) parts.add(val);
            }
          }
          if (parts.isNotEmpty && parts.containsAll(target) && target.containsAll(parts)) {
            final convId = c['id']?.toString();
            await _localCacheConversation(convId ?? '', normalized, meta: c['meta'] as Map<String, dynamic>?);
            return convId;
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  /// Ensures a conversation exists for the given participants: tries remote find first, otherwise creates.
  /// Returns the conversation id (may be remote id or empty string on failure).
  Future<String> createOrFindConversation({required String title, required List<String> participants, String? idempotencyKey}) async {
    final normalized = participants.where((e) => e.isNotEmpty).toList();
    if (normalized.length < 2) return '';

    final local = await _localFindConversationByParticipants(normalized);
    if (local != null && local.isNotEmpty) return local;

    final remoteFound = await findConversationByParticipants(normalized);
    if (remoteFound != null && remoteFound.isNotEmpty) return remoteFound;

    final convId = await createConversation(title: title, participants: normalized, idempotencyKey: idempotencyKey);
    if (convId.isNotEmpty) {
      await _localCacheConversation(convId, normalized);
    }
    return convId;
  }

  /// Create or find a conversation for a specific course/class.
  /// Resolves the professor (user id) for the course via SchoolService and ensures the conversation
  /// contains the [parentUserId] and the professor user id.
  /// Returns the conversation id if found/created, otherwise empty string on failure.
  Future<String> createOrFindConversationForCourse({required String title, String? idCours, String? idClasse, required String parentUserId, String? idempotencyKey}) async {
    final school = SchoolService(baseUrl: baseUrl, headers: defaultHeaders);
    try {
      final identifiers = await school.getProfessorIdentifiers(idCours: idCours, idClasse: idClasse);
      final participants = <String>[];
      if (parentUserId.isNotEmpty) participants.add(parentUserId);
      if (identifiers?['user_id']?.isNotEmpty == true) {
        participants.add(identifiers!['user_id']!);
      } else if (identifiers?['personnel_id']?.isNotEmpty == true) {
        participants.add(identifiers!['personnel_id']!);
      }

      if (participants.length < 2) {
        return '';
      }

      final convId = await createOrFindConversation(title: title, participants: participants, idempotencyKey: idempotencyKey);
      return convId;
    } catch (e) {
      print('[MessagingService] createOrFindConversationForCourse error: $e');
      return '';
    }
  }

  Future<List<MessageModel>> getReceivedMessagesByUserId(String userId) async {
    if (userId.isEmpty) return <MessageModel>[];
    final url = Uri.parse('$baseUrl/messaging/received/$userId');
    final resp = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) {
      final List<dynamic> data = json.decode(resp.body) as List<dynamic>;
      return data.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (resp.statusCode == 204 || resp.statusCode == 404) {
      return <MessageModel>[];
    }
    throw Exception('Failed to fetch received messages: ${resp.statusCode} ${resp.body}');
  }

  Future<void> deleteConversationRemote(String conversationId) async {
    if (conversationId.isEmpty) return;
    final url = Uri.parse('$baseUrl/messaging/conversations/$conversationId');
    final resp = await http.delete(url, headers: defaultHeaders).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200 || resp.statusCode == 204 || resp.statusCode == 404) {
      return;
    }
    throw Exception('Failed to delete conversation $conversationId: ${resp.statusCode} ${resp.body}');
  }

  Future<MessageModel> sendVoiceMessage({
    required File voiceFile,
    required String senderId,
    required String receiverId,
    required String idConversation,
    Duration? duration,
    String? clientMessageId,
    String? content,
  }) async {
    if (!voiceFile.existsSync()) {
      throw Exception('Le fichier audio est introuvable: ${voiceFile.path}');
    }
    final url = Uri.parse('$baseUrl/messaging/voice');
    final request = http.MultipartRequest('POST', url);
    // Do not forward 'Content-Type' from defaultHeaders for multipart requests —
    // MultipartRequest will set the correct Content-Type (with boundary). If we
    // keep 'application/json' the server may not parse form fields and will
    // return validation errors (422) for missing fields.
    final headers = Map<String, String>.from(defaultHeaders);
    // Remove explicit Content-Type so MultipartRequest can set a proper
    // multipart/form-data boundary content-type. Keep other headers (e.g. Authorization)
    headers.remove('Content-Type');
    // Ensure server accepts JSON responses — some backends validate Accept header
    // before parsing multipart fields.
    headers['Accept'] = 'application/json';
    request.headers.addAll(headers);
    request.fields['sender_id'] = senderId;
    request.fields['receiver_id'] = receiverId;
    request.fields['id_conversation'] = idConversation;
    if (clientMessageId != null && clientMessageId.isNotEmpty) request.fields['client_message_id'] = clientMessageId;
    if (content != null) request.fields['content'] = content;

    // Debug logs: help diagnose 422 validation errors on the server by
    // printing the form fields and headers that will be sent.
    print('[sendVoiceMessage] multipart fields=${request.fields}');
    print('[sendVoiceMessage] multipart headers before send=${request.headers}');

    if (duration != null) {
      request.fields['duration_ms'] = duration.inMilliseconds.toString();
    }
    request.files.add(await http.MultipartFile.fromPath('file', voiceFile.path));

    final response = await request.send().timeout(const Duration(seconds: 20));
    final body = await response.stream.bytesToString();
    if (response.statusCode == 200 || response.statusCode == 201) {
      final Map<String, dynamic> data = json.decode(body) as Map<String, dynamic>;
      return MessageModel.fromJson(data);
    }
    throw Exception('Failed to send voice message: ${response.statusCode} $body');
  }

  // Normalise une paire d'identifiants en clé triée (A|B)
  String _pairKey(String a, String b) {
    final list = [a, b]..sort();
    return list.join('|');
  }

  /// Construit des conversations locales pour un utilisateur à partir des messages reçus.
  /// - Regroupe par paire {sender_id, receiver_id} (triée) pour éviter les doublons A→B / B→A
  /// - Sélectionne un id_conversation (le plus récent vu) si disponible, sinon génère un id local stable basé sur la paire
  /// - Alimente le cache local (conversations + index paires)
  Future<List<Map<String, dynamic>>> buildLocalConversationsForUser(String idUser) async {
    if (idUser.isEmpty) return <Map<String, dynamic>>[];
    try {
      final received = await getReceivedMessagesByUserId(idUser);
      if (received.isEmpty) return <Map<String, dynamic>>[];

      // Regrouper par paire triée
      final Map<String, List<MessageModel>> byPair = {};
      final Map<String, String> lastConvIdByPair = {};
      for (final m in received) {
        final s = m.senderId;
        final r = m.receiverId;
        if (s.isEmpty && r.isEmpty) continue;
        final key = _pairKey(s, r);
        byPair.putIfAbsent(key, () => <MessageModel>[]).add(m);
        // garder le dernier id_conversation observé (le plus récent l'emporte)
        if (m.idConversation.isNotEmpty) {
          final prev = lastConvIdByPair[key];
          if (prev == null || m.updatedAt.isAfter(received.firstWhere((x)=>x.idConversation==prev, orElse: ()=>m).updatedAt)) {
            lastConvIdByPair[key] = m.idConversation;
          }
        }
      }

      final List<Map<String, dynamic>> convs = [];
      for (final entry in byPair.entries) {
        final pairKey = entry.key;
        final msgs = entry.value..sort((a,b)=>a.createdAt.compareTo(b.createdAt));
        if (msgs.isEmpty) continue;
        final first = msgs.first;
        // déduire l'autre participant vs idUser
        String otherId = first.senderId == idUser ? first.receiverId : first.senderId;
        if (otherId.isEmpty) {
          // chercher dans les messages suivants
          for (final m in msgs) {
            final cand = m.senderId == idUser ? m.receiverId : m.senderId;
            if (cand.isNotEmpty && cand != idUser) { otherId = cand; break; }
          }
        }
        if (otherId.isEmpty) continue;

        // choisir un id de conversation
        final chosenConvId = (lastConvIdByPair[pairKey] != null && lastConvIdByPair[pairKey]!.isNotEmpty)
            ? lastConvIdByPair[pairKey]!
            : 'local-pair-${pairKey.replaceAll('|', '-')}' ;

        // Résoudre le nom du correspondant pour affichage
        String displayName = '';
        try {
          displayName = await _userDirectory.resolveUserName(otherId);
        } catch (_) {}
        if (displayName.isEmpty) displayName = 'Conversation';

        final participants = <String>[idUser, otherId];
        final conv = {
          'id': chosenConvId,
          'title': displayName,
          'participants': participants,
          'messages': msgs.map((m) => m.toJson()).toList(),
          'created_at': msgs.first.createdAt.toIso8601String(),
          'updated_at': msgs.last.updatedAt.toIso8601String(),
          'meta': {
            'remote_participant': otherId,
            if (!chosenConvId.startsWith('local-')) 'remote_id': chosenConvId,
            'participant_name': displayName,
          },
        };

        // Persister localement et indexer la paire -> convId
        try {
          await _localService.mergeAndSaveConversationFromApi(conv);
          await _localService.cacheConversationForParticipants(conversationId: chosenConvId, participants: participants, meta: conv['meta'] as Map<String, dynamic>?);
        } catch (_) {}
        convs.add(conv);
      }

      return convs;
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
