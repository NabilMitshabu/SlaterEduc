import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:slatereduc/services/app_colors.dart';

class ChatCorrespondent {
  final String name;
  final String? avatarUrl;
  final String? otherUserId;
  final String? otherPersonnelId;

  ChatCorrespondent({
    required this.name,
    this.avatarUrl,
    this.otherUserId,
    this.otherPersonnelId,
  });
}

Widget buildContactAvatar(BuildContext context, {required String name, String? avatarUrl, double radius = 20}) {
  final url = avatarUrl ?? '';
  final isPlaceholder = url.isEmpty || url.contains('randomuser.me') || url.contains('lego');
  if (!isPlaceholder) {
    return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
  }
  final initial = name.isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : '';
  return CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.secondaryColor(context),
    child: Text(
      initial,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
  );
}

bool isConversationUnread(Map<String, dynamic> conv, {required String? currentUserId}) {
  try {
    final meta = (conv['meta'] as Map?)?.cast<String, dynamic>();
    final seenAtStr = meta?['seen_at']?.toString();
    DateTime? seenAt;
    if (seenAtStr != null && seenAtStr.isNotEmpty) {
      seenAt = DateTime.tryParse(seenAtStr);
    }
    final msgs = conv['messages'] as List?;
    if (msgs == null || msgs.isEmpty) return false;
    for (final raw in msgs) {
      if (raw == null) continue;
      if (raw is! Map) continue;
      final m = raw.cast<String, dynamic>();
      final senderId = (m['sender_id'] ?? m['senderId'])?.toString();
      if (senderId == null || senderId.isEmpty) continue;
      final isFromMe = currentUserId != null && currentUserId.isNotEmpty && senderId == currentUserId;
      if (isFromMe) continue;
      final tsStr = (m['updated_at'] ?? m['created_at'])?.toString();
      final ts = tsStr != null && tsStr.isNotEmpty ? DateTime.tryParse(tsStr) : null;
      if (seenAt == null) {
        // jamais vu -> au moins un message entrant => non-lu
        return true;
      }
      if (ts != null && ts.isAfter(seenAt)) {
        return true;
      }
    }
  } catch (_) {}
  return false;
}

/// Essaie d'extraire l'id utilisateur courant depuis SharedPreferences JSON (même heuristique que d'autres écrans).
String? tryExtractCurrentUserIdFromPrefsJson(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final parsed = json.decode(raw);
    String? tryExtract(dynamic obj) {
      if (obj == null) return null;
      if (obj is String) return null;
      if (obj is Map) {
        final keys = ['id', 'user_id', 'idUser', 'id_user', 'id_eleve', 'idEleve'];
        for (final k in keys) {
          if (obj.containsKey(k) && obj[k] != null) return obj[k].toString();
        }
        if (obj.containsKey('data')) return tryExtract(obj['data']);
        if (obj.containsKey('user')) return tryExtract(obj['user']);
      }
      return null;
    }

    return tryExtract(parsed);
  } catch (_) {
    return null;
  }
}

/// Résout le correspondant d'une conversation: le nom affiché doit être le nom du correspondant,
/// peu importe qui a envoyé le dernier message.
///
/// Priorité:
/// 1) meta.participant_name (défini par NewChatScreen)
/// 2) meta.receiver_name/name/username/firstname
/// 3) "title" nettoyé (ex: "Chat avec XXX" -> XXX)
/// 4) fallback "Conversation"
ChatCorrespondent resolveCorrespondentFromConversation(
  Map<String, dynamic> conv, {
  required String? currentUserId,
}) {
  String name = '';
  String? otherId;

  try {
    final meta = (conv['meta'] as Map?)?.cast<String, dynamic>();

    final participantName = meta?['participant_name']?.toString().trim();
    if (participantName != null && participantName.isNotEmpty) {
      name = participantName;
    }

    if (name.isEmpty) {
      final candidates = [meta?['receiver_name'], meta?['name'], meta?['username'], meta?['firstname']];
      for (final c in candidates) {
        final v = c?.toString().trim();
        if (v != null && v.isNotEmpty) {
          name = v;
          break;
        }
      }
    }

    // Id du correspondant via participants
    if (conv['participants'] is List) {
      for (final p in (conv['participants'] as List)) {
        if (p == null) continue;
        if (p is String && p.isNotEmpty) {
          if (currentUserId == null || currentUserId.isEmpty || p != currentUserId) {
            otherId = p;
            break;
          }
        } else if (p is Map) {
          final pid = (p['id'] ?? p['user_id'] ?? p['participant_id'] ?? p['idUser'])?.toString();
          if (pid != null && pid.isNotEmpty) {
            if (currentUserId == null || currentUserId.isEmpty || pid != currentUserId) {
              otherId = pid;
              break;
            }
          }
        }
      }
    }

    // Fallback: depuis le dernier message
    if ((otherId == null || otherId.isEmpty) && conv['messages'] is List && (conv['messages'] as List).isNotEmpty) {
      final last = Map<String, dynamic>.from(((conv['messages'] as List).last) as Map);
      final s = (last['sender_id'] ?? last['senderId'])?.toString();
      final r = (last['receiver_id'] ?? last['receiverId'])?.toString();
      if (currentUserId != null && currentUserId.isNotEmpty) {
        if (s != null && s.isNotEmpty && s != currentUserId) otherId = s;
        if ((otherId == null || otherId.isEmpty) && r != null && r.isNotEmpty && r != currentUserId) otherId = r;
      } else {
        otherId = (s != null && s.isNotEmpty) ? s : r;
      }
    }

    // Fallback meta participant id
    if ((otherId == null || otherId.isEmpty) && meta != null) {
      final pid = (meta['participant'] ?? meta['participant_id'] ?? meta['user_id'] ?? meta['remote_participant'])?.toString();
      if (pid != null && pid.isNotEmpty) otherId = pid;
    }

    if (name.isEmpty) {
      final t = conv['title']?.toString().trim() ?? '';
      if (t.isNotEmpty) {
        final lower = t.toLowerCase();
        if (lower.startsWith('chat avec ')) {
          name = t.substring('chat avec '.length).trim();
        } else {
          name = t;
        }
      }
    }
  } catch (_) {}

  if (name.trim().isEmpty) name = 'Conversation';

  return ChatCorrespondent(
    name: name.trim(),
    avatarUrl: ((conv['meta'] as Map?)?.cast<String, dynamic>())?['avatar']?.toString(),
    otherUserId: otherId,
  );
}
