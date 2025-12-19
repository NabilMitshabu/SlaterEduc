import 'package:flutter/material.dart';
import 'NewChatScreen.dart';
import 'chat_screen.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:slatereduc/services/app_localizations.dart';
import 'package:slatereduc/services/api/messaging_service.dart';
import 'package:slatereduc/services/api/local_messaging_service.dart';
import 'package:slatereduc/services/api/user_directory_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slatereduc/services/auth/user_identity_helper.dart';
import 'chat_avatar_helpers.dart';
import 'widgets/conversation_tile.dart';
import 'package:slatereduc/ui/widgets/correspondent_name_widget.dart';
import 'dart:async';

class ChatListItem {
  final String name;
  final String message;
  final String time;
  final bool isUnread;
  final String avatarUrl;
  final String? conversationId; // optional conversation id to open API-backed chat

  ChatListItem({
    required this.name,
    required this.message,
    required this.time,
    required this.isUnread,
    required this.avatarUrl,
    this.conversationId,
  });
}

class ChatTab extends StatefulWidget {
  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final MessagingService _messagingService = MessagingService();
  final LocalMessagingService _localService = LocalMessagingService();
  final UserDirectoryService _userDirectory = UserDirectoryService();
  final UserIdentityHelper _identity = UserIdentityHelper.instance;
  StreamSubscription<List<Map<String, dynamic>>>? _localConvSub;
  bool _isLoading = true;
  List<dynamic> _conversations = [];
  String? _error;

  Set<String> _readFamilyIdsFast() {
    // best-effort sync placeholder: la vraie valeur sera récupérée en async dans _loadConversations / listener.
    return <String>{};
  }

  /// Calcule une clé d'unicité "pair" robuste: tout id dans familyIds est traité comme "moi".
  /// Ainsi, une même discussion avec PROF NEVILLE ne sera pas dupliquée si l'expéditeur est le parent ou l'enfant.
  String _conversationPeerKey(Map<String, dynamic> conv, {required Set<String> familyIds}) {
    try {
      // 1) Essaie d'identifier l'autre participant via participants/messages/meta,
      //    en considérant n'importe quel id de familyIds comme "moi".
      String? other;

      // participants
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

      // last message
      if ((other == null || other.isEmpty) && conv['messages'] is List && (conv['messages'] as List).isNotEmpty) {
        final last = Map<String, dynamic>.from(((conv['messages'] as List).last) as Map);
        final s = (last['sender_id'] ?? last['senderId'])?.toString();
        final r = (last['receiver_id'] ?? last['receiverId'])?.toString();
        if (s != null && s.isNotEmpty && !familyIds.contains(s)) other = s;
        if ((other == null || other.isEmpty) && r != null && r.isNotEmpty && !familyIds.contains(r)) other = r;
      }

      // meta fallback
      if ((other == null || other.isEmpty) && conv['meta'] is Map) {
        final meta = conv['meta'] as Map<String, dynamic>;
        final pid = (meta['participant'] ?? meta['participant_id'] ?? meta['user_id'] ?? meta['remote_participant'])?.toString();
        if (pid != null && pid.isNotEmpty && !familyIds.contains(pid)) other = pid;
      }

      if (other != null && other.isNotEmpty) {
        return 'peer:$other';
      }
    } catch (_) {}

    // Dernier recours: id conversation
    final remoteId = (conv['id'] ?? conv['meta']?['remote_id'] ?? '').toString();
    if (remoteId.isNotEmpty) return 'id:$remoteId';
    return 'local:${conv['title'] ?? ''}';
  }

  Future<void> _cleanupLocalDuplicates(List<Map<String, dynamic>> convs, {required Set<String> familyIds}) async {
    try {
      // Nettoyage profond: fusionne les conversations dupliquées et leurs messages.
      await _localService.mergeDuplicateConversationsByPeer(familyIds: familyIds);
    } catch (_) {}
  }

  String? _otherParticipantId(Map<String, dynamic> conv, {String? currentUserId}) {
    try {
      if (conv['participants'] is List) {
        for (final p in (conv['participants'] as List)) {
          if (p == null) continue;
          if (p is String && p.isNotEmpty) {
            if (currentUserId == null || p != currentUserId) return p;
          } else if (p is Map) {
            final pid = (p['id'] ?? p['user_id'] ?? p['participant_id'] ?? p['idUser'])?.toString();
            if (pid != null && pid.isNotEmpty) {
              if (currentUserId == null || pid != currentUserId) return pid;
            }
          }
        }
      }
      if (conv['messages'] is List && (conv['messages'] as List).isNotEmpty) {
        final last = Map<String, dynamic>.from(((conv['messages'] as List).last) as Map);
        final s = (last['sender_id'] ?? last['senderId'])?.toString();
        final r = (last['receiver_id'] ?? last['receiverId'])?.toString();
        if (currentUserId != null && currentUserId.isNotEmpty) {
          if (s != null && s.isNotEmpty && s != currentUserId) return s;
          if (r != null && r.isNotEmpty && r != currentUserId) return r;
        } else {
          if (s != null && s.isNotEmpty) return s; if (r != null && r.isNotEmpty) return r;
        }
      }
      if (conv['meta'] is Map) {
        final meta = conv['meta'] as Map<String, dynamic>;
        final pid = (meta['participant'] ?? meta['participant_id'] ?? meta['user_id'] ?? meta['remote_participant'])?.toString();
        if (pid != null && pid.isNotEmpty) return pid;
      }
    } catch (_) {}
    return null;
  }

  String _pairKeyForConversation(Map<String, dynamic> c, {String? currentUserId}) {
    String? a;
    String? b;
    try {
      // Try participants field first
      if (c['participants'] is List) {
        final parts = <String>[];
        for (final p in (c['participants'] as List)) {
          if (p == null) continue;
          if (p is String && p.isNotEmpty) parts.add(p);
          else if (p is Map) {
            final pid = (p['id'] ?? p['user_id'] ?? p['idUser'] ?? p['participant_id'])?.toString();
            if (pid != null && pid.isNotEmpty) parts.add(pid);
          }
        }
        if (parts.length >= 2) {
          parts.sort();
          a = parts[0];
          b = parts[1];
        } else if (parts.length == 1 && currentUserId != null && currentUserId.isNotEmpty) {
          a = parts.first;
          b = currentUserId;
          final sorted = [a, b];
          sorted.sort(); a = sorted[0]; b = sorted[1];
        }
      }
      // Try from last message
      if ((a == null || b == null) && c['messages'] is List && (c['messages'] as List).isNotEmpty) {
        final last = Map<String, dynamic>.from(((c['messages'] as List).last) as Map);
        final s = (last['sender_id'] ?? last['senderId'])?.toString();
        final r = (last['receiver_id'] ?? last['receiverId'])?.toString();
        if (s != null && s.isNotEmpty && r != null && r.isNotEmpty) {
          a = s; b = r;
          final sorted = [a, b];
          sorted.sort(); a = sorted[0]; b = sorted[1];
        } else if (s != null && s.isNotEmpty && currentUserId != null && currentUserId.isNotEmpty) {
          a = s; b = currentUserId;
          final sorted = [a, b];
          sorted.sort(); a = sorted[0]; b = sorted[1];
        } else if (r != null && r.isNotEmpty && currentUserId != null && currentUserId.isNotEmpty) {
          a = r; b = currentUserId;
          final sorted = [a, b];
          sorted.sort(); a = sorted[0]; b = sorted[1];
        }
      }
      // Try meta fallback
      if ((a == null || b == null) && c['meta'] is Map && currentUserId != null && currentUserId.isNotEmpty) {
        final meta = c['meta'] as Map<String, dynamic>;
        final pid = (meta['participant'] ?? meta['participant_id'] ?? meta['user_id'] ?? meta['remote_participant'])?.toString();
        if (pid != null && pid.isNotEmpty) {
          a = pid; b = currentUserId;
          final sorted = [a, b];
          sorted.sort(); a = sorted[0]; b = sorted[1];
        }
      }
    } catch (_) {}

    if (a != null && b != null) {
      return 'pair:${a}|${b}';
    }

    // fallback to remote id if known
    final remoteId = (c['id'] ?? c['meta']?['remote_id'] ?? '').toString();
    if (remoteId.isNotEmpty) return 'id:$remoteId';

    // last resort
    return 'local:${c['title'] ?? DateTime.now().toIso8601String()}';
  }

  // Deduplicate conversations by pair of participants (WhatsApp style)
  List<dynamic> _dedupeConversations(List<dynamic> list, {String? currentUserId}) {
    final Map<String, Map<String, dynamic>> byKey = {};
    for (final item in list) {
      try {
        final Map<String, dynamic> c = Map<String, dynamic>.from(item as Map);
        final key = _pairKeyForConversation(c, currentUserId: currentUserId);
        if (!byKey.containsKey(key)) {
          byKey[key] = c;
        } else {
          final existing = byKey[key]!;
          // Keep the most recent
          final existingUpdated = DateTime.tryParse(existing['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final thisUpdated = DateTime.tryParse(c['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          if (thisUpdated.isAfter(existingUpdated)) byKey[key] = c;
        }
      } catch (_) {}
    }
    return byKey.values.toList();
  }

  @override
  void initState() {
    super.initState();
    // initial loading from remote/local
    _loadConversations();
    // subscribe to local conversation changes so UI updates immediately when data changes
    try {
      _localConvSub = _localService.conversationsStream.listen((convs) async {
        // aussi essayer de résoudre les noms des participants pour l'affichage
        List<Map<String, dynamic>> updated = convs.cast<Map<String, dynamic>>();
        String? currentUserId;
        Set<String> familyIds = <String>{};
        try {
          currentUserId = await _identity.getCurrentUserId();
          familyIds = await _identity.getFamilyUserIds();
          if (currentUserId == null || currentUserId.isEmpty) {
            final prefs = await SharedPreferences.getInstance();
            currentUserId = prefs.getString('current_user_id') ?? prefs.getString('user_id') ?? prefs.getString('id');
          }
        } catch (_) {}
        try {
          for (final c in updated) {
            final name = await _resolveOtherParticipantName(c, currentUserId);
            if (name != null && name.isNotEmpty) {
              final meta = Map<String, dynamic>.from((c['meta'] as Map?) ?? {});
              meta['participant_name'] = name;
              c['meta'] = meta;
            }
          }
        } catch (_) {}

        // nettoyage local: supprime les doublons persistés (conserve le plus récent)
        // (best effort, ne doit pas bloquer l'UI)
        // ignore: unawaited_futures
        _cleanupLocalDuplicates(updated, familyIds: familyIds);

        // déduplication UI robuste en considérant parent+enfants comme "moi"
        final Map<String, Map<String, dynamic>> keep = {};
        final Set<String> meIds = familyIds.isNotEmpty
            ? familyIds
            : (currentUserId != null && currentUserId.isNotEmpty ? {currentUserId} : <String>{});

        for (final c in updated) {
          final key = _conversationPeerKey(c, familyIds: meIds);
          final existing = keep[key];
          if (existing == null) {
            keep[key] = c;
          } else {
            final existingUpdated = _conversationUpdatedAt(existing);
            final thisUpdated = _conversationUpdatedAt(c);
            if (thisUpdated.isAfter(existingUpdated)) keep[key] = c;
          }
        }
        _conversations = keep.values.toList();
        _sortConversations();
      });
    } catch (_) {}
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // resolve current user id centrally
      String? curId = await _identity.getCurrentUserId();
      final familyIds = await _identity.getFamilyUserIds();

      final convs = await _messagingService.getConversations();
      if (convs.isEmpty) {
        // Endpoint 405/empty -> reconstruire depuis messages reçus
        if (curId != null && curId.isNotEmpty) {
          await _messagingService.buildLocalConversationsForUser(curId);
          final local = await _localService.getConversations();

          await _cleanupLocalDuplicates(local, familyIds: familyIds.isNotEmpty ? familyIds : {curId});
          final cleaned = await _localService.getConversations();

          setState(() {
            final Map<String, Map<String, dynamic>> keep = {};
            for (final c in cleaned) {
              final key = _conversationPeerKey(c, familyIds: familyIds.isNotEmpty ? familyIds : {curId});
              final existing = keep[key];
              if (existing == null) {
                keep[key] = c;
              } else {
                if (_conversationUpdatedAt(c).isAfter(_conversationUpdatedAt(existing))) keep[key] = c;
              }
            }
            _conversations = keep.values.toList();
            _sortConversations();
          });
        } else {
          // fallback strict local
          final local = await _localService.getConversations();
          setState(() {
            _conversations = _dedupeConversations(local, currentUserId: curId);
            _sortConversations();
          });
        }
      } else {
        // Resolve names and merge into local cache, then display from local
        for (final raw in convs) {
          try {
            final c = Map<String, dynamic>.from(raw as Map);
            final name = await _resolveOtherParticipantName(c, curId);
            if (name != null && name.isNotEmpty) {
              final meta = Map<String, dynamic>.from((c['meta'] as Map?) ?? {});
              meta['participant_name'] = name;
              c['meta'] = meta;
            }
            await _localService.mergeAndSaveConversationFromApi(c);
          } catch (_) {}
        }
        final local = await _localService.getConversations();

        await _cleanupLocalDuplicates(local, familyIds: familyIds.isNotEmpty ? familyIds : (curId != null && curId.isNotEmpty ? {curId} : <String>{}));
        final cleaned = await _localService.getConversations();

        setState(() {
          final Map<String, Map<String, dynamic>> keep = {};
          for (final c in cleaned) {
            final key = _conversationPeerKey(c, familyIds: familyIds.isNotEmpty ? familyIds : (curId != null && curId.isNotEmpty ? {curId} : <String>{}));
            final existing = keep[key];
            if (existing == null) {
              keep[key] = c;
            } else {
              if (_conversationUpdatedAt(c).isAfter(_conversationUpdatedAt(existing))) keep[key] = c;
            }
          }
          _conversations = keep.values.toList();
          _sortConversations();
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // helper: format time similar to WhatsApp
  String _formatConversationTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    DateTime? dt;
    try {
      dt = DateTime.tryParse(iso);
    } catch (_) {
      dt = null;
    }
    if (dt == null) return iso;
    final now = DateTime.now();
    final local = dt.toLocal();
    final difference = now.difference(local);
    if (difference.inDays == 0 && now.day == local.day) {
      // today -> show HH:mm
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1 || (difference.inDays == 0 && now.day != local.day)) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      // weekday name (Mon, Tue)
      const names = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
      return names[local.weekday % 7];
    } else {
      // date short
      return '${local.day}/${local.month}/${local.year.toString().substring(2)}';
    }
  }

  Future<String?> _resolveOtherParticipantName(Map<String, dynamic> conv, String? currentUserId) async {
    try {
      String? otherId;
      // Prefer participants list
      if (conv['participants'] is List) {
        for (final p in (conv['participants'] as List)) {
          if (p == null) continue;
          if (p is String && p.isNotEmpty) {
            if (currentUserId == null || p != currentUserId) { otherId = p; break; }
          } else if (p is Map) {
            final pid = (p['id'] ?? p['user_id'] ?? p['participant_id'] ?? p['idUser'])?.toString();
            if (pid != null && pid.isNotEmpty) {
              if (currentUserId == null || pid != currentUserId) { otherId = pid; break; }
            }
          }
        }
      }
      // Fallback: infer from last message
      if ((otherId == null || otherId.isEmpty) && conv['messages'] is List && (conv['messages'] as List).isNotEmpty) {
        try {
          final last = Map<String, dynamic>.from((conv['messages'] as List).last as Map);
          final s = (last['sender_id'] ?? last['senderId'])?.toString();
          final r = (last['receiver_id'] ?? last['receiverId'])?.toString();
          if (currentUserId != null && currentUserId.isNotEmpty) {
            if (s != null && s.isNotEmpty && s != currentUserId) otherId = s;
            if ((otherId == null || otherId.isEmpty) && r != null && r.isNotEmpty && r != currentUserId) otherId = r;
          } else {
            if (s != null && s.isNotEmpty) otherId = s; else if (r != null && r.isNotEmpty) otherId = r;
          }
        } catch (_) {}
      }
      // Fallback meta
      if ((otherId == null || otherId.isEmpty) && conv['meta'] is Map) {
        final meta = conv['meta'] as Map<String, dynamic>;
        final pid = (meta['participant'] ?? meta['participant_id'] ?? meta['user_id'] ?? meta['remote_participant'])?.toString();
        if (pid != null && pid.isNotEmpty) otherId = pid;
      }

      if (otherId == null || otherId.isEmpty) return null;

      // if meta already has participant_name, use it
      if (conv['meta'] is Map && (conv['meta'] as Map).containsKey('participant_name')) {
        final name = (conv['meta']['participant_name']?.toString() ?? '').trim();
        if (name.isNotEmpty) return name;
      }

      final resolved = await _userDirectory.resolveUserName(otherId);
      if (resolved.isNotEmpty) {
        // persist to local meta for future
        try {
          final convs = await _localService.getConversations();
          final idx = convs.indexWhere((c) => (c['id']?.toString() ?? '') == (conv['id']?.toString() ?? ''));
          if (idx >= 0) {
            final updated = Map<String, dynamic>.from(convs[idx]);
            final meta = Map<String, dynamic>.from((updated['meta'] as Map?) ?? {});
            meta['participant_name'] = resolved;
            updated['meta'] = meta;
            convs[idx] = updated;
            await _localService.saveConversations(convs);
          }
        } catch (_) {}
        return resolved;
      }
    } catch (_) {}
    return null;
  }

  // extrait le nom d'affichage de la conversation
  // priorité : meta.participant_name (nom du correspondant tel que défini par NewChatScreen),
  // puis éventuellement d'autres champs de meta, puis fallback sur le titre brut ou "Conversation".
  String _extractDisplayName(Map<String, dynamic> conv) {
    try {
      // 1) si meta.participant_name est présent, on l'utilise toujours comme nom du correspondant
      if (conv.containsKey('meta') && conv['meta'] != null) {
        final meta = conv['meta'] as Map<String, dynamic>;
        final participantName = meta['participant_name']?.toString().trim();
        if (participantName != null && participantName.isNotEmpty) {
          return participantName;
        }
      }
      // 2) sinon on reprend l'ancienne logique : titre ou autres champs de meta
      if (conv.containsKey('title') && conv['title'] != null) {
        final t = conv['title'].toString().trim();
        if (t.isNotEmpty && t.toLowerCase() != 'conversation') return t;
      }
      if (conv.containsKey('meta') && conv['meta'] != null) {
        final meta = conv['meta'] as Map<String, dynamic>;
        final candidates = [meta['receiver_name'], meta['name'], meta['username'], meta['firstname']];
        for (final c in candidates) {
          if (c != null) {
            final v = c.toString().trim();
            if (v.isNotEmpty) return v;
          }
        }
      }
    } catch (_) {}
    return 'Conversation';
  }

  // extrait la classe associée à la conversation (si disponible)
  String? _extractClasse(Map<String, dynamic> conv) {
    try {
      if (conv.containsKey('classe') && conv['classe'] != null) {
        return conv['classe'].toString();
      }
      if (conv.containsKey('meta') && conv['meta'] != null) {
        final meta = conv['meta'] as Map<String, dynamic>;
        final c = (meta['classe'] ?? meta['class'] ?? meta['classe_name'])?.toString();
        if (c != null && c.isNotEmpty) return c;
      }
    } catch (_) {}
    return null;
  }

  // retourne le dernier message de la conversation en se basant uniquement sur la date (created_at/updated_at)
  // sans changer le correspondant en fonction de l'expéditeur.
  Map<String, dynamic>? _latestMessage(Map<String, dynamic> conv) {
    try {
      final msgs = conv['messages'] as List<dynamic>?;
      if (msgs == null || msgs.isEmpty) return null;
      final sorted = List<Map<String, dynamic>>.from(msgs.map((e) => Map<String, dynamic>.from(e as Map)));
      sorted.sort((a, b) {
        DateTime pa = DateTime.tryParse(a['updated_at']?.toString() ?? a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        DateTime pb = DateTime.tryParse(b['updated_at']?.toString() ?? b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return pa.compareTo(pb);
      });
      return sorted.last;
    } catch (_) {
      return null;
    }
  }

  DateTime _conversationUpdatedAt(Map<String, dynamic> conv) {
    final latest = _latestMessage(conv);
    final s = latest != null
        ? (latest['updated_at'] ?? latest['created_at'])?.toString()
        : (conv['updated_at'] ?? conv['created_at'])?.toString();
    return DateTime.tryParse(s ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _sortConversations() {
    try {
      _conversations.sort((a, b) {
        final ca = Map<String, dynamic>.from(a as Map);
        final cb = Map<String, dynamic>.from(b as Map);
        final da = _conversationUpdatedAt(ca);
        final db = _conversationUpdatedAt(cb);
        return db.compareTo(da); // newest first
      });
    } catch (_) {}
  }

  Future<void> _deleteConversation(Map<String, dynamic> conv) async {
    final id = conv['id']?.toString();
    final keyId = id ?? (conv['meta']?['remote_id']?.toString() ?? '');
    // suppression optimiste dans la liste locale
    setState(() {
      _conversations.removeWhere((c) => (c['id']?.toString() ?? '') == keyId || (c['meta']?['remote_id']?.toString() ?? '') == keyId);
    });
    // tentative de suppression serveur si id plausible
    try {
      if (keyId.isNotEmpty && !keyId.startsWith('local-')) {
        await _messagingService.deleteConversationRemote(keyId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Suppression serveur impossible: ' + e.toString())));
      }
    }
    // suppression locale dans le cache
    try {
      await _localService.deleteConversation(keyId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          loc.translate('messages'),
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: AppColors.text(context)),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(child: Text(_error ?? loc.translate('no_conversations')))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _conversations.length,
                  separatorBuilder: (context, index) => const Divider(indent: 70, endIndent: 15, thickness: 0.5),
                  itemBuilder: (context, index) {
                    final conv = _conversations[index] as Map<String, dynamic>;
                    // On ne peut pas résoudre sync ici; on utilisera null pour le rendu, puis vraie valeur au onTap.
                    String? currentUserId;

                    // Résolution uniforme du correspondant (nom + id)
                    final correspondent = resolveCorrespondentFromConversation(conv, currentUserId: currentUserId);
                    final title = correspondent.name;
                    final id = conv['id']?.toString();
                    final latest = _latestMessage(conv);
                    final lastMessage = latest != null ? (latest['content'] ?? latest['message'] ?? '').toString() : '';
                    final latestDateStr = latest != null ? (latest['updated_at'] ?? latest['created_at'])?.toString() : (conv['updated_at'] ?? conv['created_at'])?.toString();
                    final classe = _extractClasse(conv);
                    final timeStr = _formatConversationTime(latestDateStr);
                    final bool unread = isConversationUnread(conv, currentUserId: null);

                    return ConversationTile(
                      title: title,
                      subtitle: lastMessage,
                      timeLabel: timeStr,
                      unread: unread,
                      avatarUrl: correspondent.avatarUrl,
                      classe: classe,
                      onTap: () async {
                        // Résout l'id utilisateur courant proprement
                        try {
                          currentUserId = await _identity.getCurrentUserId();
                          if (currentUserId == null || currentUserId!.isEmpty) {
                            final prefs = await SharedPreferences.getInstance();
                            currentUserId = prefs.getString('current_user_id') ?? prefs.getString('user_id') ?? prefs.getString('id');
                            if ((currentUserId == null || currentUserId!.isEmpty) && prefs.containsKey('user')) {
                              currentUserId = tryExtractCurrentUserIdFromPrefsJson(prefs.getString('user')) ?? currentUserId;
                            }
                          }
                        } catch (_) {}

                        final otherId = resolveCorrespondentFromConversation(conv, currentUserId: currentUserId).otherUserId ?? _otherParticipantId(conv, currentUserId: currentUserId);

                        if (id != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                name: title,
                                avatarUrl: correspondent.avatarUrl ?? 'https://randomuser.me/api/portraits/lego/1.jpg',
                                conversationId: id,
                                currentUserId: currentUserId,
                                receiverUserId: otherId,
                              ),
                            ),
                          );
                        }
                      },
                      onLongPress: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Supprimer la conversation'),
                            content: const Text('Voulez-vous vraiment supprimer cette conversation ? Cette action est irréversible.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
                              TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _deleteConversation(conv);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conversation supprimée')));
                        }
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => NewChatScreen()));
          if (result != null) {
            // NewChatScreen returns a Map with conversationId, name, avatarUrl, currentUserId, receiverUserId, receiverPersonnelId
            if (result is Map<String, dynamic>) {
              final convId = result['conversationId']?.toString();
              final name = result['name']?.toString() ?? 'Conversation';
              final avatar = result['avatarUrl']?.toString() ?? 'https://randomuser.me/api/portraits/lego/1.jpg';
              final currentUserId = result['currentUserId']?.toString();
              final receiverUserId = result['receiverUserId']?.toString();
              final receiverPersonnelId = result['receiverPersonnelId']?.toString();

              // If we have a conversationId, open ChatScreen with it; otherwise open a screen with provided ids
              Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                name: name,
                avatarUrl: avatar,
                conversationId: convId,
                currentUserId: currentUserId,
                receiverUserId: receiverUserId,
                receiverPersonnelId: receiverPersonnelId,
              )));
            } else {
              // Fallback: older code expected a ContactModel
              try {
                final dynamic c = result;
                final String name = (c.name != null) ? c.name.toString() : 'Conversation';
                final String avatar = (c.avatarUrl != null) ? c.avatarUrl.toString() : 'https://randomuser.me/api/portraits/lego/1.jpg';
                Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(name: name, avatarUrl: avatar)));
                // removed toast/snackbar here as well
              } catch (_) {
                // ignore
              }
            }
          }
         },
         backgroundColor: AppColors.secondaryColor(context),
         child: Icon(Icons.message, color: AppColors.onPrimary(context)),
       ),
    );
  }
}
