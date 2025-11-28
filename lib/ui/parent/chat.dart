import 'package:flutter/material.dart';
import 'NewChatScreen.dart';
import 'chat_screen.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:slatereduc/services/app_localizations.dart';
import 'package:slatereduc/services/messaging_service.dart';
import 'package:slatereduc/services/local_messaging_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slatereduc/models/message_model.dart' as api_models;

import 'dart:convert';
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
  StreamSubscription<List<Map<String, dynamic>>>? _localConvSub;
  bool _isLoading = true;
  List<dynamic> _conversations = [];
  String? _error;

  // Deduplicate conversations by id, keeping the one with latest updated_at
  List<dynamic> _dedupeConversations(List<dynamic> list, {String? currentUserId}) {
    final Map<String, Map<String, dynamic>> map = {};
    for (final item in list) {
      try {
        final Map<String, dynamic> c = Map<String, dynamic>.from(item as Map);
        // Compute key: prefer remote conversation id; otherwise try to extract the other participant id
        String key = '';
        final remoteId = (c['id'] ?? c['meta']?['remote_id'] ?? '').toString();
        if (remoteId.isNotEmpty) {
          key = 'id:$remoteId';
        } else {
          // try to find a participant id from messages
          String? participant;
          // first, look for explicit participants/users array on the conversation
          try {
            final possibleLists = ['participants', 'users', 'members'];
            for (final listKey in possibleLists) {
              if (c.containsKey(listKey) && c[listKey] != null) {
                final arr = c[listKey] as List<dynamic>;
                for (final el in arr) {
                  if (el == null) continue;
                  if (el is String && el.isNotEmpty) {
                    // string id
                    if (currentUserId == null || el != currentUserId) {
                      participant = el;
                      break;
                    }
                  } else if (el is Map) {
                    final pid = (el['id'] ?? el['user_id'] ?? el['idUser'] ?? el['id_user'])?.toString();
                    if (pid != null && pid.isNotEmpty) {
                      if (currentUserId == null || pid != currentUserId) {
                        participant = pid;
                        break;
                      }
                    }
                  }
                }
                if (participant != null) break;
              }
            }
          } catch (_) {}

          try {
            final msgs = (c['messages'] as List<dynamic>?) ?? [];
            for (final m in msgs) {
              final mm = m as Map<String, dynamic>;
              final s = (mm['sender_id'] ?? mm['senderId'] ?? '').toString();
              final r = (mm['receiver_id'] ?? mm['receiverId'] ?? '').toString();
              if (currentUserId != null && currentUserId.isNotEmpty) {
                if (s.isNotEmpty && s != currentUserId) participant = s;
                if (participant == null && r.isNotEmpty && r != currentUserId) participant = r;
              } else {
                // if we don't know current user, pick sender or receiver
                if (s.isNotEmpty) participant = s;
                else if (r.isNotEmpty) participant = r;
              }
              if (participant != null) break;
            }
          } catch (_) {}
          // also check meta fields for participant id
          if ((participant == null || participant.isEmpty) && c.containsKey('meta')) {
            try {
              final meta = c['meta'] as Map<String, dynamic>;
              final pid = (meta['participant'] ?? meta['participant_id'] ?? meta['user_id'] ?? meta['remote_participant'])?.toString();
              if (pid != null && pid.isNotEmpty) participant = pid;
            } catch (_) {}
          }
          if (participant != null && participant.isNotEmpty) key = 'user:$participant';
          else key = 'local:${c['title'] ?? DateTime.now().toIso8601String()}';
        }

        if (!map.containsKey(key)) {
          map[key] = c;
        } else {
          final existing = map[key]!;
          try {
            final existingUpdated = DateTime.tryParse(existing['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final thisUpdated = DateTime.tryParse(c['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            if (thisUpdated.isAfter(existingUpdated)) {
              map[key] = c;
            }
          } catch (_) {
            map[key] = c; // fallback replace
          }
        }
      } catch (_) {
        // skip non-map items
      }
    }
    return map.values.toList();
  }

  @override
  void initState() {
    super.initState();
    // initial loading from remote/local
    _loadConversations();
    // subscribe to local conversation changes so UI updates immediately when data changes
    try {
      _localConvSub = _localService.conversationsStream.listen((convs) {
        // dedupe and update UI
        setState(() {
          _conversations = _dedupeConversations(convs.cast<Map<String, dynamic>>());
        });
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _localConvSub?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // resolve current user id to help dedup by participant when needed
      String? curId;
      try {
        final prefs = await SharedPreferences.getInstance();
        curId = prefs.getString('current_user_id') ?? prefs.getString('user_id') ?? prefs.getString('id');
        if ((curId == null || curId.isEmpty) && prefs.containsKey('user')) {
          final raw = prefs.getString('user');
          if (raw != null && raw.isNotEmpty) {
            try {
              final parsed = json.decode(raw);
              if (parsed is Map && parsed.containsKey('id')) curId = parsed['id']?.toString();
            } catch (_) {}
          }
        }
      } catch (_) {}

      final convs = await _messagingService.getConversations();
      setState(() {
        _conversations = _dedupeConversations(convs, currentUserId: curId);
      });
    } catch (e) {
      final err = e.toString();
      setState(() {
        _error = err;
      });
      // if API not allowed (405) or unreachable, try received-messages endpoint to build conversations
      try {
        // attempt to get current user id
        String? currentUserId;
        try {
          final prefs = await SharedPreferences.getInstance();
          currentUserId = prefs.getString('current_user_id') ?? prefs.getString('user_id') ?? prefs.getString('id');
          if ((currentUserId == null || currentUserId.isEmpty) && prefs.containsKey('user')) {
            final raw = prefs.getString('user');
            if (raw != null && raw.isNotEmpty) {
              try {
                final parsed = json.decode(raw);
                if (parsed is Map && parsed.containsKey('id')) currentUserId = parsed['id']?.toString();
              } catch (_) {}
            }
          }
        } catch (_) {}

        if (currentUserId != null && currentUserId.isNotEmpty) {
          print('[ChatTab] resolved currentUserId=$currentUserId');
          final received = await _messagingService.getReceivedMessagesByUserId(currentUserId);
          if (received.isNotEmpty) {
            final Map<String, List<api_models.MessageModel>> byConv = {};
            for (final m in received) {
              final cid = m.idConversation;
              byConv.putIfAbsent(cid, () => []).add(m);
            }
            final convsFromMsgs = byConv.entries.map((e) {
              final msgsList = e.value;
              msgsList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
              return {
                'id': e.key,
                'title': 'Conversation',
                'messages': msgsList.map((m) => m.toJson()).toList(),
                'created_at': msgsList.first.createdAt.toIso8601String(),
                'updated_at': msgsList.last.updatedAt.toIso8601String(),
              };
            }).toList();
            setState(() {
              _conversations = _dedupeConversations(convsFromMsgs, currentUserId: currentUserId);
            });
          } else {
            // fallback to local stored conversations
            final local = await _localService.getConversations();
            if (local.isNotEmpty) {
              setState(() {
                _conversations = _dedupeConversations(local, currentUserId: currentUserId);
              });
            }
          }
        } else {
          // no current user id → load local conversations
          final local = await _localService.getConversations();
          if (local.isNotEmpty) {
            setState(() {
              _conversations = _dedupeConversations(local, currentUserId: currentUserId);
            });
          }
        }
      } catch (_) {}
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

  // extract a display name for the conversation (title or meta)
  String _extractDisplayName(Map<String, dynamic> conv) {
    try {
      if (conv.containsKey('title') && conv['title'] != null && conv['title'].toString().trim().isNotEmpty) return conv['title'].toString();
      if (conv.containsKey('meta') && conv['meta'] != null) {
        final meta = conv['meta'] as Map<String, dynamic>;
        final candidates = [meta['participant_name'], meta['name'], meta['username'], meta['firstname']];
        for (final c in candidates) {
          if (c != null && c.toString().trim().isNotEmpty) return c.toString();
        }
      }
      // try messages' sender name
      final msgs = conv['messages'] as List<dynamic>?;
      if (msgs != null && msgs.isNotEmpty) {
        final last = msgs.last as Map<String, dynamic>;
        if (last.containsKey('sender_name') && last['sender_name'] != null) return last['sender_name'].toString();
      }
    } catch (_) {}
    return 'Conversation';
  }

  // extract class/grade info if available
  String? _extractClasse(Map<String, dynamic> conv) {
    try {
      if (conv.containsKey('classe') && conv['classe'] != null) return conv['classe'].toString();
      if (conv.containsKey('meta') && conv['meta'] != null) {
        final meta = conv['meta'] as Map<String, dynamic>;
        final c = (meta['classe'] ?? meta['class'] ?? meta['classe_name'])?.toString();
        if (c != null && c.isNotEmpty) return c;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _deleteConversation(Map<String, dynamic> conv) async {
    final id = conv['id']?.toString();
    final keyId = id ?? (conv['meta']?['remote_id']?.toString() ?? '');
    // optimistic remove
    setState(() {
      _conversations.removeWhere((c) => (c['id']?.toString() ?? '') == keyId || (c['meta']?['remote_id']?.toString() ?? '') == keyId);
    });
    // try remote delete if id looks like remote (not starting with 'local-')
    try {
      if (keyId.isNotEmpty && !keyId.startsWith('local-')) {
        await _messagingService.deleteConversationRemote(keyId);
      }
    } catch (e) {
      // ignore remote delete errors but inform user
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible de supprimer la conversation sur le serveur: ' + e.toString())));
    }
    // always delete local
    try {
      await _localService.deleteConversation(keyId);
    } catch (_) {}
  }

  Widget _buildAvatar(Map<String, dynamic> conv) {
    final avatarUrl = conv['meta']?['avatar']?.toString();
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      // use network image if url is available
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(avatarUrl),
      );
    } else {
      // fallback to initial letter
      final title = _extractDisplayName(conv);
      String displayLetter = '';
      if (title.isNotEmpty) {
        displayLetter = title.trim().substring(0, 1).toUpperCase();
      }
      return CircleAvatar(
        radius: 28,
        child: Text(displayLetter, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.secondaryColor(context),
      );
    }
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
                    final title = _extractDisplayName(conv);
                    final id = conv['id']?.toString();
                    final messages = conv['messages'] as List<dynamic>? ?? [];
                    final lastMessage = messages.isNotEmpty ? (messages.last['content'] ?? messages.last['message'] ?? '') : '';
                    final createdAt = conv['updated_at'] ?? conv['created_at'] ?? '';
                    final classe = _extractClasse(conv);
                    final timeStr = _formatConversationTime(createdAt?.toString());
                    return ListTile(
                      leading: _buildAvatar(conv),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(title.toString(), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.text(context)), overflow: TextOverflow.ellipsis)),
                              Text(timeStr, style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          if (classe != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(classe, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(lastMessage.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[700])),
                      ),
                      trailing: null,
                      onTap: () async {
                        // resolve current user id from shared prefs to pass to ChatScreen
                        String? currentUserId;
                        try {
                          final prefs = await SharedPreferences.getInstance();
                          currentUserId = prefs.getString('current_user_id') ?? prefs.getString('user_id') ?? prefs.getString('id');
                          if ((currentUserId == null || currentUserId.isEmpty) && prefs.containsKey('user')) {
                            final raw = prefs.getString('user');
                            if (raw != null && raw.isNotEmpty) {
                              try {
                                final parsed = json.decode(raw);
                                if (parsed is Map && parsed.containsKey('id')) {
                                  currentUserId = parsed['id']?.toString();
                                }
                              } catch (e) {
                                // ignore JSON parse errors
                              }
                            }
                          }
                        } catch (e) {
                          // ignore SharedPreferences errors
                        }

                        if (id != null) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(name: title.toString(), avatarUrl: 'https://randomuser.me/api/portraits/lego/1.jpg', conversationId: id, currentUserId: currentUserId)));
                        }
                      },
                      onLongPress: () async {
                        final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                          title: const Text('Supprimer la conversation'),
                          content: const Text('Voulez-vous vraiment supprimer cette conversation ? Cette action est irréversible.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
                            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
                          ],
                        ));
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
          final contact = await Navigator.push(context, MaterialPageRoute(builder: (context) => NewChatScreen()));
          if (contact != null) {
            final message = loc.translate('new_chat_with').replaceAll('{name}', contact.name);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
          }
        },
        backgroundColor: AppColors.secondaryColor(context),
        child: Icon(Icons.message, color: AppColors.onPrimary(context)),
      ),
    );
  }
}
